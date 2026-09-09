import Foundation
import Combine

struct HomeLoadContext: Equatable {
    var section: SidebarSection
    var genre: Genre?
    var selectedProviderID: Int?
    var connectedPlatformIDs: Set<Int>   // NEW: user's "Connected" platforms from Settings
    var region: String
    var rating: Double
    var year: String
    var language: String

    static let initial = HomeLoadContext(
        section: .home, genre: nil, selectedProviderID: nil, connectedPlatformIDs: [],
        region: "US", rating: 0, year: "All Years", language: "en"
    )

    var needsGridLayout: Bool {
        genre != nil || selectedProviderID != nil || section != .home || rating > 0 || year != "All Years"
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }
    
    @Published var featured: Movie?
    @Published var continueWatching: [Movie] = []
    @Published var trending: [Movie] = []
    @Published var sectionResults: [Movie] = []
    @Published var searchResults: [Movie] = []
    @Published var isSearching = false
    @Published var searchErrorMessage: String?
    @Published var state: LoadState = .loading
    @Published var ratingFilter: Double = 0
    @Published var yearFilter: String = "All Years"
    
    private let service: TMDBService
    private let maxAutoPages = 10
    
    init(service: TMDBService = .shared) {
        self.service = service
    }
    
    func load(context: HomeLoadContext) async {
        state = .loading
        do {
            if !context.needsGridLayout {
                try await loadHome(region: context.region, connectedPlatformIDs: context.connectedPlatformIDs)
            } else {
                sectionResults = try await fetchAllPages(context: context)
            }
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
    
    // MARK: - Home (plain, non-grid) loading
    // NEW: now respects the user's "Connected" platforms from Settings.
    // If nothing is connected, falls back to showing everything so the
    // app never looks empty for a brand-new user.
    private func loadHome(region: String, connectedPlatformIDs: Set<Int>) async throws {
        async let trendingPage = fetchTrending(region: region, connectedPlatformIDs: connectedPlatformIDs)
        async let nowPlayingPage = fetchNowPlaying(region: region, connectedPlatformIDs: connectedPlatformIDs)
        
        let trendingResult = try await trendingPage
        let nowPlayingResult = try await nowPlayingPage
        
        trending = trendingResult.movies
        continueWatching = Array(nowPlayingResult.movies.prefix(8))
        
        var heroMovie = trendingResult.movies.first ?? .placeholder
        
        if heroMovie.id != Movie.placeholder.id {
            heroMovie.platforms = (try? await service.watchProviders(
                id: heroMovie.id,
                region: region
            ).providers) ?? []
        }
        featured = heroMovie
    }
    
    // NEW
    private func fetchTrending(region: String, connectedPlatformIDs: Set<Int>) async throws -> TMDBService.Page {
        guard !connectedPlatformIDs.isEmpty else {
            return try await service.trending(region: region, page: 1)
        }
        let filtered = try await service.discover(
            providerIDs: connectedPlatformIDs.sorted(),
            region: region,
            intent: .popular,
            page: 1
        )
        return filtered
    }
    
    // NEW
    private func fetchNowPlaying(region: String, connectedPlatformIDs: Set<Int>) async throws -> TMDBService.Page {
        guard !connectedPlatformIDs.isEmpty else {
            return try await service.nowPlaying(region: region, page: 1)
        }
        let filtered = try await service.discover(
            providerIDs: connectedPlatformIDs.sorted(),
            region: region,
            intent: .nowPlaying,
            page: 1
        )
        return filtered
    }
    
    private func fetchAllPages(context: HomeLoadContext) async throws -> [Movie] {
        let first = try await fetchSectionPage(context: context, page: 1)
        let lastPage = min(first.totalPages, maxAutoPages)
        guard lastPage > 1 else { return first.movies }
        
        var pagesByNumber: [Int: [Movie]] = [1: first.movies]
        try await withThrowingTaskGroup(of: (Int, [Movie]).self) { group in
            for page in 2...lastPage {
                group.addTask {
                    let result = try await self.fetchSectionPage(context: context, page: page)
                    return (page, result.movies)
                }
            }
            for try await (page, movies) in group {
                pagesByNumber[page] = movies
            }
        }
        return (1...lastPage).flatMap { pagesByNumber[$0] ?? [] }
    }
    
    // UPDATED: if the user hasn't picked a specific platform in the filter
    // bar, fall back to their "Connected" platforms from Settings instead
    // of showing everything unfiltered.
    private func fetchSectionPage(context: HomeLoadContext, page: Int) async throws -> TMDBService.Page {
        let intent: TMDBService.DiscoverIntent = context.genre != nil ? .popular : intent(for: context.section)
        let minRating = context.rating > 0 ? context.rating : nil
        let year = context.year == "All Years" ? nil : context.year
        
        // A quick-filter provider wins over the complete enabled-provider set.
        // Both values contain only real IDs returned by TMDB's regional catalog.
        let providerIDs = context.selectedProviderID.map { [$0] }
            ?? context.connectedPlatformIDs.sorted()
        
        let needsDiscover = context.genre != nil || !providerIDs.isEmpty || minRating != nil || year != nil
        
        if needsDiscover {
            let filtered = try await service.discover(
                genreID: context.genre?.id,
                providerIDs: providerIDs,
                region: context.region,
                intent: intent,
                minRating: minRating,
                year: year,
                page: page
            )
            if !filtered.movies.isEmpty { return filtered }

            // An empty provider-filtered result is meaningful. Never replace it
            // with unfiltered or another region's catalog.
            if !providerIDs.isEmpty { return filtered }

            if context.region != "US" {
                return try await service.discover(
                    genreID: context.genre?.id,
                    region: "US",
                    intent: intent,
                    minRating: minRating,
                    year: year,
                    page: page
                )
            }
            return filtered
        }

        let regional: TMDBService.Page
        switch intent {
        case .topRated: regional = try await service.topRated(region: context.region, page: page)
        case .upcoming: regional = try await service.upcoming(region: context.region, page: page)
        case .nowPlaying, .popular: regional = try await service.nowPlaying(region: context.region, page: page)
        }
        if !regional.movies.isEmpty || context.region == "US" { return regional }

        switch intent {
        case .topRated: return try await service.topRated(region: "US", page: page)
        case .upcoming: return try await service.upcoming(region: "US", page: page)
        case .nowPlaying, .popular: return try await service.nowPlaying(region: "US", page: page)
        }
    }
    
    private func intent(for section: SidebarSection) -> TMDBService.DiscoverIntent {
        switch section {
        case .topRated: .topRated
        case .upcoming: .upcoming
        case .nowPlaying: .nowPlaying
        case .home, .watchlist, .recent, .settings: .popular
        }
    }
    
    func search(_ query: String, region: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            searchErrorMessage = nil
            isSearching = false
            return
        }
        isSearching = true
        searchErrorMessage = nil
        defer { isSearching = false }
        do {
            let first = try await service.search(query: trimmedQuery, region: region, page: 1)
            let lastPage = min(first.totalPages, maxAutoPages)
            guard lastPage > 1 else {
                searchResults = first.movies
                return
            }
            var pagesByNumber: [Int: [Movie]] = [1: first.movies]
            try await withThrowingTaskGroup(of: (Int, [Movie]).self) { group in
                for page in 2...lastPage {
                    group.addTask {
                        let result = try await self.service.search(query: trimmedQuery, region: region, page: page)
                        return (page, result.movies)
                    }
                }
                for try await (page, movies) in group {
                    pagesByNumber[page] = movies
                }
            }
            searchResults = (1...lastPage).flatMap { pagesByNumber[$0] ?? [] }
        } catch {
            searchResults = []
            guard !Task.isCancelled else { return }
            searchErrorMessage = error.localizedDescription
        }
    }
    
    func filtered(_ movies: [Movie]) -> [Movie] {
        movies.filter { movie in
            let matchesRating = movie.voteAverage >= ratingFilter
            let matchesYear = yearFilter == "All Years" || movie.year == yearFilter
            return matchesRating && matchesYear
        }
    }
}
