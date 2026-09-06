import Foundation
import SwiftData
import Combine

@MainActor
final class RecentViewModel: ObservableObject {
    @Published private(set) var items: [RecentlyViewedItem] = []

    private var store: RecentlyViewedStore?

    func configure(context: ModelContext) {
        guard store == nil else { return }
        store = RecentlyViewedStore(context: context)
        refresh()
    }

    func refresh() {
        items = store?.all() ?? []
    }

    func record(_ movie: Movie) {
        store?.record(movie)
        refresh()
    }

    func clear() {
        store?.clear()
        refresh()
    }

    func asMovie(_ item: RecentlyViewedItem) -> Movie {
        Movie(
            id: item.movieID, title: item.title, overview: "",
            posterPath: item.posterPath, backdropPath: nil,
            voteAverage: item.voteAverage, releaseDate: nil, genreIDs: [], runtimeMinutes: nil
        )
    }
}

@MainActor
final class RecentlyViewedStore {
    private let context: ModelContext
    private let limit = 30

    init(context: ModelContext) {
        self.context = context
    }

    func record(_ movie: Movie) {
        var descriptor = FetchDescriptor<RecentlyViewedItem>(
            predicate: #Predicate { $0.movieID == movie.id }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            existing.viewedAt = .now
        } else {
            context.insert(RecentlyViewedItem(movie: movie))
        }
        try? context.save()
        trimIfNeeded()
    }

    func all() -> [RecentlyViewedItem] {
        let descriptor = FetchDescriptor<RecentlyViewedItem>(sortBy: [SortDescriptor(\.viewedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func clear() {
        all().forEach { context.delete($0) }
        try? context.save()
    }

    private func trimIfNeeded() {
        let items = all()
        guard items.count > limit else { return }
        for item in items.suffix(from: limit) {
            context.delete(item)
        }
        try? context.save()
    }
}
