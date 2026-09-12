import Foundation
import Combine

@MainActor
final class SettingsStore: ObservableObject {
    static let freeProviderIDs: Set<Int> = [
        Platform.netflix.id,
        Platform.primeVideo.id
    ]
    @Published var region: String { didSet { defaults.set(region, forKey: Keys.region) } }
    @Published var language: String { didSet { defaults.set(language, forKey: Keys.language) } }
    @Published var videoQuality: String { didSet { defaults.set(videoQuality, forKey: Keys.videoQuality) } }
    @Published var subtitles: String { didSet { defaults.set(subtitles, forKey: Keys.subtitles) } }
    @Published var autoplayNext: Bool { didSet { defaults.set(autoplayNext, forKey: Keys.autoplayNext) } }
    /// A display cache updated only from verified StoreKit entitlements.
    @Published private(set) var isPremium: Bool
    @Published var connectedPlatformIDs: Set<Int> { didSet { defaults.set(Array(connectedPlatformIDs), forKey: Keys.connectedPlatforms) } }
    @Published private(set) var availableWatchProviders: [WatchProvider] = []
    @Published var appearance: AppColorScheme { didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) } }

    /// Quick filter used only by the lower Home provider row.
    @Published var selectedProviderID: Int? {
        didSet { defaults.set(selectedProviderID, forKey: Keys.selectedPlatform) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let region = "settings.region"
        static let language = "settings.language"
        static let videoQuality = "settings.videoQuality"
        static let subtitles = "settings.subtitles"
        static let autoplayNext = "settings.autoplayNext"
        static let legacyAutoplay = "settings.autoplayTrailers"
        static let connectedPlatforms = "settings.connectedPlatforms"
        static let appearance = "settings.appearance"
        static let selectedPlatform = "settings.selectedPlatformID"
        static let isPremiumUser = "isPremiumUser"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.region = Country.find(
            defaults.string(forKey: Keys.region) ?? "QA"
        ).name
        self.language = AppLanguage.normalizedCode(
            defaults.string(forKey: Keys.language) ?? "en"
        )
        self.videoQuality = defaults.string(forKey: Keys.videoQuality) ?? "Auto (4K)"
        self.subtitles = defaults.string(forKey: Keys.subtitles) ?? "Off"
        self.autoplayNext = defaults.object(forKey: Keys.autoplayNext) as? Bool
            ?? defaults.object(forKey: Keys.legacyAutoplay) as? Bool
            ?? true
        self.isPremium = defaults.bool(forKey: Keys.isPremiumUser)

        let stored = defaults.array(forKey: Keys.connectedPlatforms) as? [Int]
            ?? Array(Self.freeProviderIDs)
        self.connectedPlatformIDs = Set(stored)

        let appearanceRaw = defaults.string(forKey: Keys.appearance) ?? AppColorScheme.dark.rawValue
        self.appearance = AppColorScheme(rawValue: appearanceRaw) ?? .dark

        self.selectedProviderID = defaults.object(forKey: Keys.selectedPlatform) as? Int

        // Persist migration from a formerly exposed but incomplete locale so
        // localization calls that do not receive the store still agree.
        defaults.set(self.language, forKey: Keys.language)
        defaults.set(self.region, forKey: Keys.region)
    }

    /// Normalized ISO 3166-1 alpha-2 code used for every regional TMDB call.
    var regionCode: String { Country.find(region).code.uppercased() }

    func toggleConnection(for platform: Platform) {
        toggleConnection(providerID: resolvedProviderID(for: platform))
    }

    func toggleConnection(providerID: Int) {
        if connectedPlatformIDs.contains(providerID) {
            connectedPlatformIDs.remove(providerID)
            // A disconnected service cannot remain the active Home filter.
            if selectedProviderID == providerID {
                selectedProviderID = nil
            }
        } else {
            connectedPlatformIDs.insert(providerID)
        }
    }

    func isConnected(_ platform: Platform) -> Bool {
        connectedPlatformIDs.contains(resolvedProviderID(for: platform))
    }

    func isConnected(providerID: Int) -> Bool {
        connectedPlatformIDs.contains(providerID)
    }

    func setConnectedProviderIDs(_ providerIDs: Set<Int>) {
        connectedPlatformIDs = providerIDs
        if let selectedProviderID, !providerIDs.contains(selectedProviderID) {
            self.selectedProviderID = nil
        }
    }

    func updateAvailableWatchProviders(_ providers: [WatchProvider]) {
        availableWatchProviders = providers
        reconcileConnectedProviders(availableProviderIDs: Set(providers.map(\.id)))
    }

    var enabledWatchProviders: [WatchProvider] {
        availableWatchProviders.filter { connectedPlatformIDs.contains($0.id) }
    }

    private func reconcileConnectedProviders(availableProviderIDs: Set<Int>) {
        let validSelection = connectedPlatformIDs.intersection(availableProviderIDs)
        if validSelection != connectedPlatformIDs {
            setConnectedProviderIDs(validSelection)
        }
    }

    func effectiveConnectedPlatformIDs(isPremium: Bool) -> Set<Int> {
        isPremium
            ? connectedPlatformIDs
            : connectedPlatformIDs.intersection(Self.freeProviderIDs)
    }

    func canConnect(_ platform: Platform, isPremium: Bool) -> Bool {
        canConnect(providerID: resolvedProviderID(for: platform), isPremium: isPremium)
    }

    func canConnect(providerID: Int, isPremium: Bool) -> Bool {
        isPremium || Self.freeProviderIDs.contains(providerID)
    }

    func resolvedProviderID(for platform: Platform) -> Int {
        availableWatchProviders.first {
            platform.tmdbProviderIDs.contains($0.id)
        }?.id ?? platform.tmdbProviderID ?? platform.id
    }

    func updatePremiumEntitlement(_ isPremium: Bool) {
        self.isPremium = isPremium
        defaults.set(isPremium, forKey: Keys.isPremiumUser)
        if !isPremium {
            setConnectedProviderIDs(
                connectedPlatformIDs.intersection(Self.freeProviderIDs)
            )
        }
        if !isPremium && (videoQuality == "Auto (4K)" || videoQuality == "4K") {
            videoQuality = "1080p"
        }
    }

}
