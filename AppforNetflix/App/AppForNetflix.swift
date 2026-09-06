import SwiftUI
import SwiftData
import FirebaseCore

@main
struct AppForNetflix: App {
    @StateObject private var router = AppRouter()
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var authStore: AuthStore
    @StateObject private var storeKit = StoreKitService()

    init() {
        FirebaseApp.configure()
        _authStore = StateObject(wrappedValue: AuthStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(router)
                .environmentObject(settingsStore)
                .environmentObject(authStore)
                .environmentObject(storeKit)
                .frame(minWidth: 900, minHeight: 600)
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
        }
        .modelContainer(for: [WatchlistItem.self, RecentlyViewedItem.self])
        .windowResizability(.contentSize)
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
