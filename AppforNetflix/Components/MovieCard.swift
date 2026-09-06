import SwiftUI

// MARK: - Vertical Poster Card (2:3)
struct MovieCard: View {
    let movie: Movie
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
            .overlay {
                // inset(by:) laga diya taaki stroke bounding box ke bahar kabhi na jaye
                // (default center-stroke lineWidth ka aadha hissa bahar draw hota tha
                // jo ScrollView clipping / neighbouring card ke peeche cut ho jata tha)
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius)
                    .strokeBorder(isHovering ? Theme.accent : Color.clear, lineWidth: 2)
            }
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
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
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius)
                    .strokeBorder(isHovering ? Theme.accent : Color.clear, lineWidth: 2)
            }
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
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

            // ✅ Horizontal scroll yahan hai
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
                // 2pt se badha kar 6pt kiya — hover pe scaleEffect(1.02) se card
                // thoda bada hota hai aur border bhi thoda bahar draw hota hai,
                // pehle wali 2pt padding kaafi nahi thi to edge wale cards ka
                // red border ScrollView ke bounds se cut ho raha tha.
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            .frame(height: isLandscape ? 155 : 245)
        }
    }
}
