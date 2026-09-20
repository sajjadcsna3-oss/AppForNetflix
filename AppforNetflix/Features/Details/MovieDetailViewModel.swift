import Foundation
import Combine

@MainActor
final class MovieDetailViewModel: ObservableObject {
    @Published private(set) var platforms: [WatchProvider] = []
    @Published private(set) var cast: [CastMember] = []
    @Published private(set) var similarMovies: [Movie] = []
    @Published private(set) var isLoading = true
    @Published private(set) var providerErrorMessage: String?

    private let movieID: Int
    private let service: TMDBService

    init(movieID: Int, service: TMDBService = TMDBService()) {
        self.movieID = movieID
        self.service = service
    }

    func load(region: String) async {
        isLoading = true

        async let availabilityRequest = service.watchProviders(
            id: movieID, mediaType: .movie, region: region
        )
        async let creditsRequest = try? service.credits(movieId: movieID)
        async let similarRequest = try? service.similar(movieId: movieID)

        let availability: WatchProviderAvailability?
        do {
            availability = try await availabilityRequest
            providerErrorMessage = nil
        } catch {
            availability = nil
            providerErrorMessage = error.localizedDescription
        }
        let (credits, similar) = await (creditsRequest, similarRequest)
        guard !Task.isCancelled else { return }

        platforms = availability?.providers ?? []
        cast = credits ?? []
        similarMovies = similar ?? []
        isLoading = false
    }
}
