import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.9
    @State private var logoOpacity: Double = 0.0

    var body: some View {
        ZStack {
            Color(red: 0.99, green: 0.96, blue: 0.90)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("BusyBeeSplash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)

                Text("Bu$yBee")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .kerning(1.2)
                    .foregroundColor(Color(red: 0.14, green: 0.14, blue: 0.16))
                    .opacity(logoOpacity)

                Text("Spend a little, save a lot.")
                    .font(.headline.weight(.medium))
                    .foregroundColor(Color.black.opacity(0.45))
                    .opacity(logoOpacity)
            }
            .multilineTextAlignment(.center)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                logoOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                logoScale = 1.03
            }
        }
        .accessibilityHidden(true)
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView()
    }
}
