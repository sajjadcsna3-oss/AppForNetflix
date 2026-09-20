import Foundation
import Combine

@MainActor
final class StreamingPlatformSelectorViewModel: ObservableObject {
    @Published private(set) var providers: [WatchProvider] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: TMDBService

    init(service: TMDBService = TMDBService()) {
        self.service = service
    }

    func load(region: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let regionalRequest = service.movieWatchProviders(region: region)
            async let globalRequest = service.movieWatchProviders()
            let (regional, global) = try await (regionalRequest, globalRequest)
            guard !Task.isCancelled else { return }

            providers = Platform.all.compactMap { definition in
                guard let provider = regional.first(where: {
                    definition.tmdbProviderIDs.contains($0.id)
                }) ?? global.first(where: {
                    definition.tmdbProviderIDs.contains($0.id)
                }) else { return nil }

                return WatchProvider(
                    id: provider.id,
                    name: definition.name,
                    logoPath: provider.logoPath,
                    displayPriority: provider.displayPriority,
                    monetizationTypes: provider.monetizationTypes
                )
            }
        } catch {
            guard !Task.isCancelled else { return }
            providers = []
            errorMessage = error.localizedDescription
        }
    }
}
