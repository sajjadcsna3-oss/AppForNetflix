import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var storeKit: StoreKitService
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var recentViewModel = RecentViewModel()
    @StateObject private var libraryViewModel = LibraryViewModel()
    
    @State private var searchText = ""
    @State private var seeAllList: SeeAllList?
    @State private var isShowingPurchaseSuccess = false

    private enum SeeAllList: Identifiable, Equatable {
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
                    MyLibraryView(
                        libraryViewModel: libraryViewModel
                    )
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
            recentViewModel.configure(context: modelContext)
            libraryViewModel.configure(context: modelContext)
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
                selectedProviderIDs: router.presentedProviderIDs,
                recentViewModel: recentViewModel,
                libraryViewModel: libraryViewModel
            )
        }
        .sheet(isPresented: $router.isShowingSubscription, onDismiss: continuePendingPremiumDestination) {
            SubscriptionView {
                isShowingPurchaseSuccess = true
            }
        }
        .alert(
            L10n.string("Purchase Information", languageCode: settings.languageCode),
            isPresented: $isShowingPurchaseSuccess
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(L10n.string("Your purchase was successful.", languageCode: settings.languageCode))
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
    }

    private var regionCode: String {
        settings.regionCode
    }

    // FIX: Settings "Connected" platforms are only a preference.
    // They must not automatically restrict the Home API feed.
    private var loadContext: HomeLoadContext {
        HomeLoadContext(
            section: router.selectedSection,
            genre: router.selectedGenre,
            selectedProviderID: activeSelectedProviderID,
            connectedPlatformIDs: settings.effectiveConnectedPlatformIDs(isPremium: isPremiumUser),
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

                    preferredPlatformsHint

                    if searchText.isEmpty && !isPlainHome {
                        PlatformFilterBar(
                            providers: settings.availableWatchProviders,
                            selectedProviderID: $settings.selectedProviderID
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
    private var preferredPlatformsHint: some View {
        if settings.connectedPlatformIDs.isEmpty && searchText.isEmpty {
            Text(L10n.string(
                "No preferred streaming providers selected — showing titles from everywhere. Choose providers in Settings to personalize discovery.",
                languageCode: settings.languageCode
            ))
            .font(Theme.Font.caption(12))
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private var homeFilterTitle: String {
        if let provider = selectedQuickFilterProvider {
            return String(
                format: L10n.string("on_platform_format", languageCode: settings.languageCode),
                provider.name
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
                        onWatch: { showDetails(for: featured) },
                        onToggleWatchlist: {
                            libraryViewModel.toggleMyList(featured)
                        },
                        onInfo: {
                            showDetails(for: featured)
                        },
                        isSaved: libraryViewModel.isInMyList(featured)
                    )
                    .padding(.horizontal, 24)
                }

                PlatformFilterBar(
                    providers: settings.availableWatchProviders,
                    selectedProviderID: $settings.selectedProviderID
                )
                .padding(.horizontal, 24)

                MovieRow(
                    title: L10n.string("Continue Watching", languageCode: settings.languageCode),
                    movies: libraryViewModel.continueWatching.map(libraryViewModel.asMovie),
                    isLandscape: true,
                    progress: { libraryViewModel.item(for: $0)?.watchProgress },
                    isInMyList: { libraryViewModel.isInMyList($0) },
                    isFavorite: { libraryViewModel.isFavorite($0) },
                    onToggleMyList: { libraryViewModel.toggleMyList($0) },
                    onToggleFavorite: { libraryViewModel.toggleFavorite($0) },
                    onSelect: {
                        showDetails(for: $0)
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
                    isInMyList: { libraryViewModel.isInMyList($0) },
                    isFavorite: { libraryViewModel.isFavorite($0) },
                    onToggleMyList: { libraryViewModel.toggleMyList($0) },
                    onToggleFavorite: { libraryViewModel.toggleFavorite($0) },
                    onSelect: {
                        showDetails(for: $0)
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

    private func continuePendingPremiumDestination() {
        guard let destination = router.takePendingPremiumDestination(),
              storeKit.hasPremiumEntitlement else { return }

        switch destination {
        case .section(let section):
            router.select(section)
        case .addToWatchlist(let movie):
            if !libraryViewModel.isInMyList(movie) {
                libraryViewModel.setStatus(.wantToWatch, for: movie)
            }
        case .enablePlatforms(let providerIDs):
            settings.setConnectedProviderIDs(
                settings.connectedPlatformIDs.union(providerIDs)
            )
        case .selectProvider(let providerID):
            settings.connectedPlatformIDs.insert(providerID)
            settings.selectedProviderID = providerID
        }
    }

    private var selectedQuickFilterProvider: WatchProvider? {
        guard let selectedProviderID = activeSelectedProviderID else { return nil }
        return settings.enabledWatchProviders.first { $0.id == selectedProviderID }
    }

    /// Prevent a persisted or externally-mutated Premium provider ID from
    /// affecting content before StoreKit has verified current ownership.
    private var activeSelectedProviderID: Int? {
        guard let selectedProviderID = settings.selectedProviderID else { return nil }
        guard storeKit.hasPremiumEntitlement
                || SettingsStore.freeProviderIDs.contains(selectedProviderID) else {
            return nil
        }
        return selectedProviderID
    }

    private var isPremiumUser: Bool {
        storeKit.hasPremiumEntitlement
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
                    libraryMovieCard(movie)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func movies(for list: SeeAllList) -> [Movie] {
        switch list {
        case .continueWatching:
            return libraryViewModel.continueWatching.map(libraryViewModel.asMovie)
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
                    PosterGrid(
                        movies: results,
                        libraryViewModel: libraryViewModel
                    ) {
                        showDetails(for: $0)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 24)
        }
    }

    // UPDATED: adds a message specific to "connected but nothing found"
    private func emptyResultsMessage(title: String) -> String {
        if let provider = selectedQuickFilterProvider {
            return L10n.format(
                "platform_filter_empty_format",
                languageCode: settings.languageCode,
                provider.name,
                L10n.string(settings.region, languageCode: settings.languageCode)
            )
        }

        if !settings.connectedPlatformIDs.isEmpty {
            return L10n.string(
                "No titles found for your preferred providers. Try selecting more providers in Settings.",
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
            PosterGrid(
                movies: viewModel.searchResults,
                libraryViewModel: libraryViewModel
            ) {
                showDetails(for: $0)
            }
            .padding(24)
        }
    }

    private func showDetails(for movie: Movie) {
        let providerIDs: Set<Int>
        if let providerID = activeSelectedProviderID {
            providerIDs = [providerID]
        } else {
            providerIDs = settings.effectiveConnectedPlatformIDs(isPremium: isPremiumUser)
        }
        router.showDetails(for: movie, providerIDs: providerIDs)
    }

    private func libraryMovieCard(_ movie: Movie) -> some View {
        MovieCard(
            movie: movie,
            isInWatchlist: libraryViewModel.isInMyList(movie),
            onToggleWatchlist: { libraryViewModel.toggleMyList(movie) },
            isFavorite: libraryViewModel.isFavorite(movie),
            onToggleFavorite: { libraryViewModel.toggleFavorite(movie) },
            onSelect: { showDetails(for: movie) }
        )
    }
}

private struct PosterGrid: View {
    let movies: [Movie]
    @ObservedObject var libraryViewModel: LibraryViewModel
    var onSelect: (Movie) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(movies) { movie in
                MovieCard(
                    movie: movie,
                    isInWatchlist: libraryViewModel.isInMyList(movie),
                    onToggleWatchlist: { libraryViewModel.toggleMyList(movie) },
                    isFavorite: libraryViewModel.isFavorite(movie),
                    onToggleFavorite: { libraryViewModel.toggleFavorite(movie) }
                ) {
                    onSelect(movie)
                }
            }
        }
    }
}
