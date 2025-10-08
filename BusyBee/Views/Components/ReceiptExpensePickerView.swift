import SwiftUI

struct ReceiptExpensePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    let expenses: [Expense]
    var onSelect: (Expense) -> Void

    private var recentExpenses: [Expense] {
        Array(expenses.prefix(30))
    }

    var body: some View {
        NavigationView {
            List {
                if recentExpenses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No expenses yet")
                            .font(.headline)
                        Text("Log an expense before attaching a receipt.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                } else {
                    ForEach(recentExpenses) { expense in
                        Button {
                            onSelect(expense)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(expense.vendor)
                                        .font(.headline)
                                    Text(settings.displayName(for: expense.category))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(expense.amount.currencyString)
                                        .font(.headline)
                                    Text(expense.date, style: .date)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Select Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct ReceiptExpensePickerView_Previews: PreviewProvider {
    static var previews: some View {
        ReceiptExpensePickerView(expenses: Expense.demoData) { _ in }
            .environmentObject(AppSettings.shared)
    }
}
