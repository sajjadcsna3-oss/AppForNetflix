import SwiftUI

struct StreamingProviderPicker: View {
    let providers: [WatchProvider]
    let onSelect: (WatchProvider) -> Void

    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(L10n.string("Choose where to watch", languageCode: settings.languageCode))
                    .font(Theme.Font.title(22))
                    .fontWeight(.bold)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    providerSection("Stream", types: [.flatrate])
                    providerSection("Free / With Ads", types: [.free, .ads])
                    providerSection("Rent", types: [.rent])
                    providerSection("Buy", types: [.buy])
                }
            }
        }
        .padding(22)
        // FIX (Guideline 4 – "Windows cut off text"): a hardcoded
        // 440x520 sheet had no room to grow for longer localized section
        // titles/provider names, and no room to shrink on a smaller
        // display without clipping. A min/ideal/max range lets AppKit size
        // the sheet to fit its actual content on every window size.
        .frame(
            minWidth: 360, idealWidth: 440, maxWidth: 560,
            minHeight: 420, idealHeight: 520, maxHeight: 720
        )
        .background(Theme.surface)
        .foregroundStyle(Theme.textPrimary)
    }

    @ViewBuilder
    private func providerSection(
        _ title: String,
        types: Set<WatchMonetizationType>
    ) -> some View {
        let matching = providers.filter { !$0.monetizationTypes.isDisjoint(with: types) }
        if !matching.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string(title, languageCode: settings.languageCode).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textTertiary)

                ForEach(matching) { provider in
                    Button {
                        onSelect(provider)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            AsyncImage(url: provider.logoURL) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().scaledToFit()
                                } else {
                                    Image(systemName: "play.tv.fill")
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            Text(provider.name)
                                .font(Theme.Font.body(14))
                                .fontWeight(.medium)
                                .lineLimit(2)

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
