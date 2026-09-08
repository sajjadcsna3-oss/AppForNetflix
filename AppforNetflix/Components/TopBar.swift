import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct TopBar: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var storeKit: StoreKitService
    @Binding var searchText: String
    @ObservedObject var viewModel: HomeViewModel

    private let ratingOptions: [Double] = [0, 7.0, 7.5, 8.0, 8.5, 9.0]
    private let yearOptions = ["All Years"] + (2002...2026).reversed().map(String.init)

    @State private var openDropdown: DropdownID?
    @FocusState private var isSearchFocused: Bool

    private enum DropdownID {
        case rating, year, country
    }

    var body: some View {
        HStack(spacing: 16) {

            // MARK: - Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textTertiary)

                TextField(
                    L10n.string("Search…", languageCode: settings.languageCode),
                    text: $searchText
                )
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
                .focused($isSearchFocused)
                .allowsHitTesting(isPremiumUser)

                if !isPremiumUser {
                    Button {
                        router.showSubscription()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                            Text("PRO")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                Text("⌘K")
                    .font(Theme.Font.caption(11))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .frame(maxWidth: 340)
            .background {
                Button("") {
                    if isPremiumUser {
                        isSearchFocused = true
                    } else {
                        router.showSubscription()
                    }
                }
                    .keyboardShortcut("k", modifiers: .command)
                    .frame(width: 0, height: 0)
                    .opacity(0)
            }

            Spacer()

            // MARK: - Streaming Platforms
            // Same selection/state as the existing top bar.
            // Only the visual presentation has been changed.
            OverlappingPlatformsView(
                selectedPlatform: settings.selectedPlatform
            )

            HStack(spacing: 12) {
                ratingDropdown
                    .zIndex(3)

                yearDropdown
                    .zIndex(2)

                countryDropdown
                    .zIndex(1)
            }
        }
    }

    // MARK: - Rating Dropdown

    private var ratingDropdown: some View {
        let currentLabel = viewModel.ratingFilter == 0
            ? L10n.string("All Ratings", languageCode: settings.languageCode)
            : "≥ \(String(format: "%.1f", viewModel.ratingFilter))"

        return FilterDropdown(
            label: currentLabel,
            buttonIcon: AnyView(
                Image("StarIcon")
                    .foregroundStyle(Theme.warning)
            ),
            panelWidth: 170,
            panelHeight: 220,
            isOpen: Binding(
                get: { openDropdown == .rating },
                set: { openDropdown = $0 ? .rating : nil }
            )
        ) { dismiss in

            ForEach(ratingOptions, id: \.self) { value in

                let title = value == 0
                    ? L10n.string("All Ratings", languageCode: settings.languageCode)
                    : "≥ \(String(format: "%.1f", value))"

                let isSelected = viewModel.ratingFilter == value

                FilterDropdownRow(
                    title: title,
                    isSelected: isSelected,
                    leadingIcon: AnyView(
                        Image("StarIcon")
                            .foregroundStyle(Theme.warning)
                    )
                ) {
                    viewModel.ratingFilter = value
                    dismiss()
                }
            }
        }
    }

    // MARK: - Year Dropdown

    private var yearDropdown: some View {
        FilterDropdown(
            label: viewModel.yearFilter == "All Years"
                ? L10n.string("All Years", languageCode: settings.languageCode)
                : viewModel.yearFilter,
            buttonIcon: AnyView(
                Image("YearIcon")
                    .foregroundStyle(.white.opacity(0.7))
            ),
            panelWidth: 133,
            panelHeight: 185.2,
            isOpen: Binding(
                get: { openDropdown == .year },
                set: { openDropdown = $0 ? .year : nil }
            )
        ) { dismiss in

            ForEach(yearOptions, id: \.self) { year in

                let title = year == "All Years"
                    ? L10n.string("All Years", languageCode: settings.languageCode)
                    : year

                let isSelected = viewModel.yearFilter == year

                FilterDropdownRow(
                    title: title,
                    isSelected: isSelected
                ) {
                    viewModel.yearFilter = year
                    dismiss()
                }
            }
        }
    }

    // MARK: - Country Dropdown

    private var countryDropdown: some View {
        FilterDropdown(
            label: L10n.string(settings.region, languageCode: settings.languageCode),
            buttonIcon: AnyView(
                HStack(spacing: 4) {
                    Text(Country.find(settings.region).flag)
                    if !isPremiumUser {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                    }
                }
            ),
            panelWidth: 194.85,
            panelHeight: 185.2,
            panelAlignment: .topTrailing,
            isOpen: Binding(
                get: { openDropdown == .country },
                set: { wantsToOpen in
                    if wantsToOpen && !isPremiumUser {
                        router.showSubscription()
                    } else {
                        openDropdown = wantsToOpen ? .country : nil
                    }
                }
            )
        ) { dismiss in

            ForEach(Country.all) { country in

                let isSelected = settings.region == country.name

                FilterDropdownRow(
                    title: L10n.string(country.name, languageCode: settings.languageCode),
                    isSelected: isSelected,
                    leadingIcon: AnyView(
                        Text(country.flag)
                    )
                ) {
                    settings.region = country.name
                    dismiss()
                }
            }
        }
    }

    private var isPremiumUser: Bool {
        storeKit.entitlementState == .loading
            ? settings.isPremium
            : storeKit.hasPremiumEntitlement
    }
}

// MARK: - Platforms

struct OverlappingPlatformsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var storeKit: StoreKitService
    let selectedPlatform: Platform?
    var platforms: [Platform] = Platform.filterBar

    // Same circular style as the reference UI.
    private let badgeSize: CGFloat = 34
    private let overlap: CGFloat = 11

    private var displayedPlatforms: [Platform] {
        if let selectedPlatform {
            return [selectedPlatform]
        }

        let effectiveIDs = settings.effectiveConnectedPlatformIDs(isPremium: isPremiumUser)
        let connected = platforms.filter { effectiveIDs.contains($0.id) }
        return connected.isEmpty ? platforms : connected
    }

    private var isPremiumUser: Bool {
        storeKit.entitlementState == .loading
            ? settings.isPremium
            : storeKit.hasPremiumEntitlement
    }

    var body: some View {
        // Negative spacing creates the exact stacked/overlapping sequence:
        // 1st circle behind 2nd, 2nd behind 3rd, etc.
        HStack(spacing: -overlap) {
            ForEach(Array(displayedPlatforms.enumerated()), id: \.element.id) { index, platform in
                Button {
                    // TopBar icon remains a quick Home platform filter.
                    // Clicking the active platform returns to All Platforms.
                    settings.selectedPlatform =
                        settings.selectedPlatform?.id == platform.id
                        ? nil
                        : platform
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                settings.selectedPlatform?.id == platform.id
                                    ? platform.color.opacity(0.22)
                                    : Color(hex: "17181D")
                            )

                        Circle()
                            .stroke(
                                settings.selectedPlatform?.id == platform.id
                                    ? platform.color.opacity(0.70)
                                    : Color.white.opacity(0.12),
                                lineWidth: 1
                            )

                        AppIconView(
                            assetName: platform.logoAssetName,
                            fallbackSymbol: "play.tv.fill",
                            renderingMode: .original
                        )
                        .frame(width: 20, height: 16)
                        .clipped()
                    }
                    .frame(width: badgeSize, height: badgeSize)
                    .contentShape(Circle())
                    .shadow(
                        color: .black.opacity(0.30),
                        radius: 4,
                        x: 0,
                        y: 1
                    )
                }
                .buttonStyle(.plain)
                // Higher index = later platform = visually on top.
                .zIndex(Double(index))
                .help(platform.name)
            }
        }
        .padding(.trailing, 8)
        .animation(.easeOut(duration: 0.15), value: selectedPlatform)
    }
}

// MARK: - Filter Dropdown

struct FilterDropdown<Content: View>: View {
    let label: String
    let buttonIcon: AnyView
    var panelWidth: CGFloat
    var panelHeight: CGFloat
    var panelAlignment: Alignment = .topLeading
    @Binding var isOpen: Bool

    @ViewBuilder
    let content: (@escaping () -> Void) -> Content

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 8) {
                buttonIcon
                    .font(.system(size: 13))

                Text(label)
                    .font(Theme.Font.body(13))
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: panelAlignment) {
            if isOpen {
                panel
                    .offset(y: 46)
                    .transition(
                        .opacity.combined(
                            with: .scale(
                                scale: 0.98,
                                anchor: panelAlignment == .topTrailing
                                    ? .topTrailing
                                    : .top
                            )
                        )
                    )
                    .zIndex(100)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isOpen)
    }

    private var panel: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 2) {
                content {
                    isOpen = false
                }
            }
            .padding(3.8)
        }
        .frame(width: panelWidth, height: panelHeight)
        .background(Color(hex: "28282C").opacity(0.98))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(
            color: .black.opacity(0.5),
            radius: 24,
            y: 8
        )
    }
}

// MARK: - Dropdown Row

struct FilterDropdownRow: View {
    let title: String
    let isSelected: Bool
    var leadingIcon: AnyView? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let leadingIcon {
                    leadingIcon
                        .font(.system(size: 13))
                }

                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(
                        isSelected
                            ? Theme.accent
                            : Color(hex: "EBEBF5")
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.top, 7)
            .padding(.bottom, 7)
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .frame(minHeight: 29)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isSelected
                ? Color.white.opacity(0.06)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
