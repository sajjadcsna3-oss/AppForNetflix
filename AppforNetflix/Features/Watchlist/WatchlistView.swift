import SwiftUI

struct WatchlistView: View {
    @ObservedObject var viewModel: WatchlistViewModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: SettingsStore
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n.string("Watchlist", languageCode: settings.languageCode))
                    .font(Theme.Font.title(28))
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                if viewModel.items.isEmpty {
                    EmptyStateView(
                        icon: "bookmark",
                        title: L10n.string("Your watchlist is empty", languageCode: settings.languageCode),
                        message: L10n.string("Titles you save will show up here so you can pick up right where you left off.", languageCode: settings.languageCode)
                    )
                    .frame(height: 400)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.items) { item in
                            let movie = viewModel.asMovie(item)
                            MovieCard(movie: movie) { router.showDetails(for: movie) }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
        .onAppear { viewModel.refresh() }
    }
}
