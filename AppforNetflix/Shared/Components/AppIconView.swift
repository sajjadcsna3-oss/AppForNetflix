//
//  Appicon.swift
//  AppForNetflix
//
//  Created by Mac Mini on 26/08/2026.
//

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

/// Loads an icon from the asset catalog by name (e.g. "ActionIcon",
/// "Netflixlogo") and falls back to an SF Symbol if that asset hasn't been
/// added to the project yet. This means the app still runs and looks
/// reasonable before every custom icon/logo asset has been dropped in.
enum AppIcon {
    static func image(_ assetName: String, fallbackSymbol: String) -> Image {
        #if canImport(AppKit)
        if NSImage(named: assetName) != nil {
            return Image(assetName)
        }
        #endif
        return Image(systemName: fallbackSymbol)
    }
}

/// A view wrapper so call sites can use `AppIconView(...)` like any other
/// SwiftUI image and still get consistent, resizable rendering.
struct AppIconView: View {
    let assetName: String
    let fallbackSymbol: String
    var renderingMode: SwiftUI.Image.TemplateRenderingMode = .template

    var body: some View {
        AppIcon.image(assetName, fallbackSymbol: fallbackSymbol)
            .resizable()
            .renderingMode(renderingMode)
            .aspectRatio(contentMode: .fit)
    }
}
