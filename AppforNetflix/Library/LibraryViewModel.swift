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
    @Published private(set) var collections: [LibraryCollection] = []
    @Published var persistenceErrorMessage: String?

    private var store: LibraryStore?

    func configure(context: ModelContext) {
        guard store == nil else { return }
        store = LibraryStore(context: context) { [weak self] message in
            self?.persistenceErrorMessage = message
        }
        refresh()
    }

    func refresh() {
        items = store?.all() ?? []
        collections = store?.collections() ?? []
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

    func remove(_ movie: Movie) { store?.remove(movie); refresh() }
    func item(for movie: Movie) -> LibraryItem? { items.first { $0.movieID == movie.id } }
    func setPersonalRating(_ rating: Int?, for movie: Movie) { store?.setPersonalRating(rating, for: movie); refresh() }
    func setNotes(_ notes: String, for movie: Movie) { store?.setNotes(notes, for: movie); refresh() }
    func setProgress(_ progress: Double, for movie: Movie) { store?.setProgress(progress, for: movie); refresh() }
    func createCollection(named name: String) { store?.createCollection(named: name); refresh() }
    func rename(_ collection: LibraryCollection, to name: String) { store?.rename(collection, to: name); refresh() }
    func delete(_ collection: LibraryCollection) { store?.delete(collection); refresh() }
    func setMovie(_ movie: Movie, in collection: LibraryCollection, included: Bool) {
        store?.setMovie(movie, in: collection, included: included); refresh()
    }

    func isInMyList(_ movie: Movie) -> Bool { status(for: movie) == .wantToWatch }
    func toggleMyList(_ movie: Movie) { setStatus(isInMyList(movie) ? .none : .wantToWatch, for: movie) }

    var continueWatching: [LibraryItem] {
        items.filter { $0.status == .watching && $0.watchProgress < 1 }
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
