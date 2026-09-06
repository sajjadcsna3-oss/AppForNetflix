import SwiftUI

struct HeroPlatformBadge: View {
    let platform: Platform

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(platform.color)
                .frame(width: 8, height: 8)
            Text(platform.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
