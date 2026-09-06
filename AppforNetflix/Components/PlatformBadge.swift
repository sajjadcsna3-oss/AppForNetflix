import SwiftUI

struct PlatformBadge: View {
    @EnvironmentObject private var settings: SettingsStore
    let platform: Platform
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            logo
            Text(platform.name)
                .font(Theme.Font.caption())
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Theme.surfaceElevated : .clear)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.border, lineWidth: isSelected ? 0 : 1))
    }

    @ViewBuilder
    private var logo: some View {
        if !platform.logoAssetName.isEmpty {
            AppIconView(assetName: platform.logoAssetName, fallbackSymbol: "play.tv.fill", renderingMode: .original)
                .frame(width: 16, height: 16)
        } else {
            Circle().fill(platform.color).frame(width: 8, height: 8)
        }
    }
}

struct PlatformFilterBar: View {
    @EnvironmentObject private var settings: SettingsStore
    let platforms: [Platform]
    @Binding var selected: Platform?

    private let baseLogoHeight: CGFloat = 14

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button { selected = nil } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(selected == nil ? Color.white : Color.clear)
                            .frame(width: 8, height: 8)
                        Text(L10n.string("All Platforms", languageCode: settings.languageCode))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selected == nil ? .white : .white.opacity(0.6))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(selected == nil ? Color.white.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                dividerLine
                ForEach(Array(platforms.enumerated()), id: \.element.id) { index, platform in
                    let isSelected = selected == platform
                    Button { selected = platform } label: {
                        HStack(spacing: 6) {
                            AppIconView(assetName: platform.logoAssetName, fallbackSymbol: "play.tv.fill", renderingMode: .original)
                                .frame(height: baseLogoHeight * platform.logoScale)
                            Text(platform.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    if index < platforms.count - 1 {
                        dividerLine
                    }
                }
            }
            .padding(6.8)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 4)
    }
}
