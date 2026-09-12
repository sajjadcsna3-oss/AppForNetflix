import SwiftUI

struct HeroPlatformBadge: View {
    let platform: WatchProvider

    var body: some View {
        HStack(spacing: 6) {
            AsyncImage(url: platform.logoURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: "play.tv.fill")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: 24, height: 24)
            .background(Color(hex: "17181D"))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            }

            Text(platform.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)

            if !platform.availabilityLabel.isEmpty {
                Text(platform.availabilityLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
    }
}
