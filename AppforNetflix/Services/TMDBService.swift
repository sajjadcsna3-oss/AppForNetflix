import Foundation

enum NetworkError: LocalizedError {
    case invalidResponse
    case server(Int)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return L10n.string("The server returned an unexpected response.")
        case .server(let code):
            return L10n.format("network_server_error_format", languageCode: nil, code)
        case .decoding:
            return L10n.string("Couldn't read the data we received.")
        }
    }
}

/// Thin wrapper around the TMDB REST API.
///
/// Platform filtering is done through TMDB's watch-provider parameters:
/// - with_watch_providers
/// - watch_region
/// - watch_monetization_types
///
/// Genre, rating and year can be combined with a platform filter.
actor TMDBService {
    static let shared = TMDBService()

    private let apiKey: String
    private let baseURL = URL(string: "https://api.themoviedb.org/3")!
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.apiKey = Secrets.tmdbAPIKey
        self.session = session
    }

    struct Page {
        let movies: [Movie]
        let currentPage: Int
        let totalPages: Int

        var hasMore: Bool {
            currentPage < totalPages
        }
    }

    enum MediaType: String {
        case movie
        case tv
    }

    private struct WatchProviderResponse: Decodable {
        let results: [String: CountryWatchProviders]
    }

    private struct WatchProviderCatalogResponse: Decodable {
        let results: [ProviderItem]
    }

    private struct CountryWatchProviders: Decodable {
        let link: URL?
        let flatrate: [ProviderItem]?
        let free: [ProviderItem]?
        let ads: [ProviderItem]?
        let rent: [ProviderItem]?
        let buy: [ProviderItem]?
    }

    private struct ProviderItem: Decodable {
        let providerID: Int
        let providerName: String
        let logoPath: String?
        let displayPriority: Int

        enum CodingKeys: String, CodingKey {
            case providerID = "provider_id"
            case providerName = "provider_name"
            case logoPath = "logo_path"
            case displayPriority = "display_priority"
        }
    }

    // MARK: - Simple Lists

    func trending(region: String = "US", page: Int = 1) async throws -> Page {
        try await fetchPage(
            path: "trending/movie/week",
            query: [:],
            page: page
        )
    }

    func topRated(region: String = "US", page: Int = 1) async throws -> Page {
        try await fetchPage(
            path: "movie/top_rated",
            query: ["region": region],
            page: page
        )
    }

    func upcoming(region: String = "US", page: Int = 1) async throws -> Page {
        try await fetchPage(
            path: "movie/upcoming",
            query: ["region": region],
            page: page
        )
    }

    func nowPlaying(region: String = "US", page: Int = 1) async throws -> Page {
        try await fetchPage(
            path: "movie/now_playing",
            query: ["region": region],
            page: page
        )
    }

    func search(
        query: String,
        region: String = "US",
        page: Int = 1
    ) async throws -> Page {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return Page(
                movies: [],
                currentPage: 1,
                totalPages: 1
            )
        }

        return try await fetchPage(
            path: "search/movie",
            query: [
                "query": trimmed,
                "region": region
            ],
            page: page
        )
    }

    // MARK: - Discover

    enum DiscoverIntent {
        case popular
        case topRated
        case upcoming
        case nowPlaying

        var sortBy: String {
            switch self {
            case .popular, .nowPlaying:
                return "popularity.desc"
            case .topRated:
                return "vote_average.desc"
            case .upcoming:
                return "primary_release_date.asc"
            }
        }

        var extraQuery: [String: String] {
            switch self {
            case .topRated:
                return [
                    "vote_count.gte": "200"
                ]

            case .upcoming:
                let formatter = ISO8601DateFormatter()
                let today = String(formatter.string(from: .now).prefix(10))

                return [
                    "primary_release_date.gte": today
                ]

            case .popular, .nowPlaying:
                return [:]
            }
        }
    }

    /// Fetch movies with any combination of:
    /// genre + streaming platform + region + rating + year.
    ///
    /// `providerIDs` are TMDB watch-provider IDs, not arbitrary app IDs.
    /// Multiple providers are joined with `|`, meaning OR:
    /// Netflix OR Prime Video OR Disney+, etc.
    func discover(
        genreID: Int? = nil,
        providerIDs: [Int] = [],
        region: String = "US",
        intent: DiscoverIntent = .popular,
        minRating: Double? = nil,
        year: String? = nil,
        page: Int = 1
    ) async throws -> Page {

        var query: [String: String] = [
            "sort_by": intent.sortBy,
            "include_adult": "false"
        ]

        query.merge(intent.extraQuery) { current, _ in
            current
        }

        // Genre filter
        if let genreID {
            query["with_genres"] = String(genreID)
        }

        // Streaming-platform filter
        let validProviderIDs = providerIDs.filter { $0 > 0 }

        if !validProviderIDs.isEmpty {
            query["with_watch_providers"] =
                validProviderIDs
                    .map(String.init)
                    .joined(separator: "|")

            // TMDB needs the region to know where the provider is available.
            query["watch_region"] = region.uppercased()

            // Include normal subscription services and free/ad-supported
            // availability where TMDB provides it.
            query["with_watch_monetization_types"] = "flatrate|free|ads"
        }

        // Rating filter
        if let minRating, minRating > 0 {
            query["vote_average.gte"] =
                String(format: "%.1f", minRating)

            if query["vote_count.gte"] == nil {
                query["vote_count.gte"] = "50"
            }
        }

        // Release year filter
        if let year,
           !year.isEmpty,
           year != "All Years" {
            query["primary_release_year"] = year
        }

        return try await fetchPage(
            path: "discover/movie",
            query: query,
            page: page
        )
    }

    // MARK: - Details

    func details(id: Int) async throws -> Movie {
        let url = makeURL(
            path: "movie/\(id)",
            query: [:]
        )

        let (data, response) = try await session.data(from: url)
        try Self.validate(response)

        do {
            return try JSONDecoder().decode(Movie.self, from: data)
        } catch {
            throw NetworkError.decoding
        }
    }

    func watchProviders(
        id: Int,
        mediaType: MediaType = .movie,
        region: String
    ) async throws -> WatchProviderAvailability {
        let url = makeURL(
            path: "\(mediaType.rawValue)/\(id)/watch/providers",
            query: [:]
        )

        let (data, response) = try await session.data(from: url)
        try Self.validate(response)

        let decoded: WatchProviderResponse
        do {
            decoded = try JSONDecoder().decode(WatchProviderResponse.self, from: data)
        } catch {
            throw NetworkError.decoding
        }

        guard let country = decoded.results[region.uppercased()] else {
            return .empty
        }

        var providersByID: [Int: WatchProvider] = [:]
        merge(country.flatrate, type: .flatrate, into: &providersByID)
        merge(country.free, type: .free, into: &providersByID)
        merge(country.ads, type: .ads, into: &providersByID)
        merge(country.rent, type: .rent, into: &providersByID)
        merge(country.buy, type: .buy, into: &providersByID)

        return WatchProviderAvailability(
            link: country.link,
            providers: providersByID.values.sorted {
                if $0.displayPriority == $1.displayPriority {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.displayPriority < $1.displayPriority
            }
        )
    }

    /// Returns TMDB's movie-provider catalog for a specific watch region.
    /// Provider IDs and logos come directly from TMDB and are safe to use in
    /// subsequent `discover/movie` requests.
    func movieWatchProviders(region: String? = nil) async throws -> [WatchProvider] {
        let query = region.map { ["watch_region": $0.uppercased()] } ?? [:]
        let url = makeURL(
            path: "watch/providers/movie",
            query: query
        )

        let (data, response) = try await session.data(from: url)
        try Self.validate(response)

        do {
            return try JSONDecoder()
                .decode(WatchProviderCatalogResponse.self, from: data)
                .results
                .map {
                    WatchProvider(
                        id: $0.providerID,
                        name: $0.providerName,
                        logoPath: $0.logoPath,
                        displayPriority: $0.displayPriority,
                        monetizationTypes: []
                    )
                }
                .sorted {
                    if $0.displayPriority == $1.displayPriority {
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    return $0.displayPriority < $1.displayPriority
                }
        } catch {
            throw NetworkError.decoding
        }
    }

    // MARK: - Credits

    private struct CreditsResponse: Codable {
        let cast: [CastMember]
    }

    func credits(movieId: Int) async throws -> [CastMember] {
        let url = makeURL(
            path: "movie/\(movieId)/credits",
            query: [:]
        )

        let (data, response) = try await session.data(from: url)
        try Self.validate(response)

        do {
            return try JSONDecoder()
                .decode(CreditsResponse.self, from: data)
                .cast
        } catch {
            throw NetworkError.decoding
        }
    }

    // MARK: - Similar

    func similar(movieId: Int) async throws -> [Movie] {
        try await fetchPage(
            path: "movie/\(movieId)/similar",
            query: [:],
            page: 1
        ).movies
    }

    // MARK: - Private

    private struct ListResponse: Codable {
        let results: [Movie]
        let page: Int?
        let totalPages: Int?

        enum CodingKeys: String, CodingKey {
            case results
            case page
            case totalPages = "total_pages"
        }
    }

    private func merge(
        _ items: [ProviderItem]?,
        type: WatchMonetizationType,
        into providersByID: inout [Int: WatchProvider]
    ) {
        for item in items ?? [] {
            var types = providersByID[item.providerID]?.monetizationTypes ?? []
            types.insert(type)
            providersByID[item.providerID] = WatchProvider(
                id: item.providerID,
                name: item.providerName,
                logoPath: item.logoPath,
                displayPriority: item.displayPriority,
                monetizationTypes: types
            )
        }
    }

    private func fetchPage(
        path: String,
        query: [String: String] = [:],
        page: Int
    ) async throws -> Page {

        let url = makeURL(
            path: path,
            query: query.merging(
                ["page": String(max(1, page))],
                uniquingKeysWith: { _, new in new }
            )
        )

        let (data, response) = try await session.data(from: url)
        try Self.validate(response)

        do {
            let decoded = try JSONDecoder()
                .decode(ListResponse.self, from: data)

            return Page(
                movies: decoded.results,
                currentPage: decoded.page ?? page,
                totalPages: max(decoded.totalPages ?? 1, 1)
            )
        } catch {
            throw NetworkError.decoding
        }
    }

    private func makeURL(
        path: String,
        query: [String: String]
    ) -> URL {
        let selectedLanguage = UserDefaults.standard.string(forKey: "settings.language") ?? "en"
        let localizedQuery = query.merging(
            ["language": AppLanguage.apiCode(for: selectedLanguage)],
            uniquingKeysWith: { current, _ in current }
        )
        let items =
            [URLQueryItem(name: "api_key", value: apiKey)] +
            localizedQuery
                .sorted { $0.key < $1.key }
                .map {
                    URLQueryItem(
                        name: $0.key,
                        value: $0.value
                    )
                }

        return baseURL
            .appendingPathComponent(path)
            .appending(queryItems: items)
    }

    private static func validate(
        _ response: URLResponse
    ) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw NetworkError.server(http.statusCode)
        }
    }
}
