import SwiftUI
import Combine
/// The sections available in the sidebar. Drives which content the home
/// screen shows without needing a separate view per tab.
enum SidebarSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case topRated = "Top Rated"
    case upcoming = "Upcoming"
    case nowPlaying = "Now Playing"
    case watchlist = "Watchlist"
    case recent = "Recent"
    case settings = "Settings"

    var id: String { rawValue }

    var assetName: String {
        switch self {
        case .home: "HomeIcon"
        case .topRated: "TopRated"
        case .upcoming: "UpcomingIcon"
        case .nowPlaying: "NowPlayingIcon"
        case .watchlist: "WatchlistIcon"
        case .recent: "RecentIcon"
        case .settings: "SettingIcon"
        }
    }

    var fallbackSymbol: String {
        switch self {
        case .home: "house.fill"
        case .topRated: "star.fill"
        case .upcoming: "calendar"
        case .nowPlaying: "play.circle.fill"
        case .watchlist: "bookmark.fill"
        case .recent: "clock.fill"
        case .settings: "gearshape.fill"
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {

    @Published var selectedSection: SidebarSection = .home
    @Published var selectedGenre: Genre?

    @Published var presentedMovie: Movie?
    @Published var isShowingSubscription = false

    func select(_ section: SidebarSection) {
        selectedSection = section
        selectedGenre = nil
    }

    func select(genre: Genre) {
        selectedGenre = genre
        selectedSection = .home
    }

    func showDetails(for movie: Movie) {
        presentedMovie = movie
    }

    func showSubscription() {
        isShowingSubscription = true
    }
}
