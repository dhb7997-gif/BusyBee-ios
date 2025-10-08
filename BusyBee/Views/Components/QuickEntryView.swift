import SwiftUI
import UIKit

struct QuickEntryView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var selectedAmount: Decimal?
    @State private var selectedCategory: ExpenseCategory?
    @State private var showingCustomAmount = false
    @State private var showingVendorEntry = false
    @State private var isSaving = false
    @State private var showingReceiptCapture = false
    @State private var receiptAlertTitle = ""
    @State private var receiptAlertMessage = ""
    @State private var showingReceiptAlert = false
    @State private var pendingReceiptExpenseID: UUID?

    private let quickCategories: [ExpenseCategory] = ExpenseCategory.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(step: 1, title: "How much did you spend?")
            amountGrid

            StepHeader(step: 2, title: "What category?", isEnabled: selectedAmount != nil)
            categoryGrid
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Color(.systemBackground), Color(.systemBackground).opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 12)
        .sheet(isPresented: $showingCustomAmount) {
            CustomAmountEntryView(isPresented: $showingCustomAmount, initialAmount: selectedAmount) { amount in
                selectedAmount = amount
                selectedCategory = nil
                // Show vendor entry screen
                showingVendorEntry = true
                showingCustomAmount = false
            }
        }
        .sheet(isPresented: $showingVendorEntry) {
            if let amount = selectedAmount {
                VendorEntryView(
                    isPresented: $showingVendorEntry,
                    initialVendor: nil,
                    amount: amount
                ) { vendor, category, createdExpense in
                    Task {
                        if let category = category {
                            await recordExpense(vendor: vendor, amount: amount, category: category)
                        } else {
                            await MainActor.run {
                                withAnimation(.spring()) {
                                    selectedAmount = nil
                                    selectedCategory = nil
                                }
                                if settings.receiptStorageEnabled, let created = createdExpense {
                                    pendingReceiptExpenseID = created.id
                                    showingReceiptCapture = true
                                } else {
                                    pendingReceiptExpenseID = nil
                                }
                            }
                        }
                    }
                }
                .environmentObject(budgetViewModel)
            }
        }
        .sheet(isPresented: $showingReceiptCapture) {
            ReceiptCaptureView { image in
                handleReceiptCaptureResult(image)
            }
        }
        .onChange(of: settings.presetAmounts) { _, _ in
            // Reset selection if the selected amount is no longer available
            if let selected = selectedAmount, !settings.presetAmounts.contains(selected) {
                selectedAmount = nil
                selectedCategory = nil
            }
        }
        .alert(receiptAlertTitle, isPresented: $showingReceiptAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(receiptAlertMessage)
        }
    }

    private var canLog: Bool {
        selectedAmount != nil && selectedCategory != nil
    }

    private var amountGrid: some View {
        AdaptiveGrid(columns: 3) {
            ForEach(settings.presetAmounts, id: \.self) { amount in
                SelectionTile(isSelected: selectedAmount == amount, title: amount.currencyString) {
                    selectedAmount = amount
                    selectedCategory = nil
                }
            }
            SelectionTile(isSelected: isCustomAmountSelected, title: "Custom") {
                showingCustomAmount = true
            }
        }
    }


    private var categoryGrid: some View {
        AdaptiveGrid(columns: 3) {
            ForEach(quickCategories, id: \.self) { category in
                SelectionTile(isSelected: selectedCategory == category, title: settings.displayName(for: category)) {
                    guard selectedAmount != nil else { return }
                    selectedCategory = category
                    // Auto-log the expense when both amount and category are selected
                    Task {
                        await autoLogExpense()
                    }
                }
                .disabled(selectedAmount == nil)
                .opacity(selectedAmount == nil ? 0.5 : 1)
            }
        }
    }

    private var isCustomAmountSelected: Bool {
        guard let amount = selectedAmount else { return showingCustomAmount }
        return !settings.presetAmounts.contains(amount)
    }


    private func autoLogExpense() async {
        guard canLog, !isSaving,
              let amount = selectedAmount,
              let category = selectedCategory else { return }
        
        isSaving = true
        // Use a default vendor since we removed vendor selection
        await recordExpense(vendor: "Quick Entry", amount: amount, category: category)
        await MainActor.run {
            isSaving = false
        }
    }

    private func recordExpense(vendor: String, amount: Decimal, category: ExpenseCategory) async {
        let created = await budgetViewModel.addExpense(vendor: vendor, amount: amount, category: category)
        await MainActor.run {
            withAnimation(.spring()) {
                selectedAmount = nil
                selectedCategory = nil
            }
            if settings.receiptStorageEnabled {
                pendingReceiptExpenseID = created.id
                showingReceiptCapture = true
            } else {
                pendingReceiptExpenseID = nil
            }
        }
    }

    private func handleReceiptCaptureResult(_ image: UIImage?) {
        showingReceiptCapture = false
        guard let expenseID = pendingReceiptExpenseID else { return }
        guard let image else {
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

private struct StepHeader: View {
    let step: Int
    let title: String
    var isEnabled: Bool = true

    var body: some View {
        HStack(spacing: 10) {
            Text("Step \(step)")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(isEnabled ? Color.accentColor : Color.gray.opacity(0.4))
                .clipShape(Capsule())
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isEnabled ? .primary : .secondary)
            Spacer()
        }
    }
}

private struct SelectionTile: View {
    var isSelected: Bool
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 68)
                .background(
                    ZStack {
                        if isSelected {
                            Color.accentColor.opacity(0.18)
                        } else {
                            Color(.secondarySystemBackground)
                        }
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    }
                )
                .cornerRadius(18)
                .foregroundColor(isSelected ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct AdaptiveGrid<Content: View>: View {
    let columns: Int
    @ViewBuilder var content: Content

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: columns), spacing: 9) {
            content
        }
    }
}


struct QuickEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = AppSettings.shared
        let store = DailyLimitStore.shared
        QuickEntryView()
            .environmentObject(BudgetViewModel(dailyLimitStore: store, settings: settings))
            .environmentObject(settings)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
