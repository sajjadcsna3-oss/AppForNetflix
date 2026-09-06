import Foundation
import StoreKit
import Combine
@MainActor
final class StoreKitService: ObservableObject {
    enum PurchaseOutcome: Equatable {
        case purchased
        case pending
        case cancelled
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
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

    func product(for plan: SubscriptionPlan) -> Product? {
        guard let productID = productIDsByPlan[plan] else { return nil }
        return products.first { $0.id == productID }
    }

    func prepare() async {
        if updatesTask == nil { updatesTask = observeTransactionUpdates() }
        guard isConfigured else {
            products = []
            purchasedProductIDs = []
            return
        }

        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Array(productIDsByPlan.values))
                .sorted { $0.price < $1.price }
            await refreshEntitlements()
        } catch {
            lastErrorMessage = L10n.string("Unable to load purchases. Please try again.")
        }
    }

    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            await refreshEntitlements()
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
        try await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var activeIDs = Set<String>()
        let configuredProductIDs = Set(productIDsByPlan.values)
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result),
                  configuredProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  transaction.expirationDate.map({ $0 > .now }) ?? true else { continue }
            activeIDs.insert(transaction.productID)
        }
        purchasedProductIDs = activeIDs
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

    nonisolated private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw StoreKitError.failedVerification
        }
    }
}

private enum StoreKitError: Error {
    case failedVerification
}
