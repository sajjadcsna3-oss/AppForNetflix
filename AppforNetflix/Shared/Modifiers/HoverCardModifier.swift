import SwiftUI

private struct HoverCardModifier: ViewModifier {
    @Binding var isHovering: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius)
                    .strokeBorder(isHovering ? Theme.accent : Color.clear, lineWidth: 2)
            }
            .scaleEffect(isHovering ? 1.02 : 1)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius))
            .onHover { isHovering = $0 }
    }
}

extension View {
    func hoverCardStyle(isHovering: Binding<Bool>) -> some View {
        modifier(HoverCardModifier(isHovering: isHovering))
    }
}
