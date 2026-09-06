import SwiftUI

/// Streaming platforms definition matching exact Xcode Asset Names
struct Platform: Identifiable, Codable, Hashable {
    let id: Int
    /// TMDB watch-provider ID. nil means this platform is UI-only and cannot be queried via TMDB discover.
    let tmdbProviderID: Int?
    let name: String
    let logoAssetName: String        // Full Wordmark Logo (For Home Page Filter Bar)
    let squareLogoAssetName: String  // Square / Circle Badge (For TopBar Circles & Settings)
    let tint: String

    var logoScale: CGFloat = 1.0

    var color: Color { Color(hex: tint) }

    // Asset Names from your Xcode

    static let netflix = Platform(
        id: 8,
        tmdbProviderID: 8, name: "Netflix",
        logoAssetName: "Netflixlogo",
        squareLogoAssetName: "Netflexlogo",
        tint: "E50914"
    )
    static let primeVideo = Platform(
        id: 9,
        tmdbProviderID: 9, name: "Prime Video",
        logoAssetName: "amazon-prime-video-seeklogo 1",
        squareLogoAssetName: "PrimeVideologo",
        tint: "00A8E1"
    )
    static let disneyPlus = Platform(
        id: 337,
        tmdbProviderID: 337, name: "Disney+",
        logoAssetName: "DisnepLogo",
        squareLogoAssetName: "Disneylogo",
        tint: "113CCF"
    )
    static let appleTVPlus = Platform(
        id: 350,
        tmdbProviderID: 350, name: "Apple TV+",
        logoAssetName: "apple-tv-seeklogo 1",
        squareLogoAssetName: "AppleTvlogo",
        tint: "8E8E93"
    )
    static let hulu = Platform(
        id: 15,
        tmdbProviderID: 15, name: "Hulu",
        logoAssetName: "hululogo",
        squareLogoAssetName: "Hulu",
        tint: "1CE783",
    
        logoScale: 0.72
    )
    static let max = Platform(
        id: 384,
        tmdbProviderID: 384, name: "Max",
        logoAssetName: "Maxlogo",
        squareLogoAssetName: "Maxlogo",
        tint: "9B51E0"
    )
    static let peacock = Platform(
        id: 386,
        tmdbProviderID: 386, name: "Peacock",
        logoAssetName: "Peacocklogo",
        squareLogoAssetName: "Peacocklogo",
        tint: "F5A623"
    )
    static let imax = Platform(
        id: 9001,
        tmdbProviderID: nil, name: "iMax",
        logoAssetName: "imax-seeklogo 1",
        squareLogoAssetName: "imax-seeklogo 1",
        tint: "1FA7E0",
        // FIX: tightly-cropped source asset — scaled down so it matches
        // the visual weight of the padded logos next to it.
        logoScale: 0.68
    )

    /// Order matches the Figma "All Platforms" bar exactly:
    static let filterBar: [Platform] = [.netflix, .primeVideo, .disneyPlus, .appleTVPlus, .imax, .hulu]

    /// Order matches Settings -> Streaming Platforms:
    static let all: [Platform] = [.netflix, .primeVideo, .disneyPlus, .appleTVPlus, .max, .hulu, .peacock]
}
