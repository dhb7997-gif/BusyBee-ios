import SwiftUI

struct QuickEntryView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @State private var selectedAmount: Decimal?
    @State private var selectedVendor: String?
    @State private var selectedCategory: ExpenseCategory?
    @State private var showingCustomAmount = false
    @State private var showingCustomVendor = false
    @State private var isSaving = false

    private let quickAmounts: [Decimal] = [5, 10, 15, 25, 50, 75]
    private let quickCategories: [ExpenseCategory] = [.food, .shopping, .transportation, .entertainment, .personal, .other]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            StepHeader(step: 1, title: "How much did you spend?")
            amountGrid

            StepHeader(step: 2, title: "Where did you spend it?", isEnabled: selectedAmount != nil)
            vendorGrid

            StepHeader(step: 3, title: "Pick a category", isEnabled: selectedVendor != nil)
            categoryGrid

            Button(action: logExpense) {
                Text(isSaving ? "Saving…" : "Log Expense")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canLog ? Color.accentColor : Color.accentColor.opacity(0.2))
                    .foregroundColor(canLog ? .white : Color.accentColor)
                    .cornerRadius(18)
            }
            .disabled(!canLog || isSaving)
        }
        .padding(24)
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
                selectedVendor = nil
                selectedCategory = nil
            }
        }
        .sheet(isPresented: $showingCustomVendor) {
            VendorEntryView(isPresented: $showingCustomVendor, initialVendor: selectedVendor) { vendor in
                selectedVendor = vendor
                selectedCategory = budgetViewModel.categoryHint(forVendor: vendor)
            }
        }
    }

    private var canLog: Bool {
        selectedAmount != nil && selectedVendor != nil && selectedCategory != nil
    }

    private var amountGrid: some View {
        AdaptiveGrid(columns: 3) {
            ForEach(quickAmounts, id: \.self) { amount in
                SelectionTile(isSelected: selectedAmount == amount, title: amount.currencyString) {
                    selectedAmount = amount
                    selectedVendor = nil
                    selectedCategory = nil
                }
            }
            SelectionTile(isSelected: isCustomAmountSelected, title: "Custom") {
                showingCustomAmount = true
            }
        }
    }

    private var vendorGrid: some View {
        AdaptiveGrid(columns: 3) {
            let vendors = vendorTiles
            let suggestions = vendors.compactMap { tile -> String? in
                if case let .suggestion(value) = tile.kind {
                    return value
                }
                return nil
            }
            ForEach(vendors.indices, id: \.self) { index in
                let vendor = vendors[index]
                SelectionTile(isSelected: isVendorSelected(vendor, suggestions: suggestions), title: vendor.displayName) {
                    guard selectedAmount != nil else { return }
                    switch vendor.kind {
                    case .suggestion(let value):
                        selectedVendor = value
                        selectedCategory = budgetViewModel.categoryHint(forVendor: value)
                    case .custom:
                        showingCustomVendor = true
                    }
                }
                .disabled(selectedAmount == nil)
                .opacity(selectedAmount == nil ? 0.5 : 1)
            }
        }
    }

    private var categoryGrid: some View {
        AdaptiveGrid(columns: 3) {
            ForEach(quickCategories, id: \.self) { category in
                SelectionTile(isSelected: selectedCategory == category, title: category.rawValue) {
                    guard selectedVendor != nil else { return }
                    selectedCategory = category
                }
                .disabled(selectedVendor == nil)
                .opacity(selectedVendor == nil ? 0.5 : 1)
            }
        }
    }

    private var isCustomAmountSelected: Bool {
        guard let amount = selectedAmount else { return showingCustomAmount }
        return !quickAmounts.contains(amount)
    }

    private var vendorTiles: [VendorTile] {
        var tiles: [VendorTile] = budgetViewModel
            .suggestedVendors(limit: 5)
            .map { VendorTile(kind: .suggestion($0)) }
        tiles.append(VendorTile(kind: .custom))
        return tiles
    }

    private func isVendorSelected(_ vendor: VendorTile, suggestions: [String]) -> Bool {
        guard let current = selectedVendor else { return false }
        switch vendor.kind {
        case .suggestion(let value):
            return current.caseInsensitiveCompare(value) == .orderedSame
        case .custom:
            return !suggestions.contains { current.caseInsensitiveCompare($0) == .orderedSame }
        }
    }

    private func logExpense() {
        guard canLog, !isSaving,
              let amount = selectedAmount,
              let vendor = selectedVendor,
              let category = selectedCategory else { return }
        isSaving = true
        Task {
            await budgetViewModel.addExpense(vendor: vendor, amount: amount, category: category)
            await MainActor.run {
                withAnimation(.spring()) {
                    selectedAmount = nil
                    selectedVendor = nil
                    selectedCategory = nil
                }
                isSaving = false
            }
        }
    }
}

private struct StepHeader: View {
    let step: Int
    let title: String
    var isEnabled: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Text("Step \(step)")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(isEnabled ? Color.accentColor : Color.gray.opacity(0.4))
                .clipShape(Capsule())
            Text(title)
                .font(.headline)
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
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(
                    ZStack {
                        if isSelected {
                            Color.accentColor.opacity(0.18)
                        } else {
                            Color(.secondarySystemBackground)
                        }
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
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
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: columns), spacing: 14) {
            content
        }
    }
}

private struct VendorTile: Identifiable {
    enum Kind {
        case suggestion(String)
        case custom
    }

    let id = UUID()
    let kind: Kind

    var displayName: String {
        switch kind {
        case .suggestion(let value):
            return value
        case .custom:
            return "Custom"
        }
    }
}

struct QuickEntryView_Previews: PreviewProvider {
    static var previews: some View {
        QuickEntryView()
            .environmentObject(BudgetViewModel())
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
