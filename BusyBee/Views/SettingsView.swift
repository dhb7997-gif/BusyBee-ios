import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var dailyLimitString: String = ""
    @FocusState private var limitFieldFocused: Bool
    @State private var showingLimitEditor = false
    @State private var autoTrackDoorDash = false
    @State private var autoTrackAmazon = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Budget Settings")) {
                    Button {
                        showingLimitEditor = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Spending Limit")
                                    .font(.body)
                                Text("Your target budget amount")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(dailyLimitString)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Picker("Period", selection: $settings.budgetPeriod) {
                        ForEach(BudgetPeriod.allCases) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Notifications")) {
                    Toggle(isOn: $settings.morningReminders) {
                        VStack(alignment: .leading) {
                            Text("Morning Reminders")
                            Text("Daily balance notifications")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle(isOn: $settings.endOfDaySummary) {
                        VStack(alignment: .leading) {
                            Text("End of Day Summary")
                            Text("Daily spending recap")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Smart Tracking")) {
                    Toggle(isOn: $autoTrackDoorDash) {
                        VStack(alignment: .leading) {
                            Text("Auto-Track DoorDash")
                            Text("Automatically add DoorDash orders")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle(isOn: $autoTrackAmazon) {
                        VStack(alignment: .leading) {
                            Text("Auto-Track Amazon")
                            Text("Automatically add Amazon purchases")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle(isOn: $settings.receiptStorageEnabled) {
                        VStack(alignment: .leading) {
                            Text("Receipt Auto-Capture")
                            Text("Prompt for a photo after saving")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Customization")) {
                    NavigationLink(destination: PresetAmountsView()) {
                        VStack(alignment: .leading) {
                            Text("Preset Amounts")
                            Text("Customize quick-add buttons")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink(destination: CategoriesView()) {
                        VStack(alignment: .leading) {
                            Text("Categories")
                            Text("Manage spending categories")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Account")) {
                    NavigationLink(destination: Text("Export Data")) {
                        VStack(alignment: .leading) {
                            Text("Export Data")
                            Text("Download CSV report")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(role: .destructive) {
                        Task {
                            await clearExpenses()
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text("Reset All Data")
                            Text("Clear expense history")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Feedback")) {
                    Toggle("Enable Animations", isOn: $settings.animationsEnabled)
                    Toggle("Enable Haptics", isOn: $settings.hapticsEnabled)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                dailyLimitString = budgetViewModel.allowanceAmount.currencyString
            }
            .onChange(of: settings.budgetPeriod) { _, _ in
                dailyLimitString = budgetViewModel.allowanceAmount.currencyString
            }
            .onReceive(budgetViewModel.$allowanceAmount) { newValue in
                dailyLimitString = newValue.currencyString
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Cancel") {
                        // Revert to current value and dismiss
                        dailyLimitString = budgetViewModel.allowanceAmount.currencyString
                        limitFieldFocused = false
                    }
                    Spacer()
                    Button("Done") {
                        commitDailyLimit()
                    }.bold()
                }
            }
            .sheet(isPresented: $showingLimitEditor) {
                SpendingLimitEditorView(
                    initialAmount: budgetViewModel.allowanceAmount,
                    onCancel: { showingLimitEditor = false },
                    onSave: { newAmount in
                        budgetViewModel.setDailyLimit(newAmount)
                        dailyLimitString = budgetViewModel.allowanceAmount.currencyString
                        showingLimitEditor = false
                    }
                )
            }
        }
    }

    private func commitDailyLimit() {
        let sanitized = dailyLimitString
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let decimal = Decimal(string: sanitized), decimal >= 0 {
            budgetViewModel.setDailyLimit(decimal)
            dailyLimitString = budgetViewModel.allowanceAmount.currencyString
        } else {
            // If invalid, revert
            dailyLimitString = budgetViewModel.allowanceAmount.currencyString
        }
        limitFieldFocused = false
    }

    private func clearExpenses() async {
        for expense in budgetViewModel.expenses {
            await budgetViewModel.removeExpense(expense)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = AppSettings.shared
        let store = DailyLimitStore.shared
        SettingsView()
            .environmentObject(BudgetViewModel(dailyLimitStore: store, settings: settings))
            .environmentObject(settings)
    }
}
