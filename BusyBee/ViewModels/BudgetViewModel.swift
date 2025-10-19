import Foundation
import Combine
import UIKit
import os

@MainActor
final class BudgetViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.caerusfund.busybee", category: "budget")
    @Published private(set) var expenses: [Expense] = []
    @Published var dailyLimit: Decimal
    @Published private(set) var allowanceAmount: Decimal
    @Published private(set) var allowanceStartDate: Date
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
        dailyLimit: Decimal = Decimal(25),
        calendar: Calendar = .current,
        expenseStore: ExpenseStore = ExpenseStore(),
        vendorTracker: VendorTracker = VendorTracker(),
        dailyLimitStore: DailyLimitStore? = nil,
        settings: AppSettings
    ) {
        let resolvedStore = dailyLimitStore ?? DailyLimitStore.shared
        self.dailyLimit = dailyLimit
        self.allowanceAmount = dailyLimit
        self.calendar = calendar
        self.expenseStore = expenseStore
        self.vendorTracker = vendorTracker
        self.dailyLimitStore = resolvedStore
        self.settings = settings
        let today = calendar.startOfDay(for: Date())
        self.allowanceStartDate = today
        let initialState = DailyBudget(date: today, dailyLimit: dailyLimit, rollover: .zero).updating(for: [])
        self.budgetState = initialState
        observeChanges()
        Task {
            await loadExpenses()
            // Record initial daily limit for today if not already recorded
            if resolvedStore.isEmpty {
                resolvedStore.recordDailyLimit(dailyLimit, for: Date())
            }
            allowanceStartDate = calendar.startOfDay(for: Date())
            allowanceAmount = displayAmount(for: settings.budgetPeriod, on: Date())
            do {
                try await vendorTracker.load()
            } catch {
                logger.error("Failed to load vendor tracker: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func loadExpenses() async {
        do {
            let loaded = try await expenseStore.load()
            expenses = loaded.sorted { $0.date > $1.date }
            recalculateBudget()
        } catch {
            logger.error("Failed to load expenses: \(error.localizedDescription, privacy: .public)")
        }
    }

    @discardableResult
    func addExpense(vendor: String, amount: Decimal, category: ExpenseCategory, notes: String? = nil, date: Date = Date()) async -> Expense {
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
            logger.error("Failed to record vendor usage: \(error.localizedDescription, privacy: .public)")
        }

        recalculateBudget()
        await persist()

        // Send notification only if you go into deficit spending
        if budgetState.remaining < 0 {
            NotificationManager.shared.sendDeficitAlert(remaining: budgetState.remaining, totalSpent: budgetState.totalSpent)
        }
        return expense
    }

    @discardableResult
    func attachReceipt(image: UIImage, to expenseID: UUID) async -> Bool {
        do {
            try await ReceiptStorageService.save(image: image, for: expenseID)
            if let index = expenses.firstIndex(where: { $0.id == expenseID }) {
                expenses[index].hasReceipt = true
            }
            await persist()
            return true
        } catch {
            logger.error("Failed to save receipt: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func removeReceipt(for expenseID: UUID) async {
        await ReceiptStorageService.delete(for: expenseID)
        if let index = expenses.firstIndex(where: { $0.id == expenseID }) {
            expenses[index].hasReceipt = false
        }
        await persist()
    }

    func receiptImage(for expenseID: UUID) async -> UIImage? {
        await ReceiptStorageService.load(for: expenseID)
    }

    func removeExpense(_ expense: Expense) async {
        await ReceiptStorageService.delete(for: expense.id)
        expenses.removeAll { $0.id == expense.id }
        recalculateBudget()
        await persist()
    }

    func setDailyLimit(_ newLimit: Decimal) {
        let clampedLimit = max(newLimit, 0)
        let today = calendar.startOfDay(for: Date())
        let perDay = perDayAmount(for: clampedLimit, period: settings.budgetPeriod, date: today)
        dailyLimit = perDay
        allowanceAmount = clampedLimit
        allowanceStartDate = today
        dailyLimitStore.recordDailyLimit(perDay, for: today)
        recalculateBudget()
    }

    func rolloverAmount(for date: Date) -> Decimal {
        let currentDay = calendar.startOfDay(for: date)
        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else { return .zero }
        return endingBalance(for: previousDay)
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
    
    func addExpenseWithKnownVendor(vendor: String, amount: Decimal) async -> Expense? {
        guard let category = await getCategoryForVendor(vendor) else {
            return nil
        }
        return await addExpense(vendor: vendor, amount: amount, category: category)
    }

    private func endingBalance(for date: Date) -> Decimal {
        let targetDay = calendar.startOfDay(for: date)

        // Establish the earliest day we need to evaluate to honor historical rollovers.
        let earliestExpenseDay = expenses.map { calendar.startOfDay(for: $0.date) }.min()
        let earliestLimitDay = dailyLimitStore.earliestEntryDate.map { calendar.startOfDay(for: $0) }
        let candidates = [allowanceStartDate, targetDay, earliestExpenseDay, earliestLimitDay].compactMap { $0 }
        guard let initialDay = candidates.min() else { return .zero }

        var currentDay = initialDay
        var carryOver: Decimal = .zero

        while currentDay <= targetDay {
            let dailyLimit = dailyLimitStore.getDailyLimit(for: currentDay)
            let spent = totalSpent(on: currentDay)
            let ending = dailyLimit + carryOver - spent

            if calendar.isDate(currentDay, inSameDayAs: targetDay) {
                return ending
            }

            carryOver = ending
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = nextDay
        }

        let dailyLimit = dailyLimitStore.getDailyLimit(for: targetDay)
        let spent = totalSpent(on: targetDay)
        return dailyLimit + carryOver - spent
    }

    private func observeChanges() {
        $dailyLimit
            .sink { [weak self] _ in
                self?.recalculateBudget()
            }
            .store(in: &cancellables)

        settings.$budgetPeriod
            .sink { [weak self] newPeriod in
                guard let self else { return }
                let today = self.calendar.startOfDay(for: Date())
                self.allowanceStartDate = today
                self.allowanceAmount = self.displayAmount(for: newPeriod, on: today)
                let perDay = self.perDayAmount(for: self.allowanceAmount, period: newPeriod, date: today)
                self.dailyLimit = perDay
                self.dailyLimitStore.recordDailyLimit(perDay, for: today)
                self.recalculateBudget()
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
            let perDayAllowance = periodAllowanceAverage(for: today, period: settings.budgetPeriod)
            let spentToday = totalSpent(on: today)
            budgetState = DailyBudgetState(
                date: today,
                dailyLimit: perDayAllowance,
                rollover: .zero,
                totalSpent: spentToday,
                remaining: perDayAllowance - spentToday
            )
        }

        weeklyRemaining = periodRemaining
    }

    private func totalSpent(on date: Date) -> Decimal {
        expenses
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private func perDayAmount(for amount: Decimal, period: BudgetPeriod, date: Date) -> Decimal {
        switch period {
        case .daily:
            return amount
        case .weekly:
            return amount / Decimal(7)
        case .monthly:
            let days = getPeriodDivisor(for: date, period: .monthly)
            guard days > 0 else { return .zero }
            return amount / days
        }
    }

    private func displayAmount(for period: BudgetPeriod, on date: Date) -> Decimal {
        let perDay = dailyLimitStore.getDailyLimit(for: date)
        switch period {
        case .daily:
            return perDay
        case .weekly:
            return perDay * Decimal(7)
        case .monthly:
            let days = getPeriodDivisor(for: date, period: .monthly)
            return perDay * days
        }
    }

    private func getPeriodDivisor(for date: Date, period: BudgetPeriod) -> Decimal {
        switch period {
        case .daily:
            return 1
        case .weekly:
            return 7
        case .monthly:
            guard let range = calendar.range(of: .day, in: .month, for: date) else {
                // Fallback to 30 days if calendar range cannot be determined
                return 30
            }
            return Decimal(range.count)
        }
    }

    private func periodAllowanceAverage(for date: Date, period: BudgetPeriod) -> Decimal {
        switch period {
        case .daily:
            return dailyLimitStore.getDailyLimit(for: date)
        case .weekly:
            return perDayAmount(for: allowanceAmount, period: .weekly, date: date)
        case .monthly:
            return perDayAmount(for: allowanceAmount, period: .monthly, date: date)
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
            let startOfToday = calendar.startOfDay(for: date)
            let perDay = perDayAmount(for: allowanceAmount, period: .weekly, date: date)
            let remainingDays = daysRemaining(from: startOfToday, to: interval.end)
            let allowance = perDay * Decimal(remainingDays)
            let effectiveStart = max(allowanceStartDate, startOfToday)
            let spent = totalSpent(from: effectiveStart, to: interval.end)
            return allowance - spent
        case .monthly:
            guard let interval = calendar.dateInterval(of: .month, for: date) else { return .zero }
            let startOfToday = calendar.startOfDay(for: date)
            let perDay = perDayAmount(for: allowanceAmount, period: .monthly, date: date)
            let remainingDays = daysRemaining(from: startOfToday, to: interval.end)
            let allowance = perDay * Decimal(remainingDays)
            let effectiveStart = max(allowanceStartDate, startOfToday)
            let spent = totalSpent(from: effectiveStart, to: interval.end)
            return allowance - spent
        }
    }

    private func totalSpent(from start: Date, to end: Date) -> Decimal {
        let normalizedStart = calendar.startOfDay(for: start)
        return expenses
            .filter { $0.date >= normalizedStart && $0.date < end }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private func daysRemaining(from start: Date, to end: Date) -> Int {
        var count = 0
        var cursor = start
        while cursor < end {
            count += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return count
    }

    private func persist() async {
        do {
            try await expenseStore.save(expenses)
        } catch {
            logger.error("Failed to save expenses: \(error.localizedDescription, privacy: .public)")
        }
    }
}
