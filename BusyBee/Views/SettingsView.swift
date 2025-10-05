import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @State private var dailyLimitString: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Daily Limit")) {
                    TextField("200", text: Binding(
                        get: { dailyLimitString },
                        set: { newValue in
                            dailyLimitString = newValue
                            updateDailyLimitIfNeeded()
                        }
                    ))
                    .keyboardType(.decimalPad)
                }

                Section(header: Text("Data")) {
                    Button(role: .destructive) {
                        Task {
                            await clearExpenses()
                        }
                    } label: {
                        Text("Clear All Expenses")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                dailyLimitString = NSDecimalNumber(decimal: budgetViewModel.dailyLimit).stringValue
            }
        }
    }

    private func updateDailyLimitIfNeeded() {
        let sanitized = dailyLimitString.filter { !$0.isWhitespace }
        guard let decimal = Decimal(string: sanitized) else { return }
        budgetViewModel.setDailyLimit(decimal)
    }

    private func clearExpenses() async {
        for expense in budgetViewModel.expenses {
            await budgetViewModel.removeExpense(expense)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(BudgetViewModel())
    }
}
