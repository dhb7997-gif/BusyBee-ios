import SwiftUI
import UIKit

struct AddExpenseView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel = AddExpenseViewModel()
    @Binding var isPresented: Bool
    @FocusState private var amountFieldFocused: Bool
    var showDatePicker: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var showingReceiptCapture = false
    @State private var receiptAlertTitle = ""
    @State private var receiptAlertMessage = ""
    @State private var showingReceiptAlert = false
    @State private var pendingReceiptExpenseID: UUID?

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
                            Text(settings.displayName(for: category)).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if showDatePicker {
                    Section(header: Text("Date")) {
                        DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
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
            .sheet(isPresented: $showingReceiptCapture) {
                ReceiptCaptureView { image in
                    handleReceiptCaptureResult(image)
                }
            }
            .alert(receiptAlertTitle, isPresented: $showingReceiptAlert) {
                Button("OK", role: .cancel) {
                    isPresented = false
                }
            } message: {
                Text(receiptAlertMessage)
            }
        }
    }

    private func saveExpense() async {
        guard let expense = viewModel.makeExpense(date: selectedDate) else { return }
        let created = await budgetViewModel.addExpense(vendor: expense.vendor, amount: expense.amount, category: expense.category, notes: expense.notes, date: expense.date)
        await MainActor.run {
            viewModel.reset()
            selectedDate = Date()
            pendingReceiptExpenseID = created.id
            if settings.receiptStorageEnabled {
                showingReceiptCapture = true
            } else {
                isPresented = false
                pendingReceiptExpenseID = nil
            }
        }
    }

    private func handleReceiptCaptureResult(_ image: UIImage?) {
        showingReceiptCapture = false
        guard let image, let expenseID = pendingReceiptExpenseID else {
            isPresented = false
            pendingReceiptExpenseID = nil
            return
        }

        Task {
            let success = await budgetViewModel.attachReceipt(image: image, to: expenseID)
            await MainActor.run {
                if success {
                    receiptAlertTitle = "Receipt Saved"
                    receiptAlertMessage = "Your receipt photo has been stored in BusyBee."
                } else {
                    receiptAlertTitle = "Save Failed"
                    receiptAlertMessage = "We couldn't save your receipt. Please try again."
                }
                showingReceiptAlert = true
                pendingReceiptExpenseID = nil
            }
        }
    }
}

struct AddExpenseView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = AppSettings.shared
        let store = DailyLimitStore.shared
        AddExpenseView(isPresented: .constant(true), showDatePicker: true)
            .environmentObject(BudgetViewModel(dailyLimitStore: store, settings: settings))
            .environmentObject(settings)
    }
}
