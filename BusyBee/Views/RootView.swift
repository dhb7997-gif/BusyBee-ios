import SwiftUI

struct RootView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var showingSplash = true
    @State private var splashTaskStarted = false

    var body: some View {
        ZStack {
            ContentView()
                .environmentObject(budgetViewModel)
                .environmentObject(settings)

            if showingSplash {
                SplashView()
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(1)
            }
        }
        .task {
            guard !splashTaskStarted else { return }
            splashTaskStarted = true
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.6)) {
                    showingSplash = false
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
