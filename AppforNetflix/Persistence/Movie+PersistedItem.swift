extension Movie {
    init(watchlistItem item: WatchlistItem) {
        self.init(
            id: item.movieID,
            title: item.title,
            overview: "",
            posterPath: item.posterPath,
            backdropPath: nil,
            voteAverage: item.voteAverage,
            releaseDate: nil,
            genreIDs: [],
            runtimeMinutes: nil
        )
    }

    init(recentlyViewedItem item: RecentlyViewedItem) {
        self.init(
            id: item.movieID,
            title: item.title,
            overview: "",
            posterPath: item.posterPath,
            backdropPath: nil,
            voteAverage: item.voteAverage,
            releaseDate: nil,
            genreIDs: [],
            runtimeMinutes: nil
        )
    }
}
