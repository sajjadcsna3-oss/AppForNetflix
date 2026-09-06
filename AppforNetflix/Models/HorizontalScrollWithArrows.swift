import SwiftUI

struct HorizontalScrollWithArrows<Item, Content: View>: View {

    let items: [Item]
    let spacing: CGFloat
    let content: (Item) -> Content

    @State private var scrollProxy: ScrollViewProxy?

    init(
        items: [Item],
        spacing: CGFloat = 16,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        HStack(spacing: 10) {

            Button {
                scrollLeft()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            ScrollViewReader { proxy in

                ScrollView(.horizontal, showsIndicators: false) {

                    HStack(spacing: spacing) {

                        ForEach(
                            Array(items.enumerated()),
                            id: \.offset
                        ) { index, item in

                            content(item)
                                .id(index)
                        }
                    }
                    // FIX: pehle sirf .horizontal, 2 tha aur vertical padding
                    // bilkul nahi thi. Cards hover pe scaleEffect(1.02) se
                    // thoda bade ho jaate hain, aur ScrollView apne content
                    // ko apne hi tight bounds mein clip karta hai — vertical
                    // padding na hone ki wajah se top/bottom ka extra hissa
                    // (jisme red border bhi shamil hai) hamesha cut ho jata
                    // tha. Ab dono taraf kaafi jagah di hai.
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                }
                .onAppear {
                    scrollProxy = proxy
                }
            }

            Button {
                scrollRight()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func scrollLeft() {
        guard !items.isEmpty else { return }

        scrollProxy?.scrollTo(
            0,
            anchor: .leading
        )
    }

    private func scrollRight() {
        guard !items.isEmpty else { return }

        scrollProxy?.scrollTo(
            max(items.count - 1, 0),
            anchor: .trailing
        )
    }
}
