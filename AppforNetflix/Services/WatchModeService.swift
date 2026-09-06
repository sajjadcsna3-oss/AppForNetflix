import Foundation

/// Watchmode API — "where can I watch this specific movie" (used only in
/// the Detail screen and the Home hero banner; Home/list-level platform
/// FILTERING still goes through TMDB's own `discover` +
/// `with_watch_providers`, see TMDBService).
///
/// FIX (availability showing empty for most titles): the old
/// `mapToPlatforms` only accepted Watchmode source `type == "sub"` or
/// `"free"`. Watchmode actually returns `"sub"`, `"free"`, `"tve"`
/// (TV-Everywhere / login-required), `"rent"`, and `"buy"`. Plenty of
/// titles — especially older ones — are ONLY available to rent/buy, so
/// they were being filtered down to an empty array and the UI showed
/// "No streaming info for this region" even though Watchmode genuinely had
/// data. Now every source type is considered, and results are ranked so
/// subscription/free options are still shown first when both exist.
///
/// FIX (silent failures): every failure path used to just `return []`,
/// which is indistinguishable from "Watchmode has no data for this title".
/// That made this impossible to debug. Failures are now logged to the
/// console (visible in Xcode's debug area) so you can tell whether it's a
/// bad API key, a network error, a decode error, or genuinely no data.
actor WatchmodeService {
    static let shared = WatchmodeService()

    private let apiKey: String
    private let baseURL = URL(string: "https://api.watchmode.com/v1")!
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.apiKey = Secrets.watchmodeAPIKey
        self.session = session
    }

    // MARK: - Public

    func platforms(forTMDBId tmdbId: Int, regionCode: String = "US") async -> [Platform] {
        do {
            guard let watchmodeId = try await watchmodeTitleId(tmdbMovieId: tmdbId) else {
                log("No Watchmode title found for TMDB id \(tmdbId).")
                return []
            }
            let sources = try await sources(titleId: watchmodeId, region: regionCode)
            if sources.isEmpty {
                log("Watchmode returned zero sources for title \(watchmodeId) (TMDB \(tmdbId)), region \(regionCode).")
            }
            return Self.mapToPlatforms(sources, region: regionCode)
        } catch {
            log("Watchmode lookup failed for TMDB id \(tmdbId): \(error)")
            return []
        }
    }

    // MARK: - Private API

    private struct SearchResponse: Decodable {
        let titleResults: [TitleHit]?
        enum CodingKeys: String, CodingKey {
            case titleResults = "title_results"
        }
    }

    private struct TitleHit: Decodable {
        let id: Int
    }

    private struct Source: Decodable {
        let sourceId: Int?
        let name: String
        let type: String?
        let region: String?
        let webUrl: String?
        enum CodingKeys: String, CodingKey {
            case sourceId = "source_id"
            case name, type, region
            case webUrl = "web_url"
        }
    }

    private func watchmodeTitleId(tmdbMovieId: Int) async throws -> Int? {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("search/"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [
            .init(name: "apiKey", value: apiKey),
            .init(name: "search_field", value: "tmdb_movie_id"),
            .init(name: "search_value", value: "\(tmdbMovieId)")
        ]
        guard let url = comps.url else { return nil }
        let (data, response) = try await session.data(from: url)
        try Self.validate(response, context: "search", body: data)
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return decoded.titleResults?.first?.id
    }

    private func sources(titleId: Int, region: String) async throws -> [Source] {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("title/\(titleId)/sources/"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [
            .init(name: "apiKey", value: apiKey),
            .init(name: "regions", value: region)
        ]
        guard let url = comps.url else { return [] }
        let (data, response) = try await session.data(from: url)
        try Self.validate(response, context: "sources", body: data)
        return try JSONDecoder().decode([Source].self, from: data)
    }

    private static func validate(_ response: URLResponse, context: String, body: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            // Surface the response body in the log — Watchmode returns a
            // JSON error message (e.g. bad/expired API key, rate limit)
            // that's otherwise invisible.
            let bodyText = String(data: body, encoding: .utf8) ?? "<no body>"
            print("[Watchmode] \(context) failed with status \(http.statusCode): \(bodyText)")
            throw NetworkError.server(http.statusCode)
        }
    }

    /// FIX: was `t == "sub" || t == "free" || t.isEmpty` — dropped every
    /// rent/buy-only title. Now accepts every known Watchmode type, and
    /// sorts so subscription/free sources surface first (better UX) while
    /// still keeping rent/buy so something shows instead of nothing.
    /// Also filters defensively by `region` client-side, in case the
    /// `regions` query param isn't honored for a given source.
    private static func mapToPlatforms(_ sources: [Source], region: String) -> [Platform] {
        let regional = sources.filter { src in
            guard let srcRegion = src.region, !srcRegion.isEmpty else { return true }
            return srcRegion.caseInsensitiveCompare(region) == .orderedSame
        }
        // If filtering by region wiped everything out (API/region mismatch),
        // fall back to the unfiltered list rather than showing nothing.
        let candidates = regional.isEmpty ? sources : regional

        let typeRank: [String: Int] = ["sub": 0, "free": 1, "tve": 2, "rent": 3, "buy": 4]
        let sorted = candidates.sorted {
            let a = typeRank[($0.type ?? "").lowercased()] ?? 5
            let b = typeRank[($1.type ?? "").lowercased()] ?? 5
            return a < b
        }

        var seen = Set<Int>()
        var result: [Platform] = []
        for src in sorted {
            guard let platform = matchPlatform(named: src.name) else { continue }
            if seen.insert(platform.id).inserted {
                result.append(platform)
            }
        }
        return result
    }

    private static func matchPlatform(named raw: String) -> Platform? {
        let name = raw.lowercased()
        if name.contains("netflix") { return .netflix }
        if name.contains("prime") || name.contains("amazon") { return .primeVideo }
        if name.contains("disney") { return .disneyPlus }
        if name.contains("apple") { return .appleTVPlus }
        if name.contains("hulu") { return .hulu }
        if name.contains("max") || name.contains("hbo") { return .max }
        if name.contains("peacock") { return .peacock }
        return nil
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[Watchmode] \(message)")
        #endif
    }
}
