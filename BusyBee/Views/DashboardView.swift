import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @Binding var showingAddExpense: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    BalanceSummaryCard(state: budgetViewModel.budgetState)
                    QuickEntryView()
                    RecentExpensesList(expenses: Array(budgetViewModel.expenses.prefix(5)))
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 20)
            }
            .background(
                LinearGradient(colors: [Color(white: 0.97), Color.white], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Daily Balance")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddExpense = true }) {
                        Label("Add Expense", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
    }
}

private struct RecentExpensesList: View {
    let expenses: [Expense]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Expenses")
                .font(.headline)
            if expenses.isEmpty {
                Text("No expenses yet. Use the quick tiles above to log your first purchase.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            } else {
                ForEach(expenses, id: \.id) { expense in
                    ExpenseRow(expense: expense)
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView(showingAddExpense: .constant(false))
            .environmentObject(BudgetViewModel())
    }
}
