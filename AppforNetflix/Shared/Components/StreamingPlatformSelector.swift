import SwiftUI

struct StreamingPlatformSelector: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var storeKit: StoreKitService

    @StateObject private var viewModel = StreamingPlatformSelectorViewModel()
    @State private var isPresented = false
    @State private var searchText = ""

    private var providers: [WatchProvider] { viewModel.providers }

    private var regionCode: String {
        settings.regionCode
    }

    private var selectedProviders: [WatchProvider] {
        providers.filter { settings.isConnected(providerID: $0.id) }
    }

    private var filteredProviders: [WatchProvider] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return providers }
        return providers.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var allProvidersSelected: Bool {
        !providers.isEmpty && providers.allSatisfy {
            settings.isConnected(providerID: $0.id)
        }
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 8) {
                providerLogos(selectedProviders, maximum: 2, size: 24)

                Text(selectedCountText)
                    .font(Theme.Font.body(13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minWidth: 132)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            selectorPanel
        }
        .task(id: regionCode) {
            await loadProviders()
        }
    }

    private var selectorPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.string("Choose your platforms", languageCode: settings.languageCode))
                    .font(Theme.Font.title(20))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                providerLogos(selectedProviders, maximum: 3, size: 30)

                Text(selectedCountText)
                    .font(Theme.Font.body(13))
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer()

                Button {
                    if allProvidersSelected {
                        settings.setConnectedProviderIDs([])
                    } else {
                        selectAllProviders()
                    }
                } label: {
                    Label(
                        L10n.string(
                            allProvidersSelected ? "Deselect All" : "Select All",
                            languageCode: settings.languageCode
                        ),
                        systemImage: allProvidersSelected ? "xmark.circle" : "checkmark.circle"
                    )
                    .font(Theme.Font.body(12))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .disabled(providers.isEmpty)
            }
            .padding(12)
            .background(Color.white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textTertiary)

                TextField(
                    L10n.string("Search Platforms", languageCode: settings.languageCode),
                    text: $searchText
                )
                .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 10) {
                        Text(errorMessage)
                            .font(Theme.Font.caption(12))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Button(L10n.string("Try Again", languageCode: settings.languageCode)) {
                            Task { await loadProviders() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: true) {
                        LazyVStack(spacing: 6) {
                            ForEach(filteredProviders) { provider in
                                providerRow(provider)
                            }
                        }
                        .padding(.trailing, 3)
                    }
                }
            }
            // FIX (Guideline 4): a fixed 310pt list area truncated the
            // provider list (and clipped the error/empty states) once more
            // than a handful of providers loaded for a region. A min/ideal/
            // max range lets this grow to fit real TMDB data per-region.
            .frame(minHeight: 240, idealHeight: 310, maxHeight: 460)
        }
        .padding(18)
        // FIX (Guideline 4): same issue as above — a fixed 440pt panel
        // width couldn't accommodate longer localized labels ("Deselect
        // All" translations, provider names) without clipping.
        .frame(minWidth: 360, idealWidth: 440, maxWidth: 560)
        .background(Theme.surface)
        .foregroundStyle(Theme.textPrimary)
    }

    private func providerRow(_ provider: WatchProvider) -> some View {
        let isSelected = settings.isConnected(providerID: provider.id)

        return Button {
            if isSelected {
                var selection = settings.connectedPlatformIDs
                selection.remove(provider.id)
                settings.setConnectedProviderIDs(selection)
            } else if settings.canConnect(providerID: provider.id, isPremium: isPremiumUser) {
                enableProviders([provider.id])
            } else {
                isPresented = false
                router.showSubscription(then: .enablePlatforms([provider.id]))
            }
        } label: {
            HStack(spacing: 12) {
                providerLogo(provider, size: 34)

                Text(provider.name)
                    .font(Theme.Font.body(14))
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                Toggle("", isOn: .constant(isSelected))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Theme.accent)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white.opacity(0.055) : Color.white.opacity(0.025))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func providerLogos(
        _ providers: [WatchProvider],
        maximum: Int,
        size: CGFloat
    ) -> some View {
        if providers.isEmpty {
            Image(systemName: "play.tv")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: size, height: size)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            HStack(spacing: -5) {
                ForEach(Array(providers.prefix(maximum).enumerated()), id: \.element.id) { index, provider in
                    providerLogo(provider, size: size)
                        .zIndex(Double(index))
                }
            }
        }
    }

    @ViewBuilder
    private func providerLogo(_ provider: WatchProvider, size: CGFloat) -> some View {
        AsyncImage(url: provider.logoURL) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFit()
            } else {
                Image(systemName: "play.tv.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .background(Color(hex: "17181D"))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }

    private var selectedCountText: String {
        L10n.format(
            "selected_platform_count_format",
            languageCode: settings.languageCode,
            selectedProviders.count
        )
    }

    private var isPremiumUser: Bool {
        storeKit.hasPremiumEntitlement
    }

    private func enableProviders(_ providerIDs: Set<Int>) {
        settings.setConnectedProviderIDs(settings.connectedPlatformIDs.union(providerIDs))
    }

    private func selectAllProviders() {
        let allProviderIDs = Set(providers.map(\.id))
        let premiumProviderIDs = allProviderIDs.subtracting(SettingsStore.freeProviderIDs)

        if isPremiumUser || premiumProviderIDs.isEmpty {
            settings.setConnectedProviderIDs(allProviderIDs)
        } else {
            isPresented = false
            router.showSubscription(then: .enablePlatforms(allProviderIDs))
        }
    }

    private func loadProviders() async {
        await viewModel.load(region: regionCode)
        settings.updateAvailableWatchProviders(viewModel.providers)
    }

}
