import SwiftUI

struct RecentView: View {
    @ObservedObject var viewModel: RecentViewModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: SettingsStore
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(L10n.string("Recent", languageCode: settings.languageCode))
                        .font(Theme.Font.title(28))
                    Spacer()
                    if !viewModel.items.isEmpty {
                        Button(L10n.string("Clear All", languageCode: settings.languageCode)) { viewModel.clear() }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.accent)
                            .font(Theme.Font.caption())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                if viewModel.items.isEmpty {
                    EmptyStateView(
                        icon: "clock",
                        title: L10n.string("Nothing viewed yet", languageCode: settings.languageCode),
                        message: L10n.string("Movies you open will show up here so you can find them again quickly.", languageCode: settings.languageCode)
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
