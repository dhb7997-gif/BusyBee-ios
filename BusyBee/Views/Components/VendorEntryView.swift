import SwiftUI

struct VendorEntryView: View {
    @Binding var isPresented: Bool
    var initialVendor: String?
    var amount: Decimal
    var onComplete: (String, ExpenseCategory?) -> Void

    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var vendorName: String = ""
    @State private var topVendors: [VendorUsage] = []
    @State private var isKnownVendor: Bool = false
    @State private var showingCategorySelection = false
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Amount Display
                VStack(spacing: 8) {
                    Text("Amount")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(amount.currencyString)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)

                // Common Vendors Section
                if !topVendors.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Common Vendors")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(topVendors, id: \.id) { vendor in
                                CommonVendorTile(vendor: vendor, displayName: settings.displayName(for: vendor.category)) {
                                    onComplete(vendor.vendor, nil) // nil means auto-log with known category
                                    isPresented = false
                                }
                            }
                        }
                    }
                }

                // Manual Vendor Entry
                VStack(alignment: .leading, spacing: 12) {
                    Text("Or Enter Vendor")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextField("Enter vendor name", text: $vendorName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .onChange(of: vendorName) { _, newValue in
                            checkIfKnownVendor(newValue)
                        }
                }

                Spacer()

                // Action Button
                Button(action: handleVendorEntry) {
                    Text(isKnownVendor ? "Add Expense" : "Select Category")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canProceed ? Color.accentColor : Color.accentColor.opacity(0.2))
                        .foregroundColor(canProceed ? .white : Color.accentColor)
                        .cornerRadius(16)
                }
                .disabled(!canProceed)
            }
            .padding()
            .navigationTitle("Enter Vendor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showingCategorySelection) {
                CategorySelectionView(
                    vendorName: vendorName,
                    amount: amount,
                    onComplete: { vendor, category in
                        onComplete(vendor, category)
                        isPresented = false
                    }
                )
            }
            .task {
                await loadTopVendors()
                if let initial = initialVendor {
                    vendorName = initial
                    checkIfKnownVendor(initial)
                }
                isLoading = false
            }
        }
    }

    private var canProceed: Bool {
        !vendorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadTopVendors() async {
        topVendors = await budgetViewModel.getTopVendors(limit: 6)
    }

    private func checkIfKnownVendor(_ vendor: String) {
        let trimmed = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isKnownVendor = false
            return
        }
        
        Task {
            isKnownVendor = await budgetViewModel.isKnownVendor(trimmed)
        }
    }

    private func handleVendorEntry() {
        let trimmed = vendorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if isKnownVendor {
            // Known vendor - auto-log immediately
            Task {
                let success = await budgetViewModel.addExpenseWithKnownVendor(vendor: trimmed, amount: amount)
                if success {
                    onComplete(trimmed, nil)
                    isPresented = false
                }
            }
        } else {
            // Unknown vendor - show category selection
            showingCategorySelection = true
        }
    }
}

private struct CommonVendorTile: View {
    let vendor: VendorUsage
    let displayName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(vendor.vendor)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(Color.accentColor.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

private struct CategorySelectionView: View {
    let vendorName: String
    let amount: Decimal
    let onComplete: (String, ExpenseCategory) -> Void
    
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    private let categories: [ExpenseCategory] = ExpenseCategory.allCases
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Select Category for")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(vendorName)
                        .font(.title2.weight(.semibold))
                    Text(amount.currencyString)
                        .font(.title.weight(.bold))
                        .foregroundColor(.accentColor)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: {
                            onComplete(vendorName, category)
                            dismiss()
                        }) {
                            Text(settings.displayName(for: category))
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 70)
                                .background(Color.accentColor.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct VendorEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = AppSettings.shared
        let store = DailyLimitStore.shared
        VendorEntryView(isPresented: .constant(true), initialVendor: "", amount: Decimal(25.50), onComplete: { _, _ in })
            .environmentObject(BudgetViewModel(dailyLimitStore: store, settings: settings))
            .environmentObject(settings)
    }
}
