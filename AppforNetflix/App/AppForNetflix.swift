import SwiftUI
import SwiftData

@main
struct AppForNetflix: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var router = AppRouter()
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var storeKit = StoreKitService()
    var body: some Scene {
        WindowGroup("Screen Library") {
            RootView()
                .environmentObject(router)
                .environmentObject(settingsStore)
                .environmentObject(storeKit)
               
                .frame(minWidth: 1200, minHeight: 800)
                .preferredColorScheme(settingsStore.appearance.colorScheme)
                .environment(\.locale, Locale(identifier: settingsStore.languageCode))
                .environment(
                    \.layoutDirection,
                    settingsStore.selectedLanguage.isRightToLeft ? .rightToLeft : .leftToRight
                )
                .task {
                    await storeKit.prepare()
                    settingsStore.updatePremiumEntitlement(storeKit.hasPremiumEntitlement)
                }
                .onChange(of: storeKit.purchasedProductIDs) {
                    settingsStore.updatePremiumEntitlement(storeKit.hasPremiumEntitlement)
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await storeKit.refreshEntitlements()
                    }
                }
        }
        .modelContainer(for: [WatchlistItem.self, RecentlyViewedItem.self, LibraryItem.self, LibraryCollection.self])
     
        .windowResizability(.contentMinSize)
        .commands {
            ScreenLibraryCommands(router: router)
        }
    }
}

extension Notification.Name {
    static let focusLibrarySearch = Notification.Name("focusLibrarySearch")
}

private struct ScreenLibraryCommands: Commands {
    @ObservedObject var router: AppRouter

    var body: some Commands {
        CommandMenu("Navigate") {
            Button("Home") { router.select(.home) }
                .keyboardShortcut("1", modifiers: .command)
            Button("My Library") { router.select(.watchlist) }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Divider()
            Button("Search") {
                if router.selectedSection != .watchlist { router.select(.watchlist) }
                NotificationCenter.default.post(name: .focusLibrarySearch, object: nil)
            }
            .keyboardShortcut("f", modifiers: .command)
        }
    }
}

struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                HomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showSplash)
        .task {
            try? await Task.sleep(for: .seconds(1.6))
            showSplash = false
        }
    }
}
