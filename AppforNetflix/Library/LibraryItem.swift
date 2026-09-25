import Foundation
import SwiftData

enum LibraryStatus: String, CaseIterable, Identifiable, Codable {
    case none
    case wantToWatch
    case watching
    case watched

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .wantToWatch: "Want to Watch"
        case .watching: "Watching"
        case .watched: "Watched"
        }
    }
}

@Model
final class LibraryItem {
    @Attribute(.unique) var movieID: Int
    var title: String
    var posterPath: String?
    var voteAverage: Double
    var statusRawValue: String
    var isFavorite: Bool
    var personalRating: Int?
    var personalNotes: String = ""
    var watchProgress: Double = 0
    var updatedAt: Date

    var status: LibraryStatus {
        get { LibraryStatus(rawValue: statusRawValue) ?? .none }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        movie: Movie,
        status: LibraryStatus = .none,
        isFavorite: Bool = false,
        personalRating: Int? = nil,
        personalNotes: String = "",
        watchProgress: Double = 0,
        updatedAt: Date = .now
    ) {
        movieID = movie.id
        title = movie.title
        posterPath = movie.posterPath
        voteAverage = movie.voteAverage
        statusRawValue = status.rawValue
        self.isFavorite = isFavorite
        self.personalRating = personalRating
        self.personalNotes = personalNotes
        self.watchProgress = watchProgress
        self.updatedAt = updatedAt
    }
}

extension Movie {
    init(libraryItem item: LibraryItem) {
        self.init(
            id: item.movieID,
            title: item.title,
            overview: "",
            posterPath: item.posterPath,
            backdropPath: nil,
            voteAverage: item.voteAverage,
            releaseDate: nil,
            genreIDs: [],
            runtimeMinutes: nil
        )
    }
}
