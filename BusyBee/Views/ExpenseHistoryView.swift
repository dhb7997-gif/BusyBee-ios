import SwiftUI

struct ExpenseHistoryView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var selectedFilter: ExpenseHistoryFilter = .today
    @State private var showingAddExpense: Bool = false
    @State private var pulseSummary: Bool = false

    var body: some View {
        NavigationView {
            List {
                filterHeader
                summaryCard
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
                addExpenseFooter
            }
            .listStyle(.insetGrouped)
            .refreshable {
                withAnimation(.easeInOut(duration: 0.3)) {
                    pulseSummary.toggle()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        pulseSummary.toggle()
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                EditButton()
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView(isPresented: $showingAddExpense, showDatePicker: true)
                    .environmentObject(budgetViewModel)
                    .environmentObject(settings)
            }
        }
    }

    private var historySections: [ExpenseSection] {
        ExpenseHistoryViewModel(expenses: budgetViewModel.expenses, filter: selectedFilter).sections
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

    private var filterHeader: some View {
        Section {
            HStack(spacing: 12) {
                ForEach(ExpenseHistoryFilter.allCases) { filter in
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedFilter = filter
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(filter.emoji)
                                .font(.title3)
                            Text(filter.rawValue)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            Group {
                                if selectedFilter == filter {
                                    LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                                } else {
                                    Color(.systemGray6)
                                }
                            }
                        )
                        .foregroundColor(selectedFilter == filter ? .white : .primary)
                        .clipShape(Capsule())
                        .shadow(color: (selectedFilter == filter ? Color.blue.opacity(0.3) : Color.clear), radius: 6, x: 0, y: 3)
                        .scaleEffect(selectedFilter == filter ? 1.02 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(filter.rawValue) filter"))
                    .accessibilityAddTraits(selectedFilter == filter ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var summaryCard: some View {
        Section {
            VStack(spacing: 8) {
                Text(summaryTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(filteredTotal.currencyString)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .background(
                LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
            , in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.blue.opacity(0.25), radius: 12, x: 0, y: 6)
            .scaleEffect(pulseSummary ? 1.01 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseSummary = true
                }
            }
        }
    }

    private var summaryTitle: String {
        switch selectedFilter {
        case .today: return "Today's Total"
        case .week: return "This Week's Total"
        case .month: return "This Month's Total"
        }
    }

    private var filteredTotal: Decimal {
        let sections = historySections
        let all = sections.flatMap { $0.items }
        return all.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var addExpenseFooter: some View {
        Section {
            Button(action: { showingAddExpense = true }) {
                HStack {
                    Spacer()
                    Label("Add Expense", systemImage: "plus.circle.fill")
                    Spacer()
                }
            }
            .accessibilityLabel(Text("Add Expense"))
        }
    }
}

struct ExpenseHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = AppSettings.shared
        let store = DailyLimitStore.shared
        ExpenseHistoryView()
            .environmentObject(BudgetViewModel(dailyLimitStore: store, settings: settings))
            .environmentObject(settings)
    }
}
