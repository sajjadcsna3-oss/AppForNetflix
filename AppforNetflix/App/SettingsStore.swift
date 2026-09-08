import Foundation
import Combine

@MainActor
final class SettingsStore: ObservableObject {
    static let freePlatformConnectionLimit = 1
    @Published var region: String { didSet { defaults.set(region, forKey: Keys.region) } }
    @Published var language: String { didSet { defaults.set(language, forKey: Keys.language) } }
    @Published var videoQuality: String { didSet { defaults.set(videoQuality, forKey: Keys.videoQuality) } }
    @Published var subtitles: String { didSet { defaults.set(subtitles, forKey: Keys.subtitles) } }
    @Published var autoplayNext: Bool { didSet { defaults.set(autoplayNext, forKey: Keys.autoplayNext) } }
    /// A display cache updated only from verified StoreKit entitlements.
    @Published private(set) var isPremium: Bool
    @Published var userName: String { didSet { defaults.set(userName, forKey: Keys.userName) } }
    @Published var userEmail: String { didSet { defaults.set(userEmail, forKey: Keys.userEmail) } }
    @Published var connectedPlatformIDs: Set<Int> { didSet { defaults.set(Array(connectedPlatformIDs), forKey: Keys.connectedPlatforms) } }
    @Published var appearance: AppColorScheme { didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) } }

    // One shared selection used by Home filter bar and TopBar.
    @Published var selectedPlatform: Platform? {
        didSet { defaults.set(selectedPlatform?.id, forKey: Keys.selectedPlatform) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let region = "settings.region"
        static let language = "settings.language"
        static let videoQuality = "settings.videoQuality"
        static let subtitles = "settings.subtitles"
        static let autoplayNext = "settings.autoplayNext"
        static let legacyAutoplay = "settings.autoplayTrailers"
        static let userName = "settings.userName"
        static let userEmail = "settings.userEmail"
        static let connectedPlatforms = "settings.connectedPlatforms"
        static let appearance = "settings.appearance"
        static let selectedPlatform = "settings.selectedPlatformID"
        static let isPremiumUser = "isPremiumUser"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.region = defaults.string(forKey: Keys.region) ?? "Kingdom of Qatar"
        self.language = AppLanguage.normalizedCode(
            defaults.string(forKey: Keys.language) ?? "en"
        )
        self.videoQuality = defaults.string(forKey: Keys.videoQuality) ?? "Auto (4K)"
        self.subtitles = defaults.string(forKey: Keys.subtitles) ?? "Off"
        self.autoplayNext = defaults.object(forKey: Keys.autoplayNext) as? Bool
            ?? defaults.object(forKey: Keys.legacyAutoplay) as? Bool
            ?? true
        self.isPremium = defaults.bool(forKey: Keys.isPremiumUser)
        self.userName = defaults.string(forKey: Keys.userName) ?? ""
        self.userEmail = defaults.string(forKey: Keys.userEmail) ?? ""

        let stored = defaults.array(forKey: Keys.connectedPlatforms) as? [Int]
            ?? [Platform.netflix.id, Platform.primeVideo.id, Platform.appleTVPlus.id, Platform.max.id, Platform.hulu.id]
        self.connectedPlatformIDs = Set(stored)

        let appearanceRaw = defaults.string(forKey: Keys.appearance) ?? AppColorScheme.dark.rawValue
        self.appearance = AppColorScheme(rawValue: appearanceRaw) ?? .dark

        let storedPlatformID = defaults.object(forKey: Keys.selectedPlatform) as? Int
        self.selectedPlatform = storedPlatformID.flatMap { id in
            Platform.filterBar.first { $0.id == id }
        }

        // Persist migration from a formerly exposed but incomplete locale so
        // localization calls that do not receive the store still agree.
        defaults.set(self.language, forKey: Keys.language)
    }

    func toggleConnection(for platform: Platform) {
        if connectedPlatformIDs.contains(platform.id) {
            connectedPlatformIDs.remove(platform.id)
            // A disconnected service cannot remain the active Home filter.
            if selectedPlatform?.id == platform.id {
                selectedPlatform = nil
            }
        } else {
            connectedPlatformIDs.insert(platform.id)
        }
    }

    func isConnected(_ platform: Platform) -> Bool {
        connectedPlatformIDs.contains(platform.id)
    }

    func effectiveConnectedPlatformIDs(isPremium: Bool) -> Set<Int> {
        guard !isPremium else { return connectedPlatformIDs }
        let allowedIDs = Platform.all
            .map(\.id)
            .filter(connectedPlatformIDs.contains)
            .prefix(Self.freePlatformConnectionLimit)
        return Set(allowedIDs)
    }

    func canConnect(_ platform: Platform, isPremium: Bool) -> Bool {
        if isPremium { return true }
        let effectiveIDs = effectiveConnectedPlatformIDs(isPremium: false)
        if isConnected(platform) { return effectiveIDs.contains(platform.id) }
        return effectiveIDs.count < Self.freePlatformConnectionLimit
    }

    func updatePremiumEntitlement(_ isPremium: Bool) {
        self.isPremium = isPremium
        defaults.set(isPremium, forKey: Keys.isPremiumUser)
        if !isPremium && (videoQuality == "Auto (4K)" || videoQuality == "4K") {
            videoQuality = "1080p"
        }
    }

    func clearAccountData() {
        userName = ""
        userEmail = ""
        selectedPlatform = nil
        connectedPlatformIDs = []
    }
}
