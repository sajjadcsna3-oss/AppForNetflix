import Foundation
import SwiftData

/// Persisted watchlist entry. Stores just enough of a `Movie` to render the
/// watchlist screen offline; full details are re-fetched on open if needed.
@Model
final class WatchlistItem {
    @Attribute(.unique) var movieID: Int
    var title: String
    var posterPath: String?
    var voteAverage: Double
    var addedAt: Date

    init(movie: Movie, addedAt: Date = .now) {
        self.movieID = movie.id
        self.title = movie.title
        self.posterPath = movie.posterPath
        self.voteAverage = movie.voteAverage
        self.addedAt = addedAt
    }
}
