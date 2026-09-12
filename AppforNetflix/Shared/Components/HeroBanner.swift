import SwiftUI

struct HeroBanner: View {
    @EnvironmentObject private var settings: SettingsStore
    let movie: Movie
    var onWatch: () -> Void
    var onToggleWatchlist: () -> Void
    var onInfo: () -> Void = {}
    var isSaved: Bool
    var isWatchlistLocked: Bool = false

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
            .frame(maxWidth: .infinity)
            .frame(height: 460)
            .clipped()

            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.85), Theme.background],
                startPoint: .top, endPoint: .bottom
            )

            if !movie.platforms.isEmpty {
                HStack(spacing: 8) {
                    ForEach(movie.platforms.prefix(4)) { platform in
                        compactProviderBadge(platform)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.trailing, 28)
                .padding(.bottom, 72)
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
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 620, alignment: .leading)

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
                        HStack(spacing: 6) {
                            Label(
                                L10n.string(isSaved ? "In My List" : "My List", languageCode: settings.languageCode),
                                systemImage: isWatchlistLocked ? "lock.fill" : (isSaved ? "checkmark" : "plus")
                            )
                            if isWatchlistLocked {
                                Text("PRO")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 460)
    }

    private func compactProviderBadge(_ platform: WatchProvider) -> some View {
        HStack(spacing: 6) {
            AsyncImage(url: platform.logoURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    Color.clear
                }
            }
            .frame(width: 35, height: 35)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
    }
}
