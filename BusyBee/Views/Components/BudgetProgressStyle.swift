import SwiftUI

struct BudgetProgressStyle: ProgressViewStyle {
    let status: BudgetStatus

    func makeBody(configuration: Configuration) -> some View {
        let progress = configuration.fractionCompleted ?? 0
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.secondarySystemFill))
                Capsule()
                    .fill(fillColor)
                    .frame(width: geometry.size.width * progress)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 12)
    }

    private var fillColor: Color {
        switch status {
        case .comfortable:
            return Color(hex: 0x00D4AA)
        case .caution:
            return Color(hex: 0xFFB84D)
        case .overLimit:
            return Color(hex: 0xFF6B6B)
        }
    }
}

private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let red = Double((hex & 0xFF0000) >> 16) / 255.0
        let green = Double((hex & 0x00FF00) >> 8) / 255.0
        let blue = Double(hex & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
}
