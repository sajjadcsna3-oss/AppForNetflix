import Foundation
import SwiftData

@MainActor
final class WatchlistStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func isSaved(_ movie: Movie) -> Bool {
        (try? fetch(movieID: movie.id)) != nil
    }

    func toggle(_ movie: Movie) {
        if let existing = try? fetch(movieID: movie.id) {
            context.delete(existing)
        } else {
            context.insert(WatchlistItem(movie: movie))
        }
        try? context.save()
    }

    func all() -> [WatchlistItem] {
        let descriptor = FetchDescriptor<WatchlistItem>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetch(movieID: Int) throws -> WatchlistItem? {
        var descriptor = FetchDescriptor<WatchlistItem>(
            predicate: #Predicate { $0.movieID == movieID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
