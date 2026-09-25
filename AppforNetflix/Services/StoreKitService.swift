import Foundation
import StoreKit
import Combine

@MainActor
final class StoreKitService: ObservableObject {

    enum ProductLoadState: Equatable {
        case idle
        case loading
        case loaded
        case unavailable
        case failed
    }

    // MARK: - Entitlement State

    enum EntitlementState: Equatable {
        case loading
        case notEntitled
        case entitled
    }

    // MARK: - Purchase Outcome

    enum PurchaseOutcome: Equatable {
        case purchased
        case pending
        case cancelled
    }

    // MARK: - Subscription Status

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

        static let loading = SubscriptionStatus(
            kind: .loading,
            grantsPremiumAccess: false
        )

        static let free = SubscriptionStatus(
            kind: .free,
            grantsPremiumAccess: false
        )

        static let pending = SubscriptionStatus(
            kind: .pending,
            grantsPremiumAccess: false
        )
    }

    // MARK: - Published Properties

    @Published private(set) var products: [Product] = []

    @Published private(set) var productLoadState: ProductLoadState = .idle

    @Published private(set) var missingProductIDs = Set<String>()

    @Published private(set) var purchasedProductIDs = Set<String>()

    @Published private(set) var entitlementState: EntitlementState = .loading

    @Published private(set) var subscriptionStatus: SubscriptionStatus = .loading

    @Published private(set) var isLoading = false

    @Published private(set) var lastErrorMessage: String?

    @Published private(set) var productLoadErrorMessage: String?

    /// True only when Apple's monthly product contains an actual three-day
    /// free-trial introductory offer and the current App Store account is
    /// eligible to redeem it.
    @Published private(set) var isMonthlyFreeTrialEligible = false

    // MARK: - Private Properties

    private var updatesTask: Task<Void, Never>?

    /// StoreKit does not guarantee a transaction update at the exact moment
    /// an auto-renewable subscription expires. Refresh at that boundary so
    /// premium UI (including the sidebar card) stays correct while the app
    /// remains open.
    private var entitlementExpirationTask: Task<Void, Never>?

    private var hasPendingPurchase = false

    // MARK: - Product IDs

    let productIDsByPlan: [SubscriptionPlan: String]

    // MARK: - Init

    init() {

        var ids: [SubscriptionPlan: String] = [:]

        for plan in SubscriptionPlan.allCases {

            let rawProductID = AppConfiguration.string(
                for: plan.configurationKey
            )

            // Important:
            // Remove accidental spaces/newlines from xcconfig / Info.plist.
            let productID = rawProductID
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !productID.isEmpty {
                ids[plan] = productID
            }
        }

        self.productIDsByPlan = ids

        print("")
        print("========== STOREKIT CONFIG ==========")

        for plan in SubscriptionPlan.allCases {

            if let id = productIDsByPlan[plan] {
                print("✅ \(plan.rawValue): [\(id)]")
            } else {
                print("❌ \(plan.rawValue): NOT CONFIGURED")
            }
        }

        print("Bundle ID:", Bundle.main.bundleIdentifier ?? "nil")
        print("=====================================")
        print("")
    }

    deinit {
        updatesTask?.cancel()
        entitlementExpirationTask?.cancel()
    }

    // MARK: - Configuration

    var isConfigured: Bool {
        !productIDsByPlan.isEmpty
    }

    var hasPremiumEntitlement: Bool {
        !purchasedProductIDs.isEmpty
    }

    private var configuredProductIDs: Set<String> {
        Set(productIDsByPlan.values)
    }

    // MARK: - Plan Helpers

    func isPlanConfigured(
        _ plan: SubscriptionPlan
    ) -> Bool {

        productIDsByPlan[plan] != nil
    }

    func product(
        for plan: SubscriptionPlan
    ) -> Product? {

        guard let productID = productIDsByPlan[plan] else {
            return nil
        }

        return products.first {
            $0.id == productID
        }
    }

    // MARK: - Prepare StoreKit

    func prepare(forceReload: Bool = false) async {

        if updatesTask == nil {
            updatesTask = observeTransactionUpdates()
        }

        guard isConfigured else {

            products = []
            missingProductIDs = []
            productLoadState = .unavailable
            purchasedProductIDs = []
            entitlementState = .notEntitled
            subscriptionStatus = .free

            lastErrorMessage =
                "Purchases are not configured for this build."
            productLoadErrorMessage = lastErrorMessage

            print("❌ STOREKIT NOT CONFIGURED")

            return
        }

        // The app prepares StoreKit at launch. Opening the paywall must not
        // start an identical request again, while an explicit Retry can.
        if !forceReload {
            switch productLoadState {
            case .loading, .loaded:
                return
            case .idle, .unavailable, .failed:
                break
            }
        }

        isLoading = true
        productLoadState = .loading
        lastErrorMessage = nil
        productLoadErrorMessage = nil

        defer {
            isLoading = false
        }

        // Get IDs from configuration.

        let requestedIDs = Array(
            configuredProductIDs
        )

        print("")
        print("========== STOREKIT FETCH ==========")

        print("Bundle ID:")
        print(Bundle.main.bundleIdentifier ?? "nil")

        print("")
        print("🟡 Requesting \(requestedIDs.count) products:")

        for id in requestedIDs {
            print("→ [\(id)]")
        }

        do {

            // MARK: Actual StoreKit 2 Fetch

            let fetchedProducts = try await Product.products(
                for: requestedIDs
            )

            print("")
            print(
                "🟢 APP STORE RETURNED \(fetchedProducts.count) PRODUCT(S)"
            )

            // Print everything Apple returned.

            for product in fetchedProducts {

                print("")
                print("------------------------------------")
                print("ID: \(product.id)")
                print("Name: \(product.displayName)")
                print("Description: \(product.description)")
                print("Price: \(product.displayPrice)")
                print("Type: \(product.type)")
                print("------------------------------------")
            }

            // Find IDs Apple didn't return.

            let returnedIDs = Set(
                fetchedProducts.map(\.id)
            )

            let missingIDs =
                configuredProductIDs
                    .subtracting(returnedIDs)

            missingProductIDs = missingIDs

            if !missingIDs.isEmpty {

                print("")
                print("🔴 APP STORE DID NOT RETURN:")

                for id in missingIDs {
                    print("→ \(id)")
                }
            }

            // Validate product types.

            let compatibleProducts =
                fetchedProducts.filter {
                    isCompatibleProduct($0)
                }

            products = compatibleProducts.sorted {
                $0.price < $1.price
            }

            await refreshMonthlyFreeTrialEligibility()

            print("")
            print(
                "🟢 Compatible products: \(products.count)"
            )

            // MARK: Important Error Detection

            if fetchedProducts.isEmpty {

                productLoadState = .unavailable

                print("")
                print("❌ ZERO PRODUCTS RETURNED")
                print("")
                print(
                    "StoreKit received the Product IDs but Apple returned no products."
                )

                lastErrorMessage =
                    "Unable to load purchase options. Please try again."
                productLoadErrorMessage = lastErrorMessage

            } else if compatibleProducts.isEmpty {

                productLoadState = .unavailable

                print("")
                print("❌ PRODUCT TYPE MISMATCH")

                lastErrorMessage =
                    "Purchase configuration is invalid."
                productLoadErrorMessage = lastErrorMessage

            } else if products.count != productIDsByPlan.count {

                productLoadState = .loaded

                lastErrorMessage =
                    "One or more purchases are unavailable. Please try again later."
                productLoadErrorMessage = lastErrorMessage

            } else {

                productLoadState = .loaded

                // All four products loaded successfully.

                lastErrorMessage = nil
                productLoadErrorMessage = nil

                print("")
                print("✅ ALL STOREKIT PRODUCTS LOADED")
            }

        } catch {

            // Preserve previously loaded products during a transient retry
            // failure. They are immutable App Store product metadata and
            // remain safe to purchase through StoreKit.
            if products.isEmpty {
                productLoadState = .failed
            } else {
                productLoadState = .loaded
            }

            print("")
            print("❌ STOREKIT FETCH THREW AN ERROR")
            print("Error:")
            print(error)
            print("")
            print("Localized:")
            print(error.localizedDescription)

            lastErrorMessage =
                "Unable to load purchases. Please try again."
            productLoadErrorMessage = lastErrorMessage
        }

        print("")
        print("===================================")
        print("")

        await refreshEntitlements()
    }

    private func refreshMonthlyFreeTrialEligibility() async {
        isMonthlyFreeTrialEligible = false

        guard let monthlyProduct = product(for: .monthly),
              let subscription = monthlyProduct.subscription,
              let offer = subscription.introductoryOffer,
              offer.paymentMode == .freeTrial,
              offer.period.unit == .day,
              offer.period.value == 3
        else {
            return
        }

        // StoreKit determines eligibility from the customer's App Store
        // history for this subscription group. No local trial state is used.
        isMonthlyFreeTrialEligible = await subscription.isEligibleForIntroOffer
    }

    // MARK: - Purchase

    func purchase(
        _ product: Product
    ) async throws -> PurchaseOutcome {

        guard configuredProductIDs.contains(product.id) else {
            throw StoreKitServiceError.unknownProduct
        }

        isLoading = true
        lastErrorMessage = nil

        defer {
            isLoading = false
        }

        let result = try await product.purchase()

        switch result {

        case .success(let verification):

            let transaction =
                try verified(verification)

            hasPendingPurchase = false

            await transaction.finish()

            await refreshEntitlements()

            guard purchasedProductIDs.contains(
                transaction.productID
            ) else {

                throw StoreKitServiceError
                    .inactiveTransaction
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

    // MARK: - Restore

    func restorePurchases() async throws {

        isLoading = true
        lastErrorMessage = nil

        defer {
            isLoading = false
        }

        try await AppStore.sync()

        hasPendingPurchase = false

        await refreshEntitlements()
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {

        entitlementState = .loading
        subscriptionStatus = .loading

        var activeIDs = Set<String>()
        var nextExpirationDate: Date?
        let now = Date()

        for await result in Transaction.currentEntitlements {

            guard let transaction =
                    try? verified(result)
            else {
                continue
            }

            guard configuredProductIDs.contains(
                transaction.productID
            ) else {
                continue
            }

            guard !transaction.isUpgraded else {
                continue
            }

            guard transaction.revocationDate == nil else {
                continue
            }

            if let expirationDate =
                transaction.expirationDate,
               expirationDate <= now {

                continue
            }

            if let expirationDate = transaction.expirationDate {
                if let currentExpiration = nextExpirationDate {
                    nextExpirationDate = min(currentExpiration, expirationDate)
                } else {
                    nextExpirationDate = expirationDate
                }
            }

            activeIDs.insert(
                transaction.productID
            )
        }

        purchasedProductIDs = activeIDs

        entitlementState =
            activeIDs.isEmpty
            ? .notEntitled
            : .entitled

        subscriptionStatus =
            await resolvedSubscriptionStatus(
                activeIDs: activeIDs
            )

        scheduleEntitlementRefresh(at: nextExpirationDate)
    }

    private func scheduleEntitlementRefresh(at expirationDate: Date?) {
        entitlementExpirationTask?.cancel()
        entitlementExpirationTask = nil

        guard let expirationDate else {
            return
        }

        // Refresh just after the verified StoreKit expiration boundary.
        let delay = max(0, expirationDate.timeIntervalSinceNow + 1)

        entitlementExpirationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }

            guard !Task.isCancelled, let self else {
                return
            }

            self.entitlementExpirationTask = nil
            await self.refreshEntitlements()
        }
    }

    // MARK: - Subscription Status

    private func resolvedSubscriptionStatus(
        activeIDs: Set<String>
    ) async -> SubscriptionStatus {

        // Lifetime entitlement

        if let lifetimeID =
            productIDsByPlan[.lifetime],
           activeIDs.contains(lifetimeID) {

            return status(
                kind: .lifetime,
                productID: lifetimeID,
                grantsAccess: true
            )
        }

        var candidates: [SubscriptionStatus] = []

        var inspectedGroupIDs = Set<String>()

        for product in products
        where product.type == .autoRenewable {

            guard let subscription =
                    product.subscription
            else {
                continue
            }

            guard inspectedGroupIDs
                .insert(
                    subscription.subscriptionGroupID
                )
                .inserted
            else {
                continue
            }

            do {

                for item in try await subscription.status {

                    guard let transaction =
                            try? verified(item.transaction),
                          configuredProductIDs.contains(
                            transaction.productID
                          ),
                          let renewalInfo =
                            try? verified(item.renewalInfo)
                    else {
                        continue
                    }

                    let hasAccess =
                        activeIDs.contains(
                            transaction.productID
                        )

                    let kind: SubscriptionStatus.Kind

                    switch item.state {

                    case .subscribed:
                        kind = .active

                    case .expired:
                        kind = .expired

                    case .revoked:
                        kind = .revoked

                    case .inBillingRetryPeriod:
                        kind = .billingRetry

                    case .inGracePeriod:
                        kind = .gracePeriod

                    default:
                        kind = hasAccess
                            ? .active
                            : .expired
                    }

                    candidates.append(
                        status(
                            kind: kind,
                            productID: transaction.productID,
                            date:
                                item.state == .inGracePeriod
                                ? renewalInfo
                                    .gracePeriodExpirationDate
                                : transaction.expirationDate,
                            willAutoRenew:
                                renewalInfo.willAutoRenew,
                            grantsAccess: hasAccess
                        )
                    )
                }

            } catch {

                print(
                    "⚠️ Unable to read subscription status:",
                    error.localizedDescription
                )
            }
        }

        if let active =
            candidates.first(
                where: {
                    $0.grantsPremiumAccess
                }
            ) {

            hasPendingPurchase = false
            return active
        }

        if hasPendingPurchase {
            return .pending
        }

        if let activeID = activeIDs.first {

            return status(
                kind: .active,
                productID: activeID,
                grantsAccess: true
            )
        }

        if let revoked =
            candidates.first(
                where: {
                    $0.kind == .revoked
                }
            ) {

            return revoked
        }

        if let retry =
            candidates.first(
                where: {
                    $0.kind == .billingRetry
                }
            ) {

            return retry
        }

        if let grace =
            candidates.first(
                where: {
                    $0.kind == .gracePeriod
                }
            ) {

            return grace
        }

        if let expired =
            candidates.first(
                where: {
                    $0.kind == .expired
                }
            ) {

            return expired
        }

        return .free
    }

    // MARK: - Build Status

    private func status(
        kind: SubscriptionStatus.Kind,
        productID: String,
        date: Date? = nil,
        willAutoRenew: Bool? = nil,
        grantsAccess: Bool
    ) -> SubscriptionStatus {

        let product =
            products.first {
                $0.id == productID
            }

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

    // MARK: - Transaction Listener

    private func observeTransactionUpdates()
        -> Task<Void, Never> {

        Task { [weak self] in

            for await result in Transaction.updates {

                guard let self else {
                    return
                }

                do {

                    let transaction =
                        try self.verified(result)

                    self.hasPendingPurchase = false

                    await transaction.finish()

                    await self.refreshEntitlements()

                } catch {

                    self.lastErrorMessage =
                        "A purchase could not be verified."
                }
            }
        }
    }

    // MARK: - Product Validation

    private func isCompatibleProduct(
        _ product: Product
    ) -> Bool {

        guard let plan =
                productIDsByPlan.first(
                    where: {
                        $0.value == product.id
                    }
                )?.key
        else {

            print(
                "❌ Unknown StoreKit Product:",
                product.id
            )

            return false
        }

        switch (plan, product.type) {

        case (.weekly, .autoRenewable),
             (.monthly, .autoRenewable),
             (.annual, .autoRenewable):

            return true

        case (.lifetime, .nonConsumable):

            return true

        default:

            print("")
            print("❌ WRONG PRODUCT TYPE")
            print("Product:", product.id)
            print("Plan:", plan.rawValue)
            print("Type:", product.type)

            return false
        }
    }

    // MARK: - Verification

    nonisolated
    private func verified<T>(
        _ result: VerificationResult<T>
    ) throws -> T {

        switch result {

        case .verified(let value):
            return value

        case .unverified:
            throw StoreKitServiceError
                .failedVerification
        }
    }
}

// MARK: - Errors

private enum StoreKitServiceError: LocalizedError {

    case failedVerification
    case unknownProduct
    case inactiveTransaction

    var errorDescription: String? {

        switch self {

        case .failedVerification:
            return "The purchase could not be verified."

        case .unknownProduct:
            return "This purchase is unavailable."

        case .inactiveTransaction:
            return "The purchase completed, but Premium access is not active."
        }
    }
}
