import Foundation

enum StreamingProviderLinkBuilder {
    /// Returns only known official provider search destinations. These are
    /// search URLs because TMDB does not expose provider-specific title IDs.
    static func searchURL(for provider: WatchProvider, title: String) -> URL? {
        let name = provider.name.lowercased()

        switch Platform.definition(matching: provider)?.id {
        case Platform.netflix.id:
            return queryURL("https://www.netflix.com/search", key: "q", title: title)
        case Platform.primeVideo.id:
            return queryURL("https://www.primevideo.com/search/ref=atv_nb_sr", key: "phrase", title: title)
        case Platform.disneyPlus.id:
            return queryURL("https://www.disneyplus.com/search", key: "q", title: title)
        case Platform.appleTVPlus.id:
            return queryURL("https://tv.apple.com/search", key: "term", title: title)
        case Platform.max.id:
            return queryURL("https://play.max.com/search", key: "q", title: title)
        case Platform.hulu.id:
            return queryURL("https://www.hulu.com/search", key: "q", title: title)
        case Platform.paramountPlus.id:
            return queryURL("https://www.paramountplus.com/search/", key: "query", title: title)
        case Platform.peacock.id:
            return queryURL("https://www.peacocktv.com/search", key: "q", title: title)
        case Platform.hbo.id:
            return queryURL("https://www.hbo.com/search", key: "q", title: title)
        default:
            break
        }

        switch provider.id {
        case 73:
            return pathURL("https://tubitv.com/search", title: title)
        case 122, 2336:
            return queryURL("https://www.hotstar.com/in/search", key: "q", title: title)
        case 538:
            return queryURL("https://watch.plex.tv/search", key: "q", title: title)
        default:
            return searchURLMatchedByName(name, title: title)
        }
    }

    private static func searchURLMatchedByName(_ name: String, title: String) -> URL? {
        if name.contains("netflix") {
            return queryURL("https://www.netflix.com/search", key: "q", title: title)
        }
        if name.contains("prime video") || name.contains("amazon") {
            return queryURL("https://www.primevideo.com/search/ref=atv_nb_sr", key: "phrase", title: title)
        }
        if name.contains("disney") {
            return queryURL("https://www.disneyplus.com/search", key: "q", title: title)
        }
        if name.contains("apple tv") {
            return queryURL("https://tv.apple.com/search", key: "term", title: title)
        }
        if name == "max" || name.contains("hbo max") {
            return queryURL("https://play.max.com/search", key: "q", title: title)
        }
        if name.contains("hulu") {
            return queryURL("https://www.hulu.com/search", key: "q", title: title)
        }
        if name.contains("paramount") {
            return queryURL("https://www.paramountplus.com/search/", key: "query", title: title)
        }
        if name.contains("peacock") {
            return queryURL("https://www.peacocktv.com/search", key: "q", title: title)
        }
        if name.contains("tubi") {
            return pathURL("https://tubitv.com/search", title: title)
        }
        if name.contains("hotstar") {
            return queryURL("https://www.hotstar.com/in/search", key: "q", title: title)
        }
        if name.contains("plex") {
            return queryURL("https://watch.plex.tv/search", key: "q", title: title)
        }
        return nil
    }

    private static func queryURL(_ base: String, key: String, title: String) -> URL? {
        guard var components = URLComponents(string: base) else { return nil }
        components.queryItems = [URLQueryItem(name: key, value: title)]
        return validatedHTTPSURL(components.url)
    }

    private static func pathURL(_ base: String, title: String) -> URL? {
        guard let baseURL = URL(string: base) else { return nil }
        return validatedHTTPSURL(baseURL.appendingPathComponent(title))
    }

    private static func validatedHTTPSURL(_ url: URL?) -> URL? {
        guard let url,
              url.scheme?.lowercased() == "https",
              url.host != nil else { return nil }
        return url
    }
}
