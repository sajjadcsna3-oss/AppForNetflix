import SwiftUI

struct SidebarView: View {

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var storeKit: StoreKitService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(SidebarSection.allCases) { section in
                        sidebarRow(section)
                    }
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("GENRES", languageCode: settings.languageCode))
                        .font(Theme.Font.caption(10))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 6)

                    ForEach(Genre.all) { genre in
                        genreRow(genre)
                    }
                }
            }

            if !settings.isPremium {
                premiumCard
                    .padding(12)
            }
        }
        .frame(width: Theme.Metrics.sidebarWidth)
        .background(Theme.surface)
    }

    private func sidebarRow(_ section: SidebarSection) -> some View {
        let isSelected = router.selectedSection == section && router.selectedGenre == nil
        let isPremiumSection = section == .watchlist || section == .recent
        let isLocked = storeKit.isConfigured && !settings.isPremium && isPremiumSection
        return Button {
            if isLocked {
                router.showSubscription(then: .section(section))
            } else {
                router.select(section)
            }
        } label: {
            HStack(spacing: 10) {
                AppIconView(assetName: section.assetName, fallbackSymbol: section.fallbackSymbol)
                    .frame(width: 16, height: 16)
                Text(L10n.string(section.rawValue, languageCode: settings.languageCode))
                    .font(Theme.Font.body())
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(isSelected ? Theme.accent : .clear)
            .foregroundStyle(isSelected ? .white : Theme.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
    }

    private func genreRow(_ genre: Genre) -> some View {
        let isSelected = router.selectedGenre == genre
        return Button { router.select(genre: genre) } label: {
            HStack(spacing: 10) {
                AppIconView(assetName: genre.assetName, fallbackSymbol: genre.fallbackSymbol)
                    .frame(width: 15, height: 15)
                Text(L10n.string(genre.name, languageCode: settings.languageCode))
                    .font(Theme.Font.body(13))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
            .background(isSelected ? Theme.surfaceElevated : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
    }

    private var premiumCard: some View {
        VStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)

            Text(L10n.string("Discover across every\nplatform", languageCode: settings.languageCode))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Spacer(minLength: 2)

            Button {
                router.showSubscription()
            } label: {
                Text(L10n.string("Get Premium", languageCode: settings.languageCode))
                    .font(.system(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(height: 130)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "E50914").opacity(0.15),
                    Color(hex: "E50914").opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "E50914").opacity(0.3), lineWidth: 1)
        )
    }
}
