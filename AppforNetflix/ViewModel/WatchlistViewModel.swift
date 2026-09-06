//
//  WatchlistViewModel 2.swift
//  AppForNetflix
//
//  Created by Mac Mini on 28/08/2026.
//


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
        Movie(
            id: item.movieID, title: item.title, overview: "",
            posterPath: item.posterPath, backdropPath: nil,
            voteAverage: item.voteAverage, releaseDate: nil, genreIDs: [], runtimeMinutes: nil
        )
    }
}

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
        let descriptor = FetchDescriptor<WatchlistItem>(sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetch(movieID: Int) throws -> WatchlistItem? {
        var descriptor = FetchDescriptor<WatchlistItem>(predicate: #Predicate { $0.movieID == movieID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
