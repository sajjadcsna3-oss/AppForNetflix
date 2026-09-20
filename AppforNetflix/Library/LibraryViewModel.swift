//
//  LibraryViewModel.swift
//  AppforNetflix
//
//  Created by Mac Mini on 16/09/2026.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var items: [LibraryItem] = []

    private var store: LibraryStore?

    func configure(context: ModelContext) {
        guard store == nil else { return }
        store = LibraryStore(context: context)
        refresh()
    }

    func refresh() {
        items = store?.all() ?? []
    }

    func status(for movie: Movie) -> LibraryStatus {
        store?.status(for: movie) ?? .none
    }

    func isFavorite(_ movie: Movie) -> Bool {
        store?.isFavorite(movie) ?? false
    }

    func setStatus(_ status: LibraryStatus, for movie: Movie) {
        store?.setStatus(status, for: movie)
        refresh()
    }

    func toggleFavorite(_ movie: Movie) {
        store?.toggleFavorite(movie)
        refresh()
    }

    func items(with status: LibraryStatus) -> [LibraryItem] {
        items.filter { $0.status == status }
    }

    var favorites: [LibraryItem] {
        items.filter(\.isFavorite)
    }

    func asMovie(_ item: LibraryItem) -> Movie {
        Movie(libraryItem: item)
    }
}
