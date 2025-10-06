import SwiftUI

@main
struct BusyBeeApp: App {
    @StateObject private var appSettings: AppSettings
    @StateObject private var budgetViewModel: BudgetViewModel

    init() {
        let settings = AppSettings.shared
        let limitStore = DailyLimitStore.shared
        _appSettings = StateObject(wrappedValue: settings)
        _budgetViewModel = StateObject(wrappedValue: BudgetViewModel(dailyLimitStore: limitStore, settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(budgetViewModel)
                .environmentObject(appSettings)
        }
    }
}
