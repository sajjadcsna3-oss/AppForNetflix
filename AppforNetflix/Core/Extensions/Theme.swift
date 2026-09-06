import SwiftUI

enum AppColorScheme: String, CaseIterable, Identifiable {
    case dark = "Dark"
    case light = "Light"
    case system = "System"
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

enum Theme {
    static let accent = Color(hex: "E50914")
    static let accentPressed = Color(hex: "B0060F")

    static var background: Color {
        Color(light: Color(hex: "F5F5F7"), dark: Color(hex: "0B0B0F"))
    }
    static var surface: Color {
        Color(light: .white, dark: Color(hex: "16161C"))
    }
    static var surfaceElevated: Color {
        Color(light: Color(hex: "EAEAEF"), dark: Color(hex: "1E1E26"))
    }
    static var border: Color {
        Color(light: .black.opacity(0.08), dark: .white.opacity(0.08))
    }

    static var textPrimary: Color {
        Color(light: .black, dark: .white)
    }
    static var textSecondary: Color {
        Color(light: .black.opacity(0.65), dark: .white.opacity(0.65))
    }
    static var textTertiary: Color {
        Color(light: .black.opacity(0.4), dark: .white.opacity(0.4))
    }

    static let success = Color(hex: "3DDC84")
    static let warning = Color(hex: "F5C518")
    static let danger = accent

    enum Font {
        static func title(_ size: CGFloat = 32) -> SwiftUI.Font {
            .appBold(size)
        }
        static func heading(_ size: CGFloat = 20) -> SwiftUI.Font {
            .appBold(size)
        }
        static func semibold(_ size: CGFloat = 14) -> SwiftUI.Font {
            .appSemibold(size)
        }
        static func body(_ size: CGFloat = 14) -> SwiftUI.Font {
            .appRegular(size)
        }
        static func caption(_ size: CGFloat = 12) -> SwiftUI.Font {
            .appMedium(size)
        }
    }

    enum Metrics {
        static let cornerRadius: CGFloat = 10
        static let sidebarWidth: CGFloat = 230
        static let cardWidth: CGFloat = 190
        static let cardHeight: CGFloat = 280
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
    init(light: Color, dark: Color) {
        #if canImport(AppKit)
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(dark)
            } else {
                return NSColor(light)
            }
        }))
        #else
        self = dark
        #endif
    }
}
