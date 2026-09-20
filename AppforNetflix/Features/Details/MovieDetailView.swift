import SwiftUI

struct MovieDetailView: View {
    let movie: Movie
    let selectedProviderIDs: Set<Int>
    let watchlistViewModel: WatchlistViewModel
    let recentViewModel: RecentViewModel
    let libraryViewModel: LibraryViewModel

    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @StateObject private var viewModel: MovieDetailViewModel
    @State private var isSaved = false
    @State private var isShowingPurchaseSuccess = false
    @State private var isShowingProviderPicker = false
    @State private var watchMessage: String?

    init(
        movie: Movie,
        selectedProviderIDs: Set<Int>,
        watchlistViewModel: WatchlistViewModel,
        recentViewModel: RecentViewModel,
        libraryViewModel: LibraryViewModel
    ) {
        self.movie = movie
        self.selectedProviderIDs = selectedProviderIDs
        self.watchlistViewModel = watchlistViewModel
        self.recentViewModel = recentViewModel
        self.libraryViewModel = libraryViewModel
        _viewModel = StateObject(wrappedValue: MovieDetailViewModel(movieID: movie.id))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(hex: "0D0D11").ignoresSafeArea()

            // Full-width TMDB backdrop, matching the supplied reference UI.
            GeometryReader { proxy in
                AsyncImage(url: movie.backdropURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Color(hex: "1F1F24")
                    }
                }
                .frame(width: proxy.size.width, height: 430)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [
                            Color(hex: "0D0D11").opacity(0.12),
                            Color(hex: "0D0D11").opacity(0.55),
                            Color(hex: "0D0D11")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay {
                    LinearGradient(
                        colors: [
                            Color(hex: "0D0D11").opacity(0.10),
                            Color(hex: "0D0D11").opacity(0.45)
                        ],
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                }
                .allowsHitTesting(false)
            }
            .frame(height: 430)
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 40) {
                    // Keep the PDF/reference composition: poster on the left,
                    // movie information and actions on the right.
                    headerRow(posterWidth: 230, posterHeight: 345)
                        .padding(.top, 54)
                        .padding(.horizontal, 40)

                    sectionContainer(title: L10n.string("AVAILABLE ON", languageCode: settings.languageCode)) {
                        if viewModel.isLoading && viewModel.platforms.isEmpty {
                            ProgressView().controlSize(.small)
                        } else if viewModel.platforms.isEmpty {
                            HStack(spacing: 10) {
                                Image(systemName: "tv.slash")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.35))

                                Text(L10n.string(
                                    "No streaming info for this region",
                                    languageCode: settings.languageCode
                                ))
                                .font(Theme.Font.caption(13))
                                .foregroundStyle(.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .padding(.horizontal, 40)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(displayedPlatforms) { platform in
                                        HeroPlatformBadge(platform: platform)
                                    }
                                }
                                .padding(.horizontal, 40)
                            }
                        }
                    }

                    if !viewModel.cast.isEmpty {
                        sectionContainer(title: L10n.string("CAST", languageCode: settings.languageCode)) {
                            HorizontalScrollWithArrows(items: Array(viewModel.cast.prefix(15))) { member in
                                VStack(spacing: 8) {
                                    AsyncImage(url: member.profileURL) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        default:
                                            Circle()
                                                .fill(Color.white.opacity(0.1))
                                                .overlay(
                                                    Image(systemName: "person.fill")
                                                        .font(.system(size: 28))
                                                        .foregroundStyle(.white.opacity(0.3))
                                                )
                                        }
                                    }
                                    .frame(width: 84, height: 84)
                                    .clipShape(Circle())

                                    Text(member.character)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)

                                    Text(member.name)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(width: 104)
                            }
                        }
                    }

                    if !viewModel.similarMovies.isEmpty {
                        sectionContainer(title: L10n.string("SIMILAR TITLES", languageCode: settings.languageCode)) {
                            HorizontalScrollWithArrows(items: Array(viewModel.similarMovies.prefix(12))) { item in
                                MovieCard(movie: item) {
                                    router.showDetails(for: item, providerIDs: selectedProviderIDs)
                                }
                                .frame(width: 150)
                            }
                        }
                    }
                }
                .padding(.bottom, 60)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(24)
        }
        .background(Color(hex: "0D0D11"))
        .foregroundStyle(Theme.textPrimary)
        // The reference design is a wide desktop detail sheet. Prevent the
        // window from becoming narrow enough to collapse it into a phone-like UI.
        .frame(
            minWidth: 900,
            idealWidth: 1040,
            minHeight: 620,
            idealHeight: 760
        )
        .onAppear {
            isSaved = watchlistViewModel.isSaved(movie)
            recentViewModel.record(movie)
        }
        .task(id: "\(settings.languageCode)|\(regionCode)") {
            await viewModel.load(region: regionCode)
        }
        .sheet(isPresented: $isShowingProviderPicker) {
            StreamingProviderPicker(providers: contextualWatchProviders) { provider in
                open(provider)
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
        .alert(
            L10n.string("Watch Now", languageCode: settings.languageCode),
            isPresented: Binding(
                get: { watchMessage != nil },
                set: { if !$0 { watchMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { watchMessage = nil }
        } message: {
            Text(watchMessage ?? "")
        }
    }

    // MARK: - Header layouts (wide / narrow)

    @ViewBuilder
    private func headerRow(posterWidth: CGFloat, posterHeight: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 32) {
            posterImage(width: posterWidth, height: posterHeight)
            infoColumn
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func headerColumn(posterWidth: CGFloat, posterHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            posterImage(width: posterWidth, height: posterHeight)
            infoColumn
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func posterImage(width: CGFloat, height: CGFloat) -> some View {
        AsyncImage(url: movie.posterURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Theme.surfaceElevated
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
    }

    private var infoColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(movie.title)
                .font(Theme.Font.title(36))
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.top, 20)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.warning)

                Text(String(format: "%.1f", movie.voteAverage))
                    .fontWeight(.bold)

                Text("•").foregroundStyle(.white.opacity(0.3))
                Text(movie.year)
                Text("•").foregroundStyle(.white.opacity(0.3))
                Text(movie.runtimeLabel)

                if !genreLine.isEmpty {
                    Text("•").foregroundStyle(.white.opacity(0.3))
                    Text(genreLine).lineLimit(1)
                }
            }
                .font(Theme.Font.caption(14))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.warning)
                        Text(String(format: "%.1f", movie.voteAverage)).fontWeight(.bold)
                        Text("•").foregroundStyle(.white.opacity(0.3))
                        Text(movie.year)
                        Text("•").foregroundStyle(.white.opacity(0.3))
                        Text(movie.runtimeLabel)
                    }
                    if !genreLine.isEmpty {
                        Text(genreLine)
                    }
                }
                .font(Theme.Font.caption(14))
                .foregroundStyle(.white.opacity(0.7))
            }

            // PDF/reference layout: all three primary actions stay on one row.
            HStack(spacing: 12) {
                Button {
                    openWatchDestination()
                } label: {
                    Label(
                        L10n.string("Watch Now", languageCode: settings.languageCode),
                        systemImage: "play.fill"
                    )
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(Theme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)

                Button {
                    openURL(trailerSearchURL())
                } label: {
                    Label(
                        L10n.string("Trailer", languageCode: settings.languageCode),
                        systemImage: "video"
                    )
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.15))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    watchlistViewModel.toggle(movie)
                    isSaved = watchlistViewModel.isSaved(movie)
                } label: {
                    Label(
                        isSaved
                            ? L10n.string("In My List", languageCode: settings.languageCode)
                            : L10n.string("My List", languageCode: settings.languageCode),
                        systemImage: isSaved ? "checkmark" : "plus"
                    )
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.15))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            MovieLibraryControls(
                movie: movie,
                libraryViewModel: libraryViewModel
            )

            Text(movie.overview)
                .font(Theme.Font.body(15))
                .foregroundStyle(.white.opacity(0.75))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
    }

    private var genreLine: String {
        Genre.all
            .filter { movie.genreIDs.contains($0.id) }
            .map {
                L10n.string($0.name, languageCode: settings.languageCode)
            }
            .joined(separator: " • ")
    }

    private var regionCode: String {
        settings.regionCode
    }

    /// Keep Available On aligned with the exact provider context used by the
    /// top selector. This removes unrelated channel/ad variants and reuses the
    /// selector's canonical TMDB logo and display name.
    private var displayedPlatforms: [WatchProvider] {
        let contextualPlatforms = selectedProviderIDs.isEmpty
            ? viewModel.platforms
            : viewModel.platforms.filter { selectedProviderIDs.contains($0.id) }

        return contextualPlatforms.map { provider in
            settings.availableWatchProviders.first { $0.id == provider.id }
                .map { canonical in
                    WatchProvider(
                        id: provider.id,
                        name: canonical.name,
                        logoPath: canonical.logoPath,
                        displayPriority: provider.displayPriority,
                        monetizationTypes: provider.monetizationTypes
                    )
                } ?? provider
        }
    }

    private var contextualWatchProviders: [WatchProvider] {
        let candidates = selectedProviderIDs.isEmpty
            ? viewModel.platforms
            : viewModel.platforms.filter { selectedProviderIDs.contains($0.id) }

        return candidates.sorted { lhs, rhs in
            let lhsStream = lhs.monetizationTypes.contains(.flatrate)
            let rhsStream = rhs.monetizationTypes.contains(.flatrate)
            if lhsStream != rhsStream { return lhsStream }
            return lhs.displayPriority < rhs.displayPriority
        }
    }

    private func openWatchDestination() {
        if let providerErrorMessage = viewModel.providerErrorMessage {
            watchMessage = providerErrorMessage
            return
        }

        guard !contextualWatchProviders.isEmpty else {
            watchMessage = L10n.string(
                "This title is not currently available on a supported streaming platform in your region.",
                languageCode: settings.languageCode
            )
            return
        }

        if contextualWatchProviders.count == 1,
           let provider = contextualWatchProviders.first {
            open(provider)
        } else {
            isShowingProviderPicker = true
        }
    }

    private func open(_ provider: WatchProvider) {
        guard let url = StreamingProviderLinkBuilder.searchURL(
            for: provider,
            title: movie.title
        ) else {
            watchMessage = L10n.string(
                "Direct link is unavailable for this provider.",
                languageCode: settings.languageCode
            )
            return
        }
        openURL(url)
    }

    private func trailerSearchURL() -> URL {
        let query = "\(movie.title) trailer"
        let encoded = query.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? query

        return URL(
            string: "https://www.youtube.com/results?search_query=\(encoded)"
        ) ?? URL(string: "https://www.youtube.com")!
    }

    @ViewBuilder
    private func sectionContainer<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 40)

            content()
        }
    }
}
