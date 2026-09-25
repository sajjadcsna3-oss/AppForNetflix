import Foundation

enum SubscriptionPlan: String, CaseIterable, Identifiable, Hashable {

    case weekly
    case monthly
    case annual
    case lifetime

    var id: String {
        rawValue
    }

    // MARK: - StoreKit Configuration Key

    var configurationKey: String {
        switch self {
        case .weekly:
            return "StoreKitWeeklyProductID"

        case .monthly:
            return "StoreKitMonthlyProductID"

        case .annual:
            return "StoreKitAnnualProductID"

        case .lifetime:
            return "StoreKitLifetimeProductID"
        }
    }

    // MARK: - Title

    var title: String {
        switch self {
        case .weekly:
            return "Weekly Plan"

        case .monthly:
            return "Monthly Plan"

        case .annual:
            return "Annual Plan"

        case .lifetime:
            return "Lifetime Purchase"
        }
    }

    // MARK: - Billing Period

    var period: String {
        switch self {
        case .weekly:
            return "/week"

        case .monthly:
            return "/month"

        case .annual:
            return "/year"

        case .lifetime:
            return ""
        }
    }

    var badge: String? {
        switch self {
        case .weekly:
            return "STARTER"

        case .monthly:
            return "3-DAY FREE TRIAL"

        case .annual:
            return "BEST VALUE"

        case .lifetime:
            return "RECOMMENDED"
        }
    }


    var detail: String {
        switch self {
        case .weekly:
            return "Auto-renew weekly."

        case .monthly:
            return "Auto-renew monthly."

        case .annual:
            return "Auto-renew yearly."

        case .lifetime:
            return "One-time payment."
        }
    }

    // MARK: - UI State

    var isHighlighted: Bool {
        self == .annual
    }

    // MARK: - Subscription Type

    var isAutoRenewable: Bool {
        self != .lifetime
    }
}

// MARK: - Premium Benefit

struct PremiumBenefit: Identifiable, Hashable {

    let id = UUID()
    let title: String
    let detail: String

    static let all: [PremiumBenefit] = [

        PremiumBenefit(
            title: "More Streaming Providers",
            detail: "Discover movies available from every supported streaming provider."
        ),

        PremiumBenefit(
            title: "Provider Filtering",
            detail: "Filter movie discovery by your connected streaming providers."
        ),

        PremiumBenefit(
            title: "Regional Availability",
            detail: "Check movie availability for your selected App Store region."
        ),

        PremiumBenefit(
            title: "Full Library Tools",
            detail: "Organize movies with statuses, ratings, notes, favorites, and collections."
        )
    ]
}
