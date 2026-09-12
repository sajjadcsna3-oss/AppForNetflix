//
//  AppFonts.swift
//  AppForNetflix
//
//  Single source of truth for every font used in the app.
//

import SwiftUI
import CoreText

#if canImport(AppKit)
import AppKit
#endif

enum CustomFontLoader {
    private static var registeredNames: Set<String> = []

    static func register(candidateNames: [String], extensions: [String] = ["ttf", "otf"]) {
        for name in candidateNames {
            if registeredNames.contains(name) { return }
            for ext in extensions {
                guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { continue }
                var error: Unmanaged<CFError>?
                if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                    registeredNames.insert(name)
                    return
                }
            }
        }
    }
}

enum AppFont {

    static func sfPro(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    private static let pollerOneCandidates = ["PollerOne-Regular", "Poller_One", "PollerOne"]

    static func pollerOne(size: CGFloat) -> Font {
        CustomFontLoader.register(candidateNames: pollerOneCandidates)
        #if canImport(AppKit)
        if let match = pollerOneCandidates.first(where: { NSFont(name: $0, size: size) != nil }) {
            return .custom(match, size: size)
        }
        #endif
        return .system(size: size, weight: .regular, design: .serif)
    }
}

extension Font {
    static func wordmark(size: CGFloat = 26.47) -> Font { AppFont.pollerOne(size: size) }

    static func appBold(_ size: CGFloat) -> Font { AppFont.sfPro(size, weight: .bold) }
    static func appSemibold(_ size: CGFloat) -> Font { AppFont.sfPro(size, weight: .semibold) }
    static func appMedium(_ size: CGFloat) -> Font { AppFont.sfPro(size, weight: .medium) }
    static func appRegular(_ size: CGFloat) -> Font { AppFont.sfPro(size, weight: .regular) }
}

extension View {
    func wordmarkStyle(size: CGFloat = 26.47, tracking: CGFloat = -0.96) -> some View {
        self
            .font(.wordmark(size: size))
            .tracking(tracking)
            .foregroundStyle(Color.white)
    }

    func taglineStyle() -> some View {
        self
            .font(.appSemibold(12))
            .tracking(2.5)
    }
}
