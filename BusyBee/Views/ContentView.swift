import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var showingAddExpense = false

    var body: some View {
        TabView {
            DashboardView(showingAddExpense: $showingAddExpense)
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }

            SummaryView()
                .tabItem {
                    Label("Summary", systemImage: "chart.bar.fill")
                }

            ExpenseHistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(isPresented: $showingAddExpense)
                .environmentObject(budgetViewModel)
                .environmentObject(settings)
        }
        .environmentObject(budgetViewModel)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = AppSettings.shared
        let store = DailyLimitStore.shared
        ContentView()
            .environmentObject(BudgetViewModel(dailyLimitStore: store, settings: settings))
            .environmentObject(settings)
    }
}
