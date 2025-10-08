import SwiftUI

struct RootView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var showingIntro = true
    @State private var deficitBanner: DeficitAlert?

    var body: some View {
        ZStack {
            ContentView()
                .environmentObject(budgetViewModel)
                .environmentObject(settings)
                .overlay(alignment: .top) {
                    if let banner = deficitBanner {
                        DeficitBanner(alert: banner) {
                            withAnimation(.easeInOut) {
                                deficitBanner = nil
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, showingIntro ? 0 : 8)
                    }
                }

            if showingIntro {
                BeeLaunchOverlay {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showingIntro = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationManager.deficitNotificationName)) { notification in
            guard let remaining = notification.userInfo?["amount"] as? Decimal else { return }
            let message = "You're \(abs(remaining).currencyString) over your daily limit. Tomorrow is a fresh start!"
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                deficitBanner = DeficitAlert(message: message)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeInOut) {
                    deficitBanner = nil
                }
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = AppSettings.shared
        let store = DailyLimitStore.shared
        RootView()
            .environmentObject(BudgetViewModel(dailyLimitStore: store, settings: settings))
            .environmentObject(settings)
    }
}

private struct DeficitAlert: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

private struct DeficitBanner: View {
    let alert: DeficitAlert
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Over Budget")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(alert.message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            Spacer(minLength: 16)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.9))
                    .padding(6)
                    .background(Color.white.opacity(0.2), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.red.gradient)
                .shadow(color: .red.opacity(0.3), radius: 12, x: 0, y: 6)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}
