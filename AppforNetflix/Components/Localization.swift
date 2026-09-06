import Foundation

struct AppLanguage: Identifiable, Hashable {
    let code: String
    let nativeName: String
    var id: String { code }
    var locale: Locale { Locale(identifier: code) }
    var isRightToLeft: Bool { ["ar", "he", "ur"].contains(code) }
    var flag: String {
        switch code {
        case "en": "🇺🇸"
        case "ar": "🇸🇦"
        case "bn": "🇧🇩"
        case "cs": "🇨🇿"
        case "da": "🇩🇰"
        case "de": "🇩🇪"
        case "el": "🇬🇷"
        case "es": "🇪🇸"
        case "fi": "🇫🇮"
        case "fil": "🇵🇭"
        case "fr": "🇫🇷"
        case "he": "🇮🇱"
        case "hi": "🇮🇳"
        case "hr": "🇭🇷"
        case "hu": "🇭🇺"
        case "id": "🇮🇩"
        case "it": "🇮🇹"
        case "ja": "🇯🇵"
        case "ko": "🇰🇷"
        case "ms": "🇲🇾"
        case "nb": "🇳🇴"
        case "nl": "🇳🇱"
        case "pl": "🇵🇱"
        case "pt-PT": "🇵🇹"
        case "ro": "🇷🇴"
        case "ru": "🇷🇺"
        case "sk": "🇸🇰"
        case "sv": "🇸🇪"
        case "th": "🇹🇭"
        case "tr": "🇹🇷"
        case "uk": "🇺🇦"
        case "ur": "🇵🇰"
        case "vi": "🇻🇳"
        case "zh-Hans": "🇨🇳"
        case "zh-Hant": "🇹🇼"
        default: "🌐"
        }
    }

    static let supported: [AppLanguage] = [
        .init(code: "en", nativeName: "English"), .init(code: "ar", nativeName: "العربية"),
        .init(code: "bn", nativeName: "বাংলা"), .init(code: "cs", nativeName: "Čeština"),
        .init(code: "da", nativeName: "Dansk"), .init(code: "de", nativeName: "Deutsch"),
        .init(code: "el", nativeName: "Ελληνικά"), .init(code: "es", nativeName: "Español"),
        .init(code: "fi", nativeName: "Suomi"), .init(code: "fil", nativeName: "Filipino"),
        .init(code: "fr", nativeName: "Français"), .init(code: "he", nativeName: "עברית"),
        .init(code: "hi", nativeName: "हिन्दी"), .init(code: "hr", nativeName: "Hrvatski"),
        .init(code: "hu", nativeName: "Magyar"), .init(code: "id", nativeName: "Bahasa Indonesia"),
        .init(code: "it", nativeName: "Italiano"), .init(code: "ja", nativeName: "日本語"),
        .init(code: "ko", nativeName: "한국어"), .init(code: "ms", nativeName: "Bahasa Melayu"),
        .init(code: "nb", nativeName: "Norsk bokmål"), .init(code: "nl", nativeName: "Nederlands"),
        .init(code: "pl", nativeName: "Polski"), .init(code: "pt-PT", nativeName: "Português"),
        .init(code: "ro", nativeName: "Română"), .init(code: "ru", nativeName: "Русский"),
        .init(code: "sk", nativeName: "Slovenčina"), .init(code: "sv", nativeName: "Svenska"),
        .init(code: "th", nativeName: "ไทย"), .init(code: "tr", nativeName: "Türkçe"),
        .init(code: "uk", nativeName: "Українська"), .init(code: "ur", nativeName: "اردو"),
        .init(code: "vi", nativeName: "Tiếng Việt"), .init(code: "zh-Hans", nativeName: "简体中文"),
        .init(code: "zh-Hant", nativeName: "繁體中文")
    ]

    static var supportedCodes: [String] { supported.map(\.code) }
    static func displayName(for code: String) -> String {
        guard let language = supported.first(where: { $0.code == code }) else { return "🇺🇸 English" }
        return "\(language.flag) \(language.nativeName)"
    }
    static func normalizedCode(_ value: String) -> String {
        if supportedCodes.contains(value) { return value }
        return supported.first { $0.nativeName == value }?.code ?? legacyCodes[value] ?? "en"
    }
    static func apiCode(for code: String) -> String {
        switch normalizedCode(code) {
        case "en": return "en-US"
        case "ar": return "ar-SA"
        case "bn": return "bn-BD"
        case "cs": return "cs-CZ"
        case "da": return "da-DK"
        case "de": return "de-DE"
        case "el": return "el-GR"
        case "es": return "es-ES"
        case "fi": return "fi-FI"
        case "fil": return "tl-PH"
        case "fr": return "fr-FR"
        case "he": return "he-IL"
        case "hi": return "hi-IN"
        case "hr": return "hr-HR"
        case "hu": return "hu-HU"
        case "id": return "id-ID"
        case "it": return "it-IT"
        case "ja": return "ja-JP"
        case "ko": return "ko-KR"
        case "ms": return "ms-MY"
        case "nb": return "nb-NO"
        case "nl": return "nl-NL"
        case "pl": return "pl-PL"
        case "pt-PT": return "pt-PT"
        case "ro": return "ro-RO"
        case "ru": return "ru-RU"
        case "sk": return "sk-SK"
        case "sv": return "sv-SE"
        case "th": return "th-TH"
        case "tr": return "tr-TR"
        case "uk": return "uk-UA"
        case "ur": return "ur-PK"
        case "vi": return "vi-VN"
        case "zh-Hans": return "zh-CN"
        case "zh-Hant": return "zh-TW"
        default: return normalizedCode(code)
        }
    }
    private static let legacyCodes = ["English":"en", "French":"fr", "German":"de", "Japanese":"ja", "Chinese":"zh-Hans", "Korean":"ko"]
}

extension SettingsStore { var languageCode: String { AppLanguage.normalizedCode(language) } }
extension SettingsStore {
    var selectedLanguage: AppLanguage {
        AppLanguage.supported.first { $0.code == languageCode } ?? AppLanguage.supported[0]
    }
}

enum L10n {
    static func bundle(for languageCode: String) -> Bundle {
        let code = AppLanguage.normalizedCode(languageCode)
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) { return bundle }
        if let path = Bundle.main.path(forResource: "en", ofType: "lproj"), let bundle = Bundle(path: path) { return bundle }
        return .main
    }
    static func string(_ key: String, languageCode: String? = nil) -> String {
        let code = AppLanguage.normalizedCode(languageCode ?? UserDefaults.standard.string(forKey: "settings.language") ?? "en")
        let localized = NSLocalizedString(key, tableName: "Localizable", bundle: bundle(for: code), value: key, comment: "")
        if localized != key { return localized }

        let english = NSLocalizedString(key, tableName: "Localizable", bundle: bundle(for: "en"), value: key, comment: "")
        return english != key ? english : fallbackValues[key] ?? key
    }
    static func format(_ key: String, languageCode: String? = nil, _ arguments: CVarArg...) -> String {
        let code = AppLanguage.normalizedCode(languageCode ?? UserDefaults.standard.string(forKey: "settings.language") ?? "en")
        return String(format: string(key, languageCode: code), locale: Locale(identifier: code), arguments: arguments)
    }

    private static let fallbackValues = [
        "network_server_error_format": "Something went wrong (code %lld).",
        "on_platform_format": "On %@",
        "search_no_results_format": "No results found for “%@”."
    ]
}
