import SwiftUI

struct MovieDetailView: View {
    let movie: Movie
    let watchlistViewModel: WatchlistViewModel
    let recentViewModel: RecentViewModel

    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var storeKit: StoreKitService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var isSaved = false
    @State private var platforms: [WatchProvider] = []
    @State private var watchProvidersLink: URL?
    @State private var cast: [CastMember] = []
    @State private var similar: [Movie] = []
    @State private var isLoadingExtras = true
    @State private var isShowingSubscription = false
    @State private var shouldAddToWatchlistAfterPurchase = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(hex: "0D0D11").ignoresSafeArea()

            GeometryReader { proxy in
                AsyncImage(url: movie.backdropURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color(hex: "1F1F24")
                    }
                }
                .frame(width: proxy.size.width, height: 480)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color(hex: "0D0D11").opacity(0.1),
                            Color(hex: "0D0D11").opacity(0.8),
                            Color(hex: "0D0D11")
                        ],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
            }
            .frame(height: 480)
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 40) {
                    HStack(alignment: .top, spacing: 32) {
                        AsyncImage(url: movie.posterURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Theme.surfaceElevated
                            }
                        }
                        .frame(width: 240, height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)

                        VStack(alignment: .leading, spacing: 16) {
                            Text(movie.title)
                                .font(Theme.Font.title(36))
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.top, 20)
                                .fixedSize(horizontal: false, vertical: true)

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

                            HStack(spacing: 12) {
                                Button {
                                    openURL(watchNowURL())
                                } label: {
                                    Label(
                                        L10n.string("Watch Now", languageCode: settings.languageCode),
                                        systemImage: "play.fill"
                                    )
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Theme.accent)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    if storeKit.isConfigured && !settings.isPremium {
                                        shouldAddToWatchlistAfterPurchase = true
                                        isShowingSubscription = true
                                    } else {
                                        watchlistViewModel.toggle(movie)
                                        isSaved = watchlistViewModel.isSaved(movie)
                                    }
                                } label: {
                                    Label(
                                        isSaved
                                            ? L10n.string("In My List", languageCode: settings.languageCode)
                                            : L10n.string("My List", languageCode: settings.languageCode),
                                        systemImage: isSaved ? "checkmark" : "plus"
                                    )
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.15))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    openURL(trailerSearchURL())
                                } label: {
                                    Label(
                                        L10n.string("Trailer", languageCode: settings.languageCode),
                                        systemImage: "video"
                                    )
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.15))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }

                            Text(movie.overview)
                                .font(Theme.Font.body(15))
                                .foregroundStyle(.white.opacity(0.75))
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 80)
                    .padding(.horizontal, 40)

                    sectionContainer(title: L10n.string("AVAILABLE ON", languageCode: settings.languageCode)) {
                        if isLoadingExtras && platforms.isEmpty {
                            ProgressView().controlSize(.small)
                        } else if platforms.isEmpty {
                            // FIX: was a bare Text sitting flush against the
                            // section header with no container — looked
                            // unfinished. Now a small icon + text card,
                            // matching the app's existing badge style
                            // (rounded rect, subtle fill + hairline border).
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
                            HStack(spacing: 12) {
                                ForEach(platforms) { platform in
                                    HeroPlatformBadge(platform: platform)
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                    }

                    if !cast.isEmpty {
                        sectionContainer(title: L10n.string("CAST", languageCode: settings.languageCode)) {
                            HorizontalScrollWithArrows(items: Array(cast.prefix(15))) { member in
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

                    if !similar.isEmpty {
                        sectionContainer(title: L10n.string("SIMILAR TITLES", languageCode: settings.languageCode)) {
                            HorizontalScrollWithArrows(items: Array(similar.prefix(12))) { item in
                                MovieCard(movie: item) {
                                    router.showDetails(for: item)
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
        .frame(
            minWidth: 1000,
            idealWidth: 1000,
            minHeight: 900,
            idealHeight: 900
        )
        .onAppear {
            isSaved = watchlistViewModel.isSaved(movie)
            if !storeKit.isConfigured || settings.isPremium {
                recentViewModel.record(movie)
            }
        }
        .task(id: settings.languageCode) {
            await loadExtras()
        }
        .sheet(isPresented: $isShowingSubscription, onDismiss: continueWatchlistAddition) {
            SubscriptionView()
        }
    }

    private func continueWatchlistAddition() {
        guard shouldAddToWatchlistAfterPurchase else { return }
        shouldAddToWatchlistAfterPurchase = false
        guard storeKit.hasPremiumEntitlement else { return }

        if !watchlistViewModel.isSaved(movie) {
            watchlistViewModel.toggle(movie)
        }
        isSaved = watchlistViewModel.isSaved(movie)
    }

    private func loadExtras() async {
        isLoadingExtras = true
        let region = Country.find(settings.region).code

        async let providerAvailability = loadWatchProviders(region: region)
        async let credits = loadCast()
        async let similarMovies = loadSimilar()

        let (availability, c, s) = await (providerAvailability, credits, similarMovies)
        platforms = availability.providers
        watchProvidersLink = availability.link
        cast = c
        similar = s
        isLoadingExtras = false
    }

    private func loadWatchProviders(region: String) async -> WatchProviderAvailability {
        (try? await TMDBService.shared.watchProviders(
            id: movie.id,
            mediaType: .movie,
            region: region
        )) ?? .empty
    }

    private func loadCast() async -> [CastMember] {
        (try? await TMDBService.shared.credits(movieId: movie.id)) ?? []
    }

    private func loadSimilar() async -> [Movie] {
        (try? await TMDBService.shared.similar(movieId: movie.id)) ?? []
    }

    private var genreLine: String {
        Genre.all
            .filter { movie.genreIDs.contains($0.id) }
            .map {
                L10n.string($0.name, languageCode: settings.languageCode)
            }
            .joined(separator: " • ")
    }

    private func watchNowURL() -> URL {
        if let watchProvidersLink {
            return watchProvidersLink
        }

        let query = movie.title.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? movie.title
        return fallbackSearchURL(query: query)
    }

    private func fallbackSearchURL(query: String) -> URL {
        URL(string: "https://www.google.com/search?q=watch+\(query)")
            ?? URL(string: "https://www.google.com")!
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
