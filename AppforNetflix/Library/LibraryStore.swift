import Foundation
import SwiftData

@MainActor
final class LibraryStore {
    private let context: ModelContext
    private let reportError: (String) -> Void

    init(context: ModelContext, reportError: @escaping (String) -> Void = { _ in }) {
        self.context = context
        self.reportError = reportError
        migrateLegacyWatchlist()
    }

    func all() -> [LibraryItem] {
        let descriptor = FetchDescriptor<LibraryItem>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        do { return try context.fetch(descriptor) }
        catch { reportError("Unable to load your library: \(error.localizedDescription)"); return [] }
    }

    func item(for movieID: Int) -> LibraryItem? {
        var descriptor = FetchDescriptor<LibraryItem>(
            predicate: #Predicate { $0.movieID == movieID }
        )
        descriptor.fetchLimit = 1
        do { return try context.fetch(descriptor).first }
        catch { reportError("Unable to read this library item: \(error.localizedDescription)"); return nil }
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
        switch status {
        case .none, .wantToWatch:
            item.watchProgress = 0
        case .watching:
            if item.watchProgress >= 1 { item.watchProgress = 0 }
        case .watched:
            item.watchProgress = 1
        }
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

    func remove(_ movie: Movie) {
        guard let item = item(for: movie.id) else { return }
        context.delete(item)
        collections().forEach { collection in
            collection.movieIDs.removeAll { $0 == movie.id }
        }
        save()
    }

    func setPersonalRating(_ rating: Int?, for movie: Movie) {
        let item = existingOrCreate(movie)
        item.personalRating = rating.map { min(10, max(1, $0)) }
        item.updatedAt = .now
        cleanUpIfEmpty(item)
        save()
    }

    func setNotes(_ notes: String, for movie: Movie) {
        let item = existingOrCreate(movie)
        item.personalNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        item.updatedAt = .now
        cleanUpIfEmpty(item)
        save()
    }

    func setProgress(_ progress: Double, for movie: Movie) {
        let item = existingOrCreate(movie)
        item.watchProgress = min(1, max(0, progress))
        if item.watchProgress > 0, item.status == .none { item.status = .watching }
        if item.watchProgress >= 1 { item.status = .watched }
        item.updatedAt = .now
        cleanUpIfEmpty(item)
        save()
    }

    func collections() -> [LibraryCollection] {
        let descriptor = FetchDescriptor<LibraryCollection>(
            sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
        )
        do { return try context.fetch(descriptor) }
        catch { reportError("Unable to load collections: \(error.localizedDescription)"); return [] }
    }

    func createCollection(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              !collections().contains(where: { $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) else { return }
        context.insert(LibraryCollection(name: name))
        save()
    }

    func rename(_ collection: LibraryCollection, to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              !collections().contains(where: { $0.id != collection.id && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) else { return }
        collection.name = name
        collection.updatedAt = .now
        save()
    }

    func delete(_ collection: LibraryCollection) {
        context.delete(collection)
        save()
    }

    func setMovie(_ movie: Movie, in collection: LibraryCollection, included: Bool) {
        _ = existingOrCreate(movie)
        if included {
            if !collection.movieIDs.contains(movie.id) { collection.movieIDs.append(movie.id) }
        } else {
            collection.movieIDs.removeAll { $0 == movie.id }
            if let item = item(for: movie.id) { cleanUpIfEmpty(item) }
        }
        collection.updatedAt = .now
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
        let isInCollection = collections().contains { $0.movieIDs.contains(item.movieID) }
        if item.status == .none && !item.isFavorite && item.personalRating == nil
            && item.personalNotes.isEmpty && item.watchProgress == 0 && !isInCollection {
            context.delete(item)
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            context.rollback()
            reportError("Your library change could not be saved. Please try again. \(error.localizedDescription)")
        }
    }

    private func migrateLegacyWatchlist() {
        let legacy: [WatchlistItem]
        do { legacy = try context.fetch(FetchDescriptor<WatchlistItem>()) }
        catch { reportError("Unable to migrate the previous watchlist: \(error.localizedDescription)"); return }
        guard !legacy.isEmpty else { return }
        for oldItem in legacy {
            if item(for: oldItem.movieID) == nil {
                context.insert(LibraryItem(movie: Movie(watchlistItem: oldItem), status: .wantToWatch))
            } else if let item = item(for: oldItem.movieID), item.status == .none {
                item.status = .wantToWatch
            }
            context.delete(oldItem)
        }
        save()
    }
}
