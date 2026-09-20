import Foundation
import SwiftData

@MainActor
final class LibraryStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func all() -> [LibraryItem] {
        let descriptor = FetchDescriptor<LibraryItem>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func item(for movieID: Int) -> LibraryItem? {
        var descriptor = FetchDescriptor<LibraryItem>(
            predicate: #Predicate { $0.movieID == movieID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func status(for movie: Movie) -> LibraryStatus {
        item(for: movie.id)?.status ?? .none
    }

    func isFavorite(_ movie: Movie) -> Bool {
        item(for: movie.id)?.isFavorite ?? false
    }

    func setStatus(_ status: LibraryStatus, for movie: Movie) {
        let item = existingOrCreate(movie)
        item.status = status
        item.updatedAt = .now
        cleanUpIfEmpty(item)
        save()
    }

    func toggleFavorite(_ movie: Movie) {
        let item = existingOrCreate(movie)
        item.isFavorite.toggle()
        item.updatedAt = .now
        cleanUpIfEmpty(item)
        save()
    }

    private func existingOrCreate(_ movie: Movie) -> LibraryItem {
        if let existing = item(for: movie.id) {
            existing.title = movie.title
            existing.posterPath = movie.posterPath
            existing.voteAverage = movie.voteAverage
            return existing
        }

        let item = LibraryItem(movie: movie)
        context.insert(item)
        return item
    }

    private func cleanUpIfEmpty(_ item: LibraryItem) {
        if item.status == .none && !item.isFavorite {
            context.delete(item)
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("Library save failed: \(error)")
        }
    }
}
