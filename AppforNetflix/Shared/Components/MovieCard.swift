import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Vertical Poster Card (2:3)
struct MovieCard: View {
    let movie: Movie
    // NEW (Guideline 4.2.2 – native macOS functionality): optional so every
    // existing call site (`MovieCard(movie: movie) { ... }`) keeps compiling
    // unchanged. Pass these two where a watchlist context is available to
    // get a live "Add/Remove from My List" row in the right-click menu.
    var isInWatchlist: Bool? = nil
    var onToggleWatchlist: (() -> Void)? = nil
    var onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: movie.posterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Theme.surfaceElevated
                            .overlay(
                                Image(systemName: "film")
                                    .foregroundStyle(Theme.textTertiary)
                            )
                    }
                }
                .frame(width: 150, height: 225)
                .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.9), .clear],
                    startPoint: .bottom,
                    endPoint: .center
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(Theme.Font.caption(13))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.warning)

                        Text(String(format: "%.1f", movie.voteAverage))
                            .font(Theme.Font.caption(10))
                            .foregroundStyle(.white.opacity(0.9))

                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))

                        Text(movie.year)
                            .font(Theme.Font.caption(10))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(10)
            }
            .frame(width: 150, height: 225)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius))
            .hoverCardStyle(isHovering: $isHovering)
        }
        .buttonStyle(.plain)
        // NEW: native right-click menu. Copy is always available; the
        // watchlist row only appears where a live toggle was supplied.
        .contextMenu {
            if let onToggleWatchlist {
                Button {
                    onToggleWatchlist()
                } label: {
                    Label(
                        isInWatchlist == true ? "Remove from My List" : "Add to My List",
                        systemImage: isInWatchlist == true ? "minus.circle" : "plus.circle"
                    )
                }
            }
            Button {
                copyToPasteboard(movie.title)
            } label: {
                Label("Copy Title", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Landscape Card (16:9) — Continue Watching
struct LandscapeMovieCard: View {
    let movie: Movie
    var onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: movie.backdropURL ?? movie.posterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Theme.surfaceElevated
                    }
                }
                .frame(width: 240, height: 135)
                .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.85), .clear],
                    startPoint: .bottom,
                    endPoint: .center
                )

                Text(movie.title)
                    .font(Theme.Font.caption(13))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(10)
            }
            .frame(width: 240, height: 135)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius))
            .hoverCardStyle(isHovering: $isHovering)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                copyToPasteboard(movie.title)
            } label: {
                Label("Copy Title", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Horizontal Row (Continue Watching / Trending)
struct MovieRow: View {
    @EnvironmentObject private var settings: SettingsStore
    let title: String
    let movies: [Movie]
    var isLandscape: Bool = false
    var onSelect: (Movie) -> Void
    var onSeeAll: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(Theme.Font.heading())
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if let onSeeAll {
                    Button(L10n.string("See All →", languageCode: settings.languageCode), action: onSeeAll)
                        .buttonStyle(.plain)
                        .font(Theme.Font.caption())
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(movies) { movie in
                        if isLandscape {
                            LandscapeMovieCard(movie: movie) {
                                onSelect(movie)
                            }
                        } else {
                            MovieCard(movie: movie) {
                                onSelect(movie)
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            .frame(height: isLandscape ? 155 : 245)
        }
    }
}

private func copyToPasteboard(_ string: String) {
    #if canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
    #endif
}
