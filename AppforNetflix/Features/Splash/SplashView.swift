import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: "E50914").opacity(0.22), Theme.background],
                center: UnitPoint(x: 0.25, y: 0.3),
                startRadius: 20,
                endRadius: 600
            )
            .ignoresSafeArea()
            VStack(spacing: 20) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    
                    .scaleEffect(isAnimating ? 1 : 0.85)
                    .opacity(isAnimating ? 1 : 0)
                VStack(spacing: 8) {
                    Image("AppforNetflixlogo")
                        .frame(width: 272, height: 31, alignment: .center)
                    Image("AppText")
                        
                        .foregroundStyle(Theme.textSecondary)
                    AppIcon.image("SplashlineIcon", fallbackSymbol: "minus")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 140, height: 4)
                        .padding(.top, 4)
                }
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { isAnimating = true }
        }
    }
}
