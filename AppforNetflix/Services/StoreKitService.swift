import Foundation
import StoreKit
import Combine

@MainActor
final class StoreKitService: ObservableObject {
    enum EntitlementState: Equatable {
        case loading
        case notEntitled
        case entitled
    }

    enum PurchaseOutcome: Equatable {
        case purchased
        case pending
        case cancelled
    }

    struct SubscriptionStatus: Equatable {
        enum Kind: Equatable {
            case loading
            case free
            case active
            case expired
            case revoked
            case billingRetry
            case gracePeriod
            case pending
            case lifetime
        }

        let kind: Kind
        var productID: String?
        var planName: String?
        var displayPrice: String?
        var relevantDate: Date?
        var willAutoRenew: Bool?
        var grantsPremiumAccess: Bool

        static let loading = SubscriptionStatus(kind: .loading, grantsPremiumAccess: false)
        static let free = SubscriptionStatus(kind: .free, grantsPremiumAccess: false)
        static let pending = SubscriptionStatus(kind: .pending, grantsPremiumAccess: false)
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    @Published private(set) var entitlementState: EntitlementState = .loading
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .loading
    @Published private(set) var isLoading = false
    @Published private(set) var lastErrorMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var hasPendingPurchase = false

    let productIDsByPlan: [SubscriptionPlan: String]

    init() {
        productIDsByPlan = Dictionary(
            uniqueKeysWithValues: SubscriptionPlan.allCases.compactMap { plan in
                let productID = AppConfiguration.string(for: plan.configurationKey)
                return productID.isEmpty ? nil : (plan, productID)
            }
        )
    }

    deinit { updatesTask?.cancel() }

    var isConfigured: Bool { !productIDsByPlan.isEmpty }

    /// This value is derived only from verified, current StoreKit entitlements.
    var hasPremiumEntitlement: Bool { !purchasedProductIDs.isEmpty }

    func isPlanConfigured(_ plan: SubscriptionPlan) -> Bool {
        productIDsByPlan[plan] != nil
    }

    func product(for plan: SubscriptionPlan) -> Product? {
        guard let productID = productIDsByPlan[plan] else { return nil }
        return products.first { $0.id == productID }
    }

    func prepare() async {
        if updatesTask == nil { updatesTask = observeTransactionUpdates() }
        guard isConfigured else {
            products = []
            purchasedProductIDs = []
            entitlementState = .notEntitled
            subscriptionStatus = .free
            return
        }

        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }

        do {
            let fetchedProducts = try await Product.products(for: Array(productIDsByPlan.values))
            products = fetchedProducts
                .filter(isCompatibleProduct)
                .sorted { $0.price < $1.price }
            if products.count != productIDsByPlan.count {
                lastErrorMessage = L10n.string("One or more purchases are unavailable. Please try again later.")
            }
        } catch {
            products = []
            lastErrorMessage = L10n.string("Unable to load purchases. Please try again.")
        }

        await refreshEntitlements()
    }

    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        guard configuredProductIDs.contains(product.id) else {
            throw StoreKitServiceError.unknownProduct
        }
        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            hasPendingPurchase = false
            await transaction.finish()
            await refreshEntitlements()
            guard purchasedProductIDs.contains(transaction.productID) else {
                throw StoreKitServiceError.inactiveTransaction
            }
            return .purchased
        case .pending:
            hasPendingPurchase = true
            subscriptionStatus = .pending
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restorePurchases() async throws {
        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }
        try await AppStore.sync()
        hasPendingPurchase = false
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        entitlementState = .loading
        subscriptionStatus = .loading

        var activeIDs = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result),
                  configuredProductIDs.contains(transaction.productID),
                  !transaction.isUpgraded,
                  transaction.revocationDate == nil,
                  transaction.expirationDate.map({ $0 > .now }) ?? true else { continue }
            activeIDs.insert(transaction.productID)
        }

        purchasedProductIDs = activeIDs
        entitlementState = activeIDs.isEmpty ? .notEntitled : .entitled
        subscriptionStatus = await resolvedSubscriptionStatus(activeIDs: activeIDs)
    }

    private func resolvedSubscriptionStatus(activeIDs: Set<String>) async -> SubscriptionStatus {
        if let lifetimeID = productIDsByPlan[.lifetime], activeIDs.contains(lifetimeID) {
            return status(kind: .lifetime, productID: lifetimeID, grantsAccess: true)
        }

        var candidates: [SubscriptionStatus] = []
        var inspectedGroupIDs = Set<String>()

        for product in products where product.type == .autoRenewable {
            guard let subscription = product.subscription,
                  inspectedGroupIDs.insert(subscription.subscriptionGroupID).inserted else { continue }
            do {
                for item in try await subscription.status {
                    guard let transaction = try? verified(item.transaction),
                          configuredProductIDs.contains(transaction.productID),
                          let renewalInfo = try? verified(item.renewalInfo) else { continue }
                    let hasAccess = activeIDs.contains(transaction.productID)
                    let kind: SubscriptionStatus.Kind
                    switch item.state {
                    case .subscribed: kind = .active
                    case .expired: kind = .expired
                    case .revoked: kind = .revoked
                    case .inBillingRetryPeriod: kind = .billingRetry
                    case .inGracePeriod: kind = .gracePeriod
                    default: kind = hasAccess ? .active : .expired
                    }
                    candidates.append(
                        status(
                            kind: kind,
                            productID: transaction.productID,
                            date: item.state == .inGracePeriod
                                ? renewalInfo.gracePeriodExpirationDate
                                : transaction.expirationDate,
                            willAutoRenew: renewalInfo.willAutoRenew,
                            grantsAccess: hasAccess
                        )
                    )
                }
            } catch {
                // Current verified entitlements still remain authoritative if
                // subscription-status metadata cannot be loaded temporarily.
            }
        }

        if let active = candidates.first(where: { $0.grantsPremiumAccess }) {
            hasPendingPurchase = false
            return active
        }
        if hasPendingPurchase { return .pending }
        if let activeID = activeIDs.first {
            return status(kind: .active, productID: activeID, grantsAccess: true)
        }
        if let revoked = candidates.first(where: { $0.kind == .revoked }) { return revoked }
        if let retry = candidates.first(where: { $0.kind == .billingRetry }) { return retry }
        if let grace = candidates.first(where: { $0.kind == .gracePeriod }) { return grace }
        if let expired = candidates.first(where: { $0.kind == .expired }) { return expired }
        return .free
    }

    private func status(
        kind: SubscriptionStatus.Kind,
        productID: String,
        date: Date? = nil,
        willAutoRenew: Bool? = nil,
        grantsAccess: Bool
    ) -> SubscriptionStatus {
        let product = products.first { $0.id == productID }
        return SubscriptionStatus(
            kind: kind,
            productID: productID,
            planName: product?.displayName,
            displayPrice: product?.displayPrice,
            relevantDate: date,
            willAutoRenew: willAutoRenew,
            grantsPremiumAccess: grantsAccess
        )
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.verified(result)
                    self.hasPendingPurchase = false
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    self.lastErrorMessage = L10n.string("A purchase could not be verified.")
                }
            }
        }
    }

    private var configuredProductIDs: Set<String> { Set(productIDsByPlan.values) }

    private func isCompatibleProduct(_ product: Product) -> Bool {
        guard let plan = productIDsByPlan.first(where: { $0.value == product.id })?.key else { return false }
        switch (plan, product.type) {
        case (.lifetime, .nonConsumable): return true
        case (.weekly, .autoRenewable), (.monthly, .autoRenewable), (.annual, .autoRenewable): return true
        default: return false
        }
    }

    nonisolated private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw StoreKitServiceError.failedVerification
        }
    }
}

private enum StoreKitServiceError: LocalizedError {
    case failedVerification
    case unknownProduct
    case inactiveTransaction

    var errorDescription: String? {
        switch self {
        case .failedVerification: return "The purchase could not be verified."
        case .unknownProduct: return "This purchase is unavailable."
        case .inactiveTransaction: return "The purchase completed, but Premium access is not active."
        }
    }
}
