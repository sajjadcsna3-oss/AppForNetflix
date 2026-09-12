import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var storeKit: StoreKitService
    @Environment(\.openURL) private var openURL

    private let languages = AppLanguage.supportedCodes

    private let videoQualities = [
        "Auto (4K)",
        "4K",
        "1080p",
        "720p",
        "480p",
        "Data Saver"
    ]

    private let subtitleOptions = [
        "Off",
        "English",
        "Arabic",
        "Urdu",
        "French",
        "Spanish"
    ]

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 32
            ) {
                Text(L10n.string("Settings", languageCode: settings.languageCode))
                    .font(Theme.Font.title(28))
                    .padding(.bottom, -8)

                section("GENERAL") {
                    settingsRow(
                        title: "Appearance",
                        subtitle: appearanceSubtitle
                    ) {
                        SettingsDropdown(
                            items: AppColorScheme.allCases,
                            label: {
                                L10n.string($0.rawValue, languageCode: settings.languageCode)
                            },
                            selection: $settings.appearance
                        )
                    }

                    rowDivider

                    settingsRow(
                        title: "Language",
                        subtitle: L10n.string("Interface language", languageCode: settings.languageCode)
                    ) {
                        SettingsDropdown(
                            items: languages,
                            label: {
                                AppLanguage.displayName(for: $0)
                            },
                            selection: $settings.language
                        )
                    }

                    rowDivider

                    settingsRow(
                        title: "Region",
                        subtitle: L10n.string("Content availability region", languageCode: settings.languageCode)
                    ) {
                        SettingsDropdown(
                            items: Country.all.map(\.name),
                            label: { name in
                                "\(Country.find(name).flag) \(L10n.string(name, languageCode: settings.languageCode))"
                            },
                            selection: $settings.region
                        )
                    }
                }

                section("PLAYBACK") {
                    settingsRow(
                        title: "Video Quality",
                        subtitle: L10n.string("Preferred quality for playback handled by this app", languageCode: settings.languageCode)
                    ) {
                        premiumIndicator
                        SettingsDropdown(
                            items: videoQualities,
                            label: {
                                L10n.string($0, languageCode: settings.languageCode)
                            },
                            selection: videoQualityBinding
                        )
                    }

                    rowDivider

                    settingsRow(
                        title: "Autoplay",
                        subtitle: L10n.string("Play the next item automatically when supported in this app", languageCode: settings.languageCode)
                    ) {
                        CustomRedSwitch(isOn: $settings.autoplayNext)
                    }

                    rowDivider

                    settingsRow(
                        title: "Subtitles",
                        subtitle: L10n.string("Preferred subtitles for playback handled by this app", languageCode: settings.languageCode)
                    ) {
                        SettingsDropdown(
                            items: subtitleOptions,
                            label: {
                                L10n.string($0, languageCode: settings.languageCode)
                            },
                            selection: $settings.subtitles
                        )
                    }
                }

                section("STREAMING PLATFORMS") {
                    ForEach(
                        Array(
                            Platform.all.enumerated()
                        ),
                        id: \.element.id
                    ) { index, platform in
                        platformRow(platform)

                        if index < Platform.all.count - 1 {
                            rowDivider
                        }
                    }
                }

                section("ABOUT & CREDITS") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            AppIconView(
                                assetName: "TMDB Logo",
                                fallbackSymbol: "film",
                                renderingMode: .original
                            )
                            .frame(width: 56, height: 40)

                            Text(L10n.string("This product uses the TMDB API but is not endorsed or certified by TMDB.", languageCode: settings.languageCode))
                                .font(Theme.Font.caption(12))
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Text(L10n.string("Streaming-provider availability data is provided by JustWatch.", languageCode: settings.languageCode))
                            .font(Theme.Font.caption(12))
                            .foregroundStyle(Theme.textSecondary)

                        Button(L10n.string("Privacy Policy", languageCode: settings.languageCode)) {
                            if let url = AppConfiguration.privacyPolicyURL { openURL(url) }
                        }
                        .buttonStyle(.link)
                        .disabled(AppConfiguration.privacyPolicyURL == nil)
                    }
                    .padding(16)
                }

            }
            .padding(24)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }

    private var appearanceSubtitle: String {
        switch settings.appearance {
        case .dark:
            return L10n.string("Dark mode is always on", languageCode: settings.languageCode)

        case .light:
            return L10n.string("Light mode is always on", languageCode: settings.languageCode)

        case .system:
            return L10n.string("Follows system setting", languageCode: settings.languageCode)
        }
    }

    private var rowDivider: some View {
        Divider()
            .background(
                Theme.border
            )
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text(
                L10n.string(title, languageCode: settings.languageCode)
            )
            .font(
                .system(
                    size: 12,
                    weight: .bold
                )
            )
            .tracking(1.5)
            .foregroundStyle(
                Theme.textTertiary
            )
            .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(
                Theme.surface
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16
                )
                .stroke(
                    Theme.border,
                    lineWidth: 1
                )
            )
        }
    }

    private func settingsRow<Content: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder trailing: () -> Content
    ) -> some View {
        HStack {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(L10n.string(title, languageCode: settings.languageCode))
                .font(
                    Theme.Font.body(15)
                )
                .fontWeight(.medium)

                if let subtitle {
                    Text(subtitle)
                        .font(
                            Theme.Font.caption(13)
                        )
                        .foregroundStyle(
                            Theme.textSecondary
                        )
                }
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func platformRow(
        _ platform: Platform
    ) -> some View {
        HStack {
            platformIcon(platform)

            Text(platform.name)
                .font(
                    Theme.Font.body(15)
                )
                .fontWeight(.medium)
                .padding(.leading, 4)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            if settings.isConnected(platform) {
                settings.toggleConnection(for: platform)
            } else if settings.canConnect(platform, isPremium: isPremiumUser) {
                settings.toggleConnection(for: platform)
            } else {
                router.showSubscription(
                    then: .enablePlatforms([platform.tmdbProviderID ?? platform.id])
                )
            }
        }
    }

    private var isPremiumUser: Bool {
        storeKit.hasPremiumEntitlement
    }

    private var premiumIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
            Text("PRO")
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(Theme.textTertiary)
        .opacity(isPremiumUser ? 0 : 1)
    }

    private var videoQualityBinding: Binding<String> {
        Binding(
            get: { settings.videoQuality },
            set: { quality in
                let isPremiumQuality = quality == "Auto (4K)" || quality == "4K"
                if isPremiumQuality && !isPremiumUser {
                    router.showSubscription()
                } else {
                    settings.videoQuality = quality
                }
            }
        )
    }

    @ViewBuilder
    private func platformIcon(
        _ platform: Platform
    ) -> some View {
        // Use the same full logo assets as HomeView. Only the presentation
        // size is normalized here; the underlying artwork is unchanged.
        let iconAssetName = platform.id == Platform.max.id
            ? Platform.imax.logoAssetName
            : platform.logoAssetName

        AppIconView(
            assetName: iconAssetName,
            fallbackSymbol: "play.tv.fill",
            renderingMode: .original
        )
        .frame(width: 30, height: 30)
        .padding(3)
        .frame(width: 36, height: 36, alignment: .center)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8
            )
        )
    }

}

private struct SettingsDropdown<Item: Hashable>: View {
    let items: [Item]
    let label: (Item) -> String
    @Binding var selection: Item

    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 8) {
                Text(label(selection))
                    .font(
                        .system(
                            size: 13,
                            weight: .regular
                        )
                    )
                    .foregroundStyle(
                        Theme.textPrimary
                    )

                Image(
                    systemName:
                        "chevron.down"
                )
                .font(
                    .system(
                        size: 9,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    Theme.textSecondary
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(
                    cornerRadius: 6,
                    style: .continuous
                )
                .fill(
                    Theme.surfaceElevated
                )
            )
            .frame(height: 24)
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: $isOpen,
            arrowEdge: .bottom
        ) {
            ScrollView(
                showsIndicators: true
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    ForEach(
                        items,
                        id: \.self
                    ) { item in
                        Button {
                            selection = item
                            isOpen = false
                        } label: {
                            HStack(spacing: 12) {
                                Text(label(item))
                                    .font(
                                        Theme.Font.body(14)
                                    )
                                    .foregroundStyle(
                                        item == selection
                                            ? Theme.accent
                                            : Theme.textPrimary
                                    )

                                Spacer()

                                if item == selection {
                                    Image(
                                        systemName:
                                            "checkmark"
                                    )
                                    .font(
                                        .system(
                                            size: 12,
                                            weight: .medium
                                        )
                                    )
                                    .foregroundStyle(
                                        Theme.accent
                                    )
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            item == selection
                                ? Theme.surfaceElevated
                                : Color.clear
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 6
                            )
                        )
                    }
                }
                .padding(8)
            }
            .frame(
                width: 220,
                height: 260
            )
            .background(
                Theme.surface
            )
        }
    }
}

struct CustomRedSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(
                .spring(
                    response: 0.25,
                    dampingFraction: 0.75
                )
            ) {
                isOn.toggle()
            }
        } label: {
            ZStack(
                alignment:
                    isOn
                    ? .trailing
                    : .leading
            ) {
                Capsule()
                    .fill(
                        isOn
                            ? Color(hex: "E50914")
                            : Theme.border
                    )
                    .frame(
                        width: 38,
                        height: 22
                    )

                Circle()
                    .fill(.white)
                    .frame(
                        width: 18,
                        height: 18
                    )
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
    }
}
