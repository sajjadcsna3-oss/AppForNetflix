import Foundation

enum WatchMonetizationType: String, Codable, Hashable, CaseIterable {
    case flatrate
    case free
    case ads
    case rent
    case buy

    var label: String {
        switch self {
        case .flatrate: "Stream"
        case .free: "Free"
        case .ads: "Free with ads"
        case .rent: "Rent"
        case .buy: "Buy"
        }
    }
}

struct WatchProvider: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let logoPath: String?
    let displayPriority: Int
    let monetizationTypes: Set<WatchMonetizationType>

    var logoURL: URL? {
        guard let logoPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w92\(logoPath)")
    }

    var availabilityLabel: String {
        WatchMonetizationType.allCases
            .filter(monetizationTypes.contains)
            .map(\.label)
            .joined(separator: " / ")

    }
}

struct WatchProviderAvailability: Equatable {
    let link: URL?
    let providers: [WatchProvider]

    static let empty = WatchProviderAvailability(link: nil, providers: [])
}
