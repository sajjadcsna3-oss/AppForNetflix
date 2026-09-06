import Foundation

struct Genre: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let assetName: String
    let fallbackSymbol: String

    /// The standard TMDB movie genre list. Fetching this from the network
    /// buys nothing since it barely changes, so it's kept as a static list —
    /// one less network call and one less loading state to handle.
    ///
    /// `assetName` matches the icon names from the project's asset sheet
    /// exactly; `fallbackSymbol` is only used until that asset is added.
    static let all: [Genre] = [
        Genre(id: 28, name: "Action", assetName: "ActionIcon", fallbackSymbol: "bolt.fill"),
        Genre(id: 12, name: "Adventure", assetName: "AdventureIcon", fallbackSymbol: "map.fill"),
        Genre(id: 16, name: "Animation", assetName: "AnimationIcon", fallbackSymbol: "pencil.and.outline"),
        Genre(id: 35, name: "Comedy", assetName: "ComedyIcon", fallbackSymbol: "face.smiling.fill"),
        Genre(id: 80, name: "Crime", assetName: "Crime", fallbackSymbol: "person.fill.questionmark"),
        Genre(id: 99, name: "Documentary", assetName: "DocumentaryIcon", fallbackSymbol: "camera.fill"),
        Genre(id: 18, name: "Drama", assetName: "DramaIcon", fallbackSymbol: "theatermasks.fill"),
        Genre(id: 14, name: "Fantasy", assetName: "FantasyIcon", fallbackSymbol: "wand.and.stars"),
        Genre(id: 27, name: "Horror", assetName: "HorrorIcon", fallbackSymbol: "eye.fill"),
        Genre(id: 10402, name: "Music", assetName: "MusicIcon", fallbackSymbol: "music.note"),
        Genre(id: 9648, name: "Mystery", assetName: "MysteryIcon", fallbackSymbol: "questionmark.circle.fill"),
        Genre(id: 10749, name: "Romance", assetName: "RomanceIcon", fallbackSymbol: "heart.fill"),
        Genre(id: 878, name: "Science Fiction", assetName: "ScienceFictionIcon", fallbackSymbol: "sparkles")
    ]
}
