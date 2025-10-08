import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @EnvironmentObject private var settings: AppSettings
    @Binding var showingAddExpense: Bool
    @State private var showingVoiceEntry = false
    @State private var showingManualReceiptCapture = false
    @State private var manualReceiptAlertTitle = ""
    @State private var manualReceiptAlertMessage = ""
    @State private var showingManualReceiptAlert = false
    @State private var showingExpensePicker = false
    @State private var pendingManualReceiptExpenseID: UUID?
    @State private var receiptPreviewExpense: Expense?
    @State private var showingReceiptViewer = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    BalanceSummaryCard(
                        state: budgetViewModel.budgetState,
                        weeklyRemaining: budgetViewModel.weeklyRemaining,
                        budgetPeriod: settings.budgetPeriod
                    )
                    QuickEntryView()
                    RecentExpensesList(expenses: Array(budgetViewModel.expenses.prefix(5))) { expense in
                        receiptPreviewExpense = expense
                        showingReceiptViewer = true
                    }
                    Button(action: {
                        pendingManualReceiptExpenseID = nil
                        showingExpensePicker = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Capture Receipt")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .accessibilityLabel(Text("Capture receipt photo"))
                    .disabled(budgetViewModel.expenses.isEmpty)
                    .opacity(budgetViewModel.expenses.isEmpty ? 0.5 : 1)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
            }
            .background(
                LinearGradient(colors: [Color(white: 0.97), Color.white], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Daily Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingVoiceEntry = true }) {
                        Image(systemName: "mic.fill")
                            .accessibilityLabel(Text("Voice Entry"))
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddExpense = true }) {
                        Label("Add Expense", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showingVoiceEntry) {
            VoiceExpenseEntryView()
                .environmentObject(budgetViewModel)
                .environmentObject(settings)
        }
        .sheet(isPresented: $showingExpensePicker) {
            ReceiptExpensePickerView(expenses: budgetViewModel.expenses) { expense in
                pendingManualReceiptExpenseID = expense.id
                showingExpensePicker = false
                showingManualReceiptCapture = true
            }
            .environmentObject(settings)
        }
        .sheet(isPresented: $showingManualReceiptCapture) {
            ReceiptCaptureView { image in
                handleManualReceiptCapture(image)
            }
        }
        .sheet(isPresented: $showingReceiptViewer, onDismiss: { receiptPreviewExpense = nil }) {
            if let expense = receiptPreviewExpense {
                ReceiptViewerView(expense: expense)
                    .environmentObject(budgetViewModel)
            }
        }
        .alert(manualReceiptAlertTitle, isPresented: $showingManualReceiptAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(manualReceiptAlertMessage)
        }
    }
}

private struct RecentExpensesList: View {
    let expenses: [Expense]
    var onReceiptTapped: (Expense) -> Void

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
                    ExpenseRow(expense: expense, onReceiptTapped: onReceiptTapped)
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
        let settings = AppSettings.shared
        let store = DailyLimitStore.shared
        DashboardView(showingAddExpense: .constant(false))
            .environmentObject(BudgetViewModel(dailyLimitStore: store, settings: settings))
            .environmentObject(settings)
    }
}

private extension DashboardView {
    func handleManualReceiptCapture(_ image: UIImage?) {
        showingManualReceiptCapture = false
        guard let expenseID = pendingManualReceiptExpenseID else { return }
        guard let image else {
            pendingManualReceiptExpenseID = nil
            return
        }

        Task {
            let success = await budgetViewModel.attachReceipt(image: image, to: expenseID)
            await MainActor.run {
                if success {
                    manualReceiptAlertTitle = "Receipt Saved"
                    manualReceiptAlertMessage = "Your receipt photo has been stored in BusyBee."
                } else {
                    manualReceiptAlertTitle = "Save Failed"
                    manualReceiptAlertMessage = "We couldn't save your receipt. Please try again."
                }
                showingManualReceiptAlert = true
                pendingManualReceiptExpenseID = nil
            }
        }
    }
}
