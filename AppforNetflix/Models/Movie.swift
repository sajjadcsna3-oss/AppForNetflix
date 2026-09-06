import Foundation

/// A single piece of content (movie or show). Mirrors just the fields the UI
/// actually needs from TMDB rather than the entire payload.
struct Movie: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let releaseDate: String?
    let genreIDs: [Int]
    let runtimeMinutes: Int?

    /// Platforms this title is available on. TMDB doesn't provide this for
    /// free, so it's populated from `WatchProvidersService` when available
    /// and defaults to an empty list otherwise — the UI treats that as
    /// "availability unknown" rather than showing a wrong platform.
    var platforms: [Platform] = []

    var year: String {
        guard let releaseDate, let year = releaseDate.split(separator: "-").first else { return "—" }
        return String(year)
    }

    var runtimeLabel: String {
        guard let runtimeMinutes else { return "—" }
        let hours = runtimeMinutes / 60
        let minutes = runtimeMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }

    var backdropURL: URL? {
        guard let backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/original\(backdropPath)")
    }

    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case releaseDate = "release_date"
        case genreIDs = "genre_ids"
        case runtimeMinutes = "runtime"
    }
}

extension Movie {
    /// Lightweight sample used for previews and empty-network fallbacks.
    static let placeholder = Movie(
        id: -1,
        title: "Crimson Protocol",
        overview: "When every intelligence agency in the world is compromised simultaneously, a disgraced analyst must go off-grid and assemble a team of burned spies to stop a digital apocalypse.",
        posterPath: nil,
        backdropPath: nil,
        voteAverage: 8.9,
        releaseDate: "2025-01-01",
        genreIDs: [28, 53],
        runtimeMinutes: 148
    )
}
