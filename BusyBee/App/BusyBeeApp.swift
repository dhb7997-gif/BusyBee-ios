import SwiftUI

@main
struct BusyBeeApp: App {
    @StateObject private var budgetViewModel = BudgetViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(budgetViewModel)
        }
    }
}
