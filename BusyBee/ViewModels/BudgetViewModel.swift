import Foundation
import Combine

@MainActor
final class BudgetViewModel: ObservableObject {
    @Published private(set) var expenses: [Expense] = []
    @Published var dailyLimit: Decimal
    @Published private(set) var budgetState: DailyBudgetState
    @Published private(set) var weeklyRemaining: Decimal = .zero

    private let calendar: Calendar
    private let expenseStore: ExpenseStore
    private let vendorTracker: VendorTracker
    private let dailyLimitStore: DailyLimitStore
    private var cancellables = Set<AnyCancellable>()
    private let settings: AppSettings
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

    init(
        dailyLimit: Decimal = Decimal(200),
        calendar: Calendar = .current,
        expenseStore: ExpenseStore = ExpenseStore(),
        vendorTracker: VendorTracker = VendorTracker(),
        dailyLimitStore: DailyLimitStore,
        settings: AppSettings
    ) {
        self.dailyLimit = dailyLimit
        self.calendar = calendar
        self.expenseStore = expenseStore
        self.vendorTracker = vendorTracker
        self.dailyLimitStore = dailyLimitStore
        self.settings = settings
        let today = calendar.startOfDay(for: Date())
        let initialState = DailyBudget(date: today, dailyLimit: dailyLimit, rollover: .zero).updating(for: [])
        self.budgetState = initialState
        observeChanges()
        Task {
            await loadExpenses()
            // Record initial daily limit for today if not already recorded
            if dailyLimitStore.isEmpty {
                dailyLimitStore.recordDailyLimit(dailyLimit, for: Date())
            }
            do {
                try await vendorTracker.load()
            } catch {
                print("Failed to load vendor tracker: \(error)")
            }
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
        
        // Record vendor usage for smart tracking
        do {
            try await vendorTracker.recordUsage(vendor: vendor, category: category)
        } catch {
            print("Failed to record vendor usage: \(error)")
        }
        
        recalculateBudget()
        await persist()
        
        // Send notification only if you go into deficit spending
        if budgetState.remaining < 0 {
            NotificationManager.shared.sendDeficitAlert(remaining: budgetState.remaining, totalSpent: budgetState.totalSpent)
        }
    }

    func removeExpense(_ expense: Expense) async {
        expenses.removeAll { $0.id == expense.id }
        recalculateBudget()
        await persist()
    }

    func setDailyLimit(_ newLimit: Decimal) {
        let clampedLimit = max(newLimit, 0)
        if clampedLimit != dailyLimit {
            dailyLimit = clampedLimit
            // Record the historical daily limit for today
            dailyLimitStore.recordDailyLimit(clampedLimit, for: Date())
            recalculateBudget()
        }
    }

    func rolloverAmount(for date: Date) -> Decimal {
        guard !dailyLimitStore.isEmpty else { return .zero }
        let previousDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) ?? date
        let previousExpenses = expenses.filter { calendar.isDate($0.date, inSameDayAs: previousDay) }
        let previousTotal = previousExpenses.reduce(Decimal.zero) { $0 + $1.amount }
        let historicalDailyLimit = dailyLimitStore.getDailyLimit(for: previousDay)
        let remaining = historicalDailyLimit - previousTotal
        return max(remaining, .zero)
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
    
    // MARK: - Smart Vendor System
    
    func isKnownVendor(_ vendor: String) async -> Bool {
        return await vendorTracker.isKnownVendor(vendor)
    }
    
    func getCategoryForVendor(_ vendor: String) async -> ExpenseCategory? {
        return await vendorTracker.getCategory(for: vendor)
    }
    
    func getTopVendors(limit: Int = 6) async -> [VendorUsage] {
        return await vendorTracker.getTopVendors(limit: limit)
    }
    
    func addExpenseWithKnownVendor(vendor: String, amount: Decimal) async -> Bool {
        guard let category = await getCategoryForVendor(vendor) else {
            return false
        }
        await addExpense(vendor: vendor, amount: amount, category: category)
        return true
    }

    private func observeChanges() {
        $dailyLimit
            .sink { [weak self] _ in
                self?.recalculateBudget()
            }
            .store(in: &cancellables)

        settings.$budgetPeriod
            .sink { [weak self] _ in
                self?.recalculateBudget()
            }
            .store(in: &cancellables)
    }

    private func recalculateBudget() {
        let today = calendar.startOfDay(for: Date())

        let todayLimit = dailyLimitStore.getDailyLimit(for: today)
        let rollover = rolloverAmount(for: today)
        let dailyBudget = DailyBudget(date: today, dailyLimit: todayLimit, rollover: rollover)
        budgetState = dailyBudget.updating(for: expenses, calendar: calendar)

        let periodRemaining = calculatePeriodRemaining(for: today, period: settings.budgetPeriod)

        if settings.budgetPeriod != .daily {
            budgetState = DailyBudgetState(
                date: today,
                dailyLimit: todayLimit,
                rollover: rollover,
                totalSpent: totalSpent(on: today),
                remaining: periodRemaining / getPeriodDivisor(for: today, period: settings.budgetPeriod)
            )
        }

        weeklyRemaining = periodRemaining
    }

    private func totalSpent(on date: Date) -> Decimal {
        expenses
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private func getPeriodDivisor(for date: Date, period: BudgetPeriod) -> Decimal {
        switch period {
        case .daily:
            return 1
        case .weekly:
            return 7
        case .monthly:
            let calendar = Calendar.current
            let range = calendar.range(of: .day, in: .month, for: date)!
            return Decimal(range.count)
        }
    }
    
    private func calculatePeriodRemaining(for date: Date, period: BudgetPeriod) -> Decimal {
        switch period {
        case .daily:
            let allowance = dailyLimitStore.getDailyLimit(for: date)
            let spent = totalSpent(on: date)
            return allowance - spent
        case .weekly:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return .zero }
            let allowance = totalAllowance(in: interval)
            let spent = totalSpent(in: interval)
            return allowance - spent
        case .monthly:
            guard let interval = calendar.dateInterval(of: .month, for: date) else { return .zero }
            let allowance = totalAllowance(in: interval)
            let spent = totalSpent(in: interval)
            return allowance - spent
        }
    }

    private func totalSpent(in interval: DateInterval) -> Decimal {
        expenses
            .filter { interval.contains($0.date) }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private func totalAllowance(in interval: DateInterval) -> Decimal {
        var total: Decimal = .zero
        var cursor = calendar.startOfDay(for: interval.start)
        let end = calendar.startOfDay(for: interval.end)

        while cursor < end {
            total += dailyLimitStore.getDailyLimit(for: cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return total
    }

    private func persist() async {
        do {
            try await expenseStore.save(expenses)
        } catch {
            print("Failed to save expenses: \(error)")
        }
    }
}
