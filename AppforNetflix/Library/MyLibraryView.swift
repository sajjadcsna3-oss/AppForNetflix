import SwiftUI

struct MyLibraryView: View {

    enum Tab: String, CaseIterable, Identifiable {
        case myList = "My List"
        case watching = "Watching"
        case watched = "Watched"
        case favorites = "Favorites"

        var id: String { rawValue }
    }

    @ObservedObject var watchlistViewModel: WatchlistViewModel
    @ObservedObject var libraryViewModel: LibraryViewModel

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: SettingsStore

    @State private var selectedTab: Tab = .myList

    private let columns = [
        GridItem(.adaptive(minimum: 250, maximum: 330), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Header

                VStack(alignment: .leading, spacing: 10) {

                    Text(
                        L10n.string(
                            "My Library",
                            languageCode: settings.languageCode
                        )
                    )
                    .font(Theme.Font.title(28))

                    Picker("", selection: $selectedTab) {
                        ForEach(Tab.allCases) { tab in
                            Text(
                                L10n.string(
                                    tab.rawValue,
                                    languageCode: settings.languageCode
                                )
                            )
                            .tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 290)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // MARK: - Content

                Group {
                    if movies.isEmpty {
                        EmptyStateView(
                            icon: emptyIcon,
                            title: L10n.string(
                                emptyTitle,
                                languageCode: settings.languageCode
                            ),
                            message: L10n.string(
                                emptyMessage,
                                languageCode: settings.languageCode
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 380)

                    } else {
                        LazyVGrid(
                            columns: columns,
                            alignment: .leading,
                            spacing: 14
                        ) {
                            ForEach(movies) { movie in
                                LibraryMovieCard(
                                    movie: movie,
                                    tab: selectedTab,
                                    onOpen: {
                                        router.showDetails(for: movie)
                                    },
                                    onRemove: {
                                        remove(movie)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.top, 24)
            }
            .padding(24)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
        .onAppear(perform: refresh)
        .onChange(of: selectedTab) { _, _ in
            refresh()
        }
    }

    // MARK: - Movies

    private var movies: [Movie] {
        switch selectedTab {

        case .myList:
            return watchlistViewModel.items.map(
                watchlistViewModel.asMovie
            )

        case .watching:
            return libraryViewModel
                .items(with: .watching)
                .map(libraryViewModel.asMovie)

        case .watched:
            return libraryViewModel
                .items(with: .watched)
                .map(libraryViewModel.asMovie)

        case .favorites:
            return libraryViewModel
                .favorites
                .map(libraryViewModel.asMovie)
        }
    }

    // MARK: - Refresh

    private func refresh() {
        watchlistViewModel.refresh()
        libraryViewModel.refresh()
    }

    // MARK: - Remove

    private func remove(_ movie: Movie) {
        switch selectedTab {

        case .myList:
            if watchlistViewModel.isSaved(movie) {
                watchlistViewModel.toggle(movie)
            }

        case .watching, .watched:
            libraryViewModel.setStatus(
                .none,
                for: movie
            )

        case .favorites:
            if libraryViewModel.isFavorite(movie) {
                libraryViewModel.toggleFavorite(movie)
            }
        }

        refresh()
    }

    // MARK: - Empty State

    private var emptyIcon: String {
        switch selectedTab {
        case .myList:
            return "bookmark"

        case .watching:
            return "play.circle"

        case .watched:
            return "checkmark.circle"

        case .favorites:
            return "heart"
        }
    }

    private var emptyTitle: String {
        switch selectedTab {
        case .myList:
            return "Your list is empty"

        case .watching:
            return "Nothing marked as Watching"

        case .watched:
            return "Nothing marked as Watched"

        case .favorites:
            return "No favorites yet"
        }
    }

    private var emptyMessage: String {
        switch selectedTab {
        case .myList:
            return "Add movies from Movie Detail using My List."

        case .watching:
            return "Mark a movie as Watching from Movie Detail."

        case .watched:
            return "Mark a movie as Watched from Movie Detail."

        case .favorites:
            return "Favorite a movie from Movie Detail to see it here."
        }
    }
}

// MARK: - Library Movie Card

private struct LibraryMovieCard: View {

    let movie: Movie
    let tab: MyLibraryView.Tab
    let onOpen: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // MARK: Poster

            AsyncImage(url: movie.posterURL) { phase in
                switch phase {

                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)

                default:
                    Color.white.opacity(0.06)
                        .overlay {
                            Image(systemName: "film")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 76, height: 112)
            .clipShape(
                RoundedRectangle(cornerRadius: 7)
            )

            // MARK: Movie Information

            VStack(alignment: .leading, spacing: 7) {

                HStack(alignment: .top, spacing: 8) {

                    Text(movie.title)
                        .font(
                            .system(
                                size: 14,
                                weight: .semibold
                            )
                        )
                        .lineLimit(2)

                    Spacer(minLength: 4)

                    Menu {
                        Button(
                            "Open",
                            action: onOpen
                        )

                        Button(
                            "Remove",
                            role: .destructive,
                            action: onRemove
                        )

                    } label: {
                        Image(systemName: "ellipsis.vertical")
                            .foregroundStyle(.secondary)
                            .frame(
                                width: 20,
                                height: 20
                            )
                    }
                    .menuStyle(.borderlessButton)
                }

                // MARK: Rating

                HStack(spacing: 5) {

                    if !movie.year.isEmpty {
                        Text(movie.year)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .foregroundStyle(
                                .secondary.opacity(0.7)
                            )
                    }

                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)

                    Text(
                        String(
                            format: "%.1f",
                            movie.voteAverage
                        )
                    )
                    .foregroundStyle(.secondary)
                }
                .font(.system(size: 12))
                .lineLimit(1)

                // MARK: Status

                HStack(spacing: 6) {

                    statusIcon
                        .foregroundStyle(statusColor)

                    Text(statusText)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
                .font(
                    .system(
                        size: 12,
                        weight: .medium
                    )
                )

                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
        }
        .padding(10)
        .frame(
            maxWidth: .infinity,
            minHeight: 132,
            alignment: .leading
        )
        .background(
            Color.white.opacity(0.045)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 9)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(
                    Color.white.opacity(0.08),
                    lineWidth: 1
                )
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }

    // MARK: - Status

    private var statusText: String {
        switch tab {
        case .myList:
            return "In My List"

        case .watching:
            return "Watching"

        case .watched:
            return "Watched"

        case .favorites:
            return "Favorite"
        }
    }

    private var statusColor: Color {
        switch tab {
        case .myList:
            return .secondary

        case .watching:
            return Theme.accent

        case .watched:
            return .green

        case .favorites:
            return .red
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch tab {

        case .myList:
            Image(systemName: "bookmark.fill")

        case .watching:
            Image(systemName: "play.circle.fill")

        case .watched:
            Image(systemName: "checkmark.circle.fill")

        case .favorites:
            Image(systemName: "heart.fill")
        }
    }
}
