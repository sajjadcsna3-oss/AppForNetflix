import Foundation
import SwiftData

/// Persisted "recently viewed" entry, written whenever a user opens a
/// movie's details. Separate model from `WatchlistItem` since the two lists
/// have different lifecycles (this one is append/reorder-on-view; the
/// watchlist is explicit add/remove).
@Model
final class RecentlyViewedItem {
    @Attribute(.unique) var movieID: Int
    var title: String
    var posterPath: String?
    var voteAverage: Double
    var viewedAt: Date

    init(movie: Movie, viewedAt: Date = .now) {
        self.movieID = movie.id
        self.title = movie.title
        self.posterPath = movie.posterPath
        self.voteAverage = movie.voteAverage
        self.viewedAt = viewedAt
    }
}
