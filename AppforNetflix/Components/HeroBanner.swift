import SwiftUI

struct HeroBanner: View {
    @EnvironmentObject private var settings: SettingsStore
    let movie: Movie
    var onWatch: () -> Void
    var onToggleWatchlist: () -> Void
    var onInfo: () -> Void = {}
    var isSaved: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: movie.backdropURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    LinearGradient(colors: [Theme.surfaceElevated, Theme.background],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
            .frame(height: 460)
            .clipped()

            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.85), Theme.background],
                startPoint: .top, endPoint: .bottom
            )

            if !movie.platforms.isEmpty {
                HStack(spacing: 12) {
                    ForEach(movie.platforms) { platform in
                        HeroPlatformBadge(platform: platform)
                    }
                }
                .padding(.trailing, 40)
                .padding(.bottom, 64)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text(L10n.string("NEW RELEASE", languageCode: settings.languageCode))
                        .font(Theme.Font.caption(11))
                        .fontWeight(.bold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Label(String(format: "%.1f", movie.voteAverage), systemImage: "star.fill")
                        .foregroundStyle(Theme.warning)
                    Text(movie.year)
                    Text(movie.runtimeLabel)
                }
                .font(Theme.Font.caption())
                .foregroundStyle(Theme.textSecondary)

                Text(movie.title)
                    .font(Theme.Font.title(40))
                    .foregroundStyle(.white)

                Text(movie.overview)
                    .font(Theme.Font.body())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(3)
                    .frame(maxWidth: 560, alignment: .leading)

                HStack(spacing: 12) {
                    Button(action: onWatch) {
                        Label(L10n.string("Watch Now", languageCode: settings.languageCode), systemImage: "play.fill")
                            .font(Theme.Font.body(14)).fontWeight(.semibold)
                            .padding(.horizontal, 20).padding(.vertical, 11)
                            .background(Theme.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button(action: onToggleWatchlist) {
                        Label(
                            L10n.string(isSaved ? "In My List" : "My List", languageCode: settings.languageCode),
                            systemImage: isSaved ? "checkmark" : "plus"
                        )
                            .font(Theme.Font.body(14)).fontWeight(.semibold)
                            .padding(.horizontal, 20).padding(.vertical, 11)
                            .background(Theme.surfaceElevated)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button(action: onInfo) {
                        AppIconView(assetName: "Infologo", fallbackSymbol: "info")
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .frame(width: 42, height: 42)
                            .background(Theme.surfaceElevated)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28)
        }
        .frame(height: 460)
    }
}
