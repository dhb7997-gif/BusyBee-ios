import Foundation
import Combine

@MainActor
final class BudgetViewModel: ObservableObject {
    @Published private(set) var expenses: [Expense] = []
    @Published var dailyLimit: Decimal
    @Published private(set) var budgetState: DailyBudgetState

    private let calendar: Calendar
    private let expenseStore: ExpenseStore
    private var cancellables = Set<AnyCancellable>()
    private let defaultVendors = ["DoorDash", "Amazon", "Uber", "Lyft", "Starbucks", "Target", "Trader Joe's", "Whole Foods", "Sephora", "Netflix"]
    private let vendorCategoryHints: [String: ExpenseCategory] = [
        "doordash": .food,
        "ubereats": .food,
        "starbucks": .food,
        "whole foods": .food,
        "trader joe's": .food,
        "amazon": .shopping,
        "target": .shopping,
        "netflix": .entertainment,
        "ubere": .transportation,
        "uber": .transportation,
        "lyft": .transportation,
        "sephora": .personal
    ]

    init(dailyLimit: Decimal = Decimal(200), calendar: Calendar = .current, expenseStore: ExpenseStore = ExpenseStore()) {
        self.dailyLimit = dailyLimit
        self.calendar = calendar
        self.expenseStore = expenseStore
        let today = calendar.startOfDay(for: Date())
        let initialState = DailyBudget(date: today, dailyLimit: dailyLimit, rollover: .zero).updating(for: [])
        self.budgetState = initialState
        observeChanges()
        Task {
            await loadExpenses()
        }
    }

    func loadExpenses() async {
        do {
            let loaded = try await expenseStore.load()
            expenses = loaded.sorted { $0.date > $1.date }
            recalculateBudget()
        } catch {
            print("Failed to load expenses: \(error)")
        }
    }

    func addExpense(vendor: String, amount: Decimal, category: ExpenseCategory, notes: String? = nil, date: Date = Date()) async {
        var sanitizedAmount = amount
        if sanitizedAmount < 0 {
            sanitizedAmount = -sanitizedAmount
        }
        let expense = Expense(vendor: vendor, amount: sanitizedAmount, category: category, date: date, notes: notes)
        expenses.insert(expense, at: 0)
        recalculateBudget()
        await persist()
    }

    func removeExpense(_ expense: Expense) async {
        expenses.removeAll { $0.id == expense.id }
        recalculateBudget()
        await persist()
    }

    func setDailyLimit(_ newLimit: Decimal) {
        dailyLimit = max(newLimit, 0)
        recalculateBudget()
    }

    func rolloverAmount(for date: Date) -> Decimal {
        let previousDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) ?? date
        let previousExpenses = expenses.filter { calendar.isDate($0.date, inSameDayAs: previousDay) }
        let previousTotal = previousExpenses.reduce(Decimal.zero) { $0 + $1.amount }
        let remaining = dailyLimit - previousTotal
        return remaining
    }

    func suggestedVendors(limit: Int = 6) -> [String] {
        var seen = Set<String>()
        var suggestions: [String] = []

        for expense in expenses {
            let trimmed = expense.vendor.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                suggestions.append(expense.vendor)
                if suggestions.count >= limit { return suggestions }
            }
        }

        for vendor in defaultVendors where seen.insert(vendor.lowercased()).inserted {
            suggestions.append(vendor)
            if suggestions.count >= limit { break }
        }

        return suggestions
    }

    func categoryHint(forVendor vendor: String) -> ExpenseCategory {
        let normalized = vendor.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let existing = expenses.first(where: { $0.vendor.lowercased() == normalized }) {
            return existing.category
        }
        if let hint = vendorCategoryHints[normalized] {
            return hint
        }
        return .other
    }

    private func observeChanges() {
        $dailyLimit
            .sink { [weak self] _ in
                self?.recalculateBudget()
            }
            .store(in: &cancellables)
    }

    private func recalculateBudget() {
        let today = calendar.startOfDay(for: Date())
        let rollover = rolloverAmount(for: today)
        let budget = DailyBudget(date: today, dailyLimit: dailyLimit, rollover: rollover)
        budgetState = budget.updating(for: expenses, calendar: calendar)
    }

    private func persist() async {
        do {
            try await expenseStore.save(expenses)
        } catch {
            print("Failed to save expenses: \(error)")
        }
    }
}
