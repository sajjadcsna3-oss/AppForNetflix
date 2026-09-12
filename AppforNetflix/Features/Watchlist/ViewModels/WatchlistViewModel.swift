import Foundation
import SwiftData
import Combine

@MainActor
final class WatchlistViewModel: ObservableObject {
    @Published private(set) var items: [WatchlistItem] = []

    private var store: WatchlistStore?

    func configure(context: ModelContext) {
        guard store == nil else { return }
        store = WatchlistStore(context: context)
        refresh()
    }

    func refresh() {
        items = store?.all() ?? []
    }

    func isSaved(_ movie: Movie) -> Bool {
        store?.isSaved(movie) ?? false
    }

    func toggle(_ movie: Movie) {
        store?.toggle(movie)
        refresh()
    }

    func asMovie(_ item: WatchlistItem) -> Movie {
        Movie(watchlistItem: item)
    }
}
