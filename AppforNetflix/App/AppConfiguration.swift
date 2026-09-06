import Foundation

enum AppConfiguration {
    private enum Key {
        static let tmdbAPIKey = "TMDBAPIKey"
        static let watchmodeAPIKey = "WatchmodeAPIKey"
    }

    static func string(for key: String) -> String {
        if let environmentValue = ProcessInfo.processInfo.environment[key],
           !environmentValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return environmentValue
        }

        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return "" }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("$(") else { return "" }
        return trimmed
    }

    static var privacyPolicyURL: URL? { URL(string: string(for: "PrivacyPolicyURL")) }
    static var termsOfServiceURL: URL? { URL(string: string(for: "TermsOfServiceURL")) }
    static var tmdbAPIKey: String { string(for: Key.tmdbAPIKey) }
    static var watchmodeAPIKey: String { string(for: Key.watchmodeAPIKey) }
}
