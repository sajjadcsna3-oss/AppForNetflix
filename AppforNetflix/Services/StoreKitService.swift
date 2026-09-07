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

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    @Published private(set) var entitlementState: EntitlementState = .loading
    @Published private(set) var isLoading = false
    @Published private(set) var lastErrorMessage: String?

    private var updatesTask: Task<Void, Never>?

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
            await refreshEntitlements()
        } catch {
            products = []
            await refreshEntitlements()
            lastErrorMessage = L10n.string("Unable to load purchases. Please try again.")
        }
    }

    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        guard configuredProductIDs.contains(product.id) else {
            throw StoreKitError.unknownProduct
        }
        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            await refreshEntitlements()
            guard purchasedProductIDs.contains(transaction.productID) else {
                throw StoreKitError.inactiveTransaction
            }
            return .purchased
        case .pending:
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
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        entitlementState = .loading
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
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.verified(result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    self.lastErrorMessage = L10n.string("A purchase could not be verified.")
                }
            }
        }
    }

    private var configuredProductIDs: Set<String> {
        Set(productIDsByPlan.values)
    }

    private func isCompatibleProduct(_ product: Product) -> Bool {
        guard let plan = productIDsByPlan.first(where: { $0.value == product.id })?.key else {
            return false
        }
        switch (plan, product.type) {
        case (.lifetime, .nonConsumable):
            return true
        case (.weekly, .autoRenewable), (.monthly, .autoRenewable), (.annual, .autoRenewable):
            return true
        default:
            return false
        }
    }

    nonisolated private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw StoreKitError.failedVerification
        }
    }
}

private enum StoreKitError: Error {
    case failedVerification
    case unknownProduct
    case inactiveTransaction
}
