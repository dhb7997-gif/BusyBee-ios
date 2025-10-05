import SwiftUI

struct AddExpenseView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @StateObject private var viewModel = AddExpenseViewModel()
    @Binding var isPresented: Bool
    @FocusState private var amountFieldFocused: Bool

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Vendor")) {
                    TextField("Where did you spend?", text: $viewModel.vendor)
                        .textInputAutocapitalization(.words)
                }

                Section(header: Text("Amount")) {
                    TextField("0.00", text: $viewModel.amountString)
                        .keyboardType(.decimalPad)
                        .focused($amountFieldFocused)
                }

                Section(header: Text("Category")) {
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(ExpenseCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Notes")) {
                    TextField("Optional details", text: $viewModel.notes)
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveExpense()
                        }
                    }
                    .disabled(!viewModel.isValid)
                }
            }
            .onAppear {
                amountFieldFocused = true
            }
        }
    }

    private func saveExpense() async {
        guard let expense = viewModel.makeExpense() else { return }
        await budgetViewModel.addExpense(vendor: expense.vendor, amount: expense.amount, category: expense.category, notes: expense.notes, date: expense.date)
        viewModel.reset()
        isPresented = false
    }
}

struct AddExpenseView_Previews: PreviewProvider {
    static var previews: some View {
        AddExpenseView(isPresented: .constant(true))
            .environmentObject(BudgetViewModel())
    }
}
