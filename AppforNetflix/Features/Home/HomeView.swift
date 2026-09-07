import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var storeKit: StoreKitService
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var watchlistViewModel = WatchlistViewModel()
    @StateObject private var recentViewModel = RecentViewModel()
    
    @State private var searchText = ""
    @State private var seeAllList: SeeAllList?

    enum SeeAllList: Identifiable, Equatable {
        case continueWatching
        case trending

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .continueWatching:
                return "Continue Watching"
            case .trending:
                return "Trending Now"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
            
            Group {
                switch router.selectedSection {
                case .watchlist:
                    WatchlistView(viewModel: watchlistViewModel)
                case .recent:
                    RecentView(viewModel: recentViewModel)
                case .settings:
                    SettingsView()
                case .home, .topRated, .upcoming, .nowPlaying:
                    contentColumn
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
        .task {
            watchlistViewModel.configure(context: modelContext)
            recentViewModel.configure(context: modelContext)
        }
        .onAppear {
            auth.restoreSession(settings: settings)
        }
        .task(id: loadContext) {
            await viewModel.load(context: loadContext)
        }
        .task(id: "\(searchText)|\(settings.languageCode)") {
            try? await Task.sleep(for: .milliseconds(300))
            await viewModel.search(searchText, region: regionCode)
        }
        .sheet(item: $router.presentedMovie) { movie in
            MovieDetailView(
                movie: movie,
                watchlistViewModel: watchlistViewModel,
                recentViewModel: recentViewModel
            )
        }
        .sheet(isPresented: $router.isShowingSubscription) {
            SubscriptionView()
        }
        .onChange(of: router.selectedSection) {
            seeAllList = nil
        }
        .onChange(of: router.selectedGenre) {
            seeAllList = nil
        }
        .onChange(of: searchText) {
            if !searchText.isEmpty {
                seeAllList = nil
            }
        }
        .onChange(of: settings.isPremium) {
            guard storeKit.isConfigured, !settings.isPremium else { return }
            if router.selectedSection == .watchlist || router.selectedSection == .recent {
                router.select(.home)
            }
        }
    }

    private var regionCode: String {
        Country.find(settings.region).code
    }

    // FIX: Settings "Connected" platforms are only a preference.
    // They must not automatically restrict the Home API feed.
    private var loadContext: HomeLoadContext {
        HomeLoadContext(
            section: router.selectedSection,
            genre: router.selectedGenre,
            platform: settings.selectedPlatform,
            connectedPlatformIDs: settings.connectedPlatformIDs,
            region: regionCode,
            rating: viewModel.ratingFilter,
            year: viewModel.yearFilter,
            language: settings.languageCode
        )
    }

    private var isPlainHome: Bool {
        searchText.isEmpty
            && router.selectedGenre == nil
            && router.selectedSection == .home
            && !loadContext.needsGridLayout
    }

    @ViewBuilder
    private var contentColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let seeAllList {
                    seeAllHeader(seeAllList)
                    seeAllGrid(seeAllList)
                } else {
                    TopBar(searchText: $searchText, viewModel: viewModel)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .zIndex(1)

                    // NEW: lets a new user know why they're seeing everything
                    connectedPlatformsHint

                    if searchText.isEmpty && !isPlainHome {
                        PlatformFilterBar(
                            platforms: Platform.filterBar,
                            selected: $settings.selectedPlatform
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    }

                    if !searchText.isEmpty {
                        searchResultsSection
                    } else if let genre = router.selectedGenre {
                        listSection(title: genre.name, emptyIcon: "film")
                    } else if isPlainHome {
                        homeSection
                    } else if router.selectedSection == .home {
                        listSection(title: homeFilterTitle, emptyIcon: "tv")
                    } else {
                        listSection(
                            title: L10n.string(
                                router.selectedSection.rawValue,
                                languageCode: settings.languageCode
                            ),
                            emptyIcon: "square.stack"
                        )
                    }
                }
            }
        }
    }

    // NEW: shown only when nothing is connected yet, so the "show
    // everything" fallback doesn't feel like a silent bug to the user.
    @ViewBuilder
    private var connectedPlatformsHint: some View {
        if settings.connectedPlatformIDs.isEmpty && searchText.isEmpty {
            Text(L10n.string(
                "You haven't connected any streaming platforms yet — showing titles from everywhere. Connect platforms in Settings to personalize this.",
                languageCode: settings.languageCode
            ))
            .font(Theme.Font.caption(12))
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private var homeFilterTitle: String {
        if let platform = settings.selectedPlatform {
            return String(
                format: L10n.string("on_platform_format", languageCode: settings.languageCode),
                platform.name
            )
        }

        return L10n.string("Filtered Results", languageCode: settings.languageCode)
    }

    @ViewBuilder
    private var homeSection: some View {
        switch viewModel.state {
        case .loading:
            LoadingView(message: L10n.string("Loading titles…", languageCode: settings.languageCode))
                .frame(height: 500)

        case .failed(let message):
            ErrorStateView(message: message) {
                Task {
                    await viewModel.load(context: loadContext)
                }
            }
            .frame(height: 500)

        case .loaded:
            VStack(alignment: .leading, spacing: 28) {
                if let featured = viewModel.featured {
                    HeroBanner(
                        movie: featured,
                        onWatch: { router.showDetails(for: featured) },
                        onToggleWatchlist: {
                            if storeKit.isConfigured && !settings.isPremium {
                                router.showSubscription()
                            } else {
                                watchlistViewModel.toggle(featured)
                            }
                        },
                        onInfo: {
                            router.showDetails(for: featured)
                        },
                        isSaved: (!storeKit.isConfigured || settings.isPremium)
                            && watchlistViewModel.isSaved(featured)
                    )
                    .padding(.horizontal, 24)
                }

                PlatformFilterBar(
                    platforms: Platform.filterBar,
                    selected: $settings.selectedPlatform
                )
                .padding(.horizontal, 24)

                MovieRow(
                    title: L10n.string("Continue Watching", languageCode: settings.languageCode),
                    movies: viewModel.continueWatching,
                    isLandscape: true,
                    onSelect: {
                        router.showDetails(for: $0)
                    },
                    onSeeAll: {
                        seeAllList = .continueWatching
                    }
                )
                .padding(.horizontal, 24)

                MovieRow(
                    title: L10n.string("Trending Now", languageCode: settings.languageCode),
                    movies: viewModel.trending,
                    isLandscape: false,
                    onSelect: {
                        router.showDetails(for: $0)
                    },
                    onSeeAll: {
                        seeAllList = .trending
                    }
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func seeAllHeader(_ list: SeeAllList) -> some View {
        HStack(spacing: 14) {
            Button {
                seeAllList = nil
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))

                    Text(L10n.string("Back", languageCode: settings.languageCode))
                        .font(Theme.Font.body(14))
                        .fontWeight(.semibold)
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Text(list.title)
                .font(Theme.Font.title(24))

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func seeAllGrid(_ list: SeeAllList) -> some View {
        let movies = movies(for: list)

        if movies.isEmpty {
            EmptyStateView(
                icon: "tv",
                title: L10n.string("Nothing here yet", languageCode: settings.languageCode),
                message: String(
                    localized: "Titles will show up here once there's something to watch."
                )
            )
            .frame(height: 380)
        } else {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: 150, maximum: 200),
                        spacing: 16
                    )
                ],
                spacing: 16
            ) {
                ForEach(movies) { movie in
                    MovieCard(movie: movie) {
                        router.showDetails(for: movie)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func movies(for list: SeeAllList) -> [Movie] {
        switch list {
        case .continueWatching:
            return viewModel.continueWatching
        case .trending:
            return viewModel.trending
        }
    }

    @ViewBuilder
    private func listSection(
        title: String,
        emptyIcon: String
    ) -> some View {
        switch viewModel.state {
        case .loading:
            LoadingView(
                message: L10n.string("Loading all matching titles…", languageCode: settings.languageCode)
            )
            .frame(height: 500)

        case .failed(let message):
            ErrorStateView(message: message) {
                Task {
                    await viewModel.load(context: loadContext)
                }
            }
            .frame(height: 500)

        case .loaded:
            let results = viewModel.sectionResults

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(Theme.Font.title(24))

                    if !results.isEmpty {
                        Text(
                            L10n.format(
                                "title_count_format",
                                languageCode: settings.languageCode,
                                results.count
                            )
                        )
                        .font(Theme.Font.caption(13))
                        .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)

                if results.isEmpty {
                    EmptyStateView(
                        icon: emptyIcon,
                        title: L10n.string("No titles found", languageCode: settings.languageCode),
                        message: emptyResultsMessage(title: title)
                    )
                    .frame(height: 380)
                } else {
                    PosterGrid(movies: results) {
                        router.showDetails(for: $0)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 24)
        }
    }

    // UPDATED: adds a message specific to "connected but nothing found"
    private func emptyResultsMessage(title: String) -> String {
        if let platform = settings.selectedPlatform {
            return L10n.format(
                "platform_filter_empty_format",
                languageCode: settings.languageCode,
                platform.name,
                L10n.string(settings.region, languageCode: settings.languageCode)
            )
        }

        if !settings.connectedPlatformIDs.isEmpty {
            return L10n.string(
                "No titles found on your connected platforms for this filter. Try connecting more platforms in Settings.",
                languageCode: settings.languageCode
            )
        }

        return L10n.format(
            "try_adjusting_filters_format",
            languageCode: settings.languageCode,
            title
        )
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if viewModel.isSearching {
            LoadingView(message: L10n.string("Searching…", languageCode: settings.languageCode))
                .frame(height: 400)
        } else if let message = viewModel.searchErrorMessage {
            ErrorStateView(message: message) {
                Task { await viewModel.search(searchText, region: regionCode) }
            }
            .frame(height: 400)
        } else if viewModel.searchResults.isEmpty {
            EmptyStateView(
                icon: "magnifyingglass",
                title: L10n.string("No results", languageCode: settings.languageCode),
                message: L10n.format(
                    "search_no_results_format",
                    languageCode: settings.languageCode,
                    searchText
                )
            )
            .frame(height: 400)
        } else {
            PosterGrid(movies: viewModel.searchResults) {
                router.showDetails(for: $0)
            }
            .padding(24)
        }
    }
}

private struct PosterGrid: View {
    let movies: [Movie]
    var onSelect: (Movie) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(movies) { movie in
                MovieCard(movie: movie) {
                    onSelect(movie)
                }
            }
        }
    }
}
