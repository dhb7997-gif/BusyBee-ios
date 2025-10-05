import SwiftUI

struct ExpenseHistoryView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel

    var body: some View {
        NavigationView {
            List {
                ForEach(historySections) { section in
                    Section(header: Text(section.formattedDate)) {
                        ForEach(section.items) { expense in
                            ExpenseRow(expense: expense)
                        }
                        .onDelete { indexSet in
                            deleteExpenses(indexSet, in: section)
                        }
                        HStack {
                            Text("Total")
                                .font(.subheadline)
                            Spacer()
                            Text(section.total.currencyString)
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("History")
            .toolbar {
                EditButton()
            }
        }
    }

    private var historySections: [ExpenseSection] {
        ExpenseHistoryViewModel(expenses: budgetViewModel.expenses).sections
    }

    private func deleteExpenses(_ offsets: IndexSet, in section: ExpenseSection) {
        for index in offsets {
            guard section.items.indices.contains(index) else { continue }
            let expense = section.items[index]
            Task {
                await budgetViewModel.removeExpense(expense)
            }
        }
    }
}

struct ExpenseHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        ExpenseHistoryView()
            .environmentObject(BudgetViewModel())
    }
}
