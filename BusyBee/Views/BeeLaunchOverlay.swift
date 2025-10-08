import SwiftUI

struct BeeLaunchOverlay: View {
    var onFinished: () -> Void

    @State private var writeProgress: CGFloat = 0
    @State private var slideProgress: CGFloat = 0
    @State private var taglineOpacity: Double = 0
    @State private var overlayOpacity: Double = 1

    private let totalDuration: Double = 3.6
    private let writeDuration: Double = 2.4
    private let slideDelay: Double = 2.5
    private let slideDuration: Double = 1.0

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 0.78, 320)

            ZStack {
                Color.clear.ignoresSafeArea()

                VStack(spacing: 18) {
                    Spacer(minLength: geo.size.height * 0.12)
                    ZStack(alignment: .leading) {
                        HoneyWord(width: width, progress: writeProgress, slide: slideProgress)
                            .frame(width: width, height: 100)

                        BeeSprite(progress: writeProgress, slide: slideProgress, width: width)
                            .frame(width: width, height: 100, alignment: .leading)
                    }
                    .frame(width: width, height: 120)
                    .offset(y: slideOffset(for: geo.size))

                    Text("Spend a little, save a lot.")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Color(.label))
                        .opacity(taglineOpacity)
                        .offset(y: slideOffset(for: geo.size))

                    Spacer()
                }
            }
            .opacity(overlayOpacity)
            .onAppear {
                runAnimation()
            }
        }
    }

    private func slideOffset(for size: CGSize) -> CGFloat {
        slideProgress * size.height
    }

    private func runAnimation() {
        withAnimation(.easeOut(duration: writeDuration)) {
            writeProgress = 1
        }

        withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
            taglineOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + slideDelay) {
            withAnimation(.easeIn(duration: slideDuration)) {
                slideProgress = 1
                taglineOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            withAnimation(.easeInOut(duration: 0.3)) {
                overlayOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onFinished()
            }
        }
    }
}

private struct HoneyWord: View {
    let width: CGFloat
    let progress: CGFloat
    let slide: CGFloat

    private let honeyColor = Color(red: 0.95, green: 0.72, blue: 0.25)
    private let highlightColor = Color(red: 1.0, green: 0.83, blue: 0.45)

    var body: some View {
        let maskWidth = max(width * progress, 1)

        Text("Bu$yBee")
            .font(.system(size: 60, weight: .heavy, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [honeyColor, highlightColor, honeyColor.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, alignment: .leading)
            .mask(
                Rectangle()
                    .frame(width: maskWidth)
                    .alignmentGuide(.leading) { d in d[.leading] }
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 6)
            .offset(y: slide * 400)
    }
}

private struct BeeSprite: View {
    let progress: CGFloat
    let slide: CGFloat
    let width: CGFloat

    private let amplitude: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let beePosition = position(size: geo.size)
            Image("BeeCharacter")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 90, height: 90)
                .rotationEffect(rotationAngle)
                .position(beePosition)
                .offset(y: slide * 400)
        }
    }

    private func position(size: CGSize) -> CGPoint {
        let x = width * progress
        let y = size.height * 0.45 - cos(progress * .pi) * amplitude
        return CGPoint(x: max(44, x + 30), y: y)
    }

    private var rotationAngle: Angle {
        let angle = sin(progress * .pi) * 18
        return Angle(degrees: Double(angle))
    }
}

struct BeeLaunchOverlay_Previews: PreviewProvider {
    static var previews: some View {
        BeeLaunchOverlay(onFinished: {})
            .background(Color(.systemBackground))
    }
}
