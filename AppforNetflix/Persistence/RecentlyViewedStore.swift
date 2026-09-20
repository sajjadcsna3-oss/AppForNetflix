import Foundation
import SwiftData

@MainActor
final class RecentlyViewedStore {
    private let context: ModelContext
    private let maximumItemCount: Int

    init(context: ModelContext, maximumItemCount: Int = 30) {
        self.context = context
        self.maximumItemCount = maximumItemCount
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

        save()
        trimIfNeeded()
    }

    func all() -> [RecentlyViewedItem] {
        let descriptor = FetchDescriptor<RecentlyViewedItem>(
            sortBy: [SortDescriptor(\.viewedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func clear() {
        all().forEach(context.delete)
        save()
    }

    private func trimIfNeeded() {
        let items = all()
        guard items.count > maximumItemCount else { return }
        items.dropFirst(maximumItemCount).forEach(context.delete)
        save()
    }

    private func save() {
        try? context.save()
    }
}
