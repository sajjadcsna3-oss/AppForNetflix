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
        Movie(recentlyViewedItem: item)
    }
}
