import Foundation
import SwiftUI

struct CategoryTotal: Identifiable, Hashable {
    var id: String { category.id }
    let category: ExpenseCategory
    let amount: Decimal
}

@MainActor
struct MonthlySummaryViewModel {
    let monthInterval: DateInterval
    let filteredExpenses: [Expense]
    let totalSpent: Decimal
    let dailyAverage: Decimal
    let categoryTotals: [CategoryTotal]

    init(expenses: [Expense], for date: Date = Date(), calendar: Calendar = .current) {
        let interval = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
        self.monthInterval = interval
        let filtered = expenses.filter { interval.contains($0.date) }
        self.filteredExpenses = filtered.sorted { $0.date > $1.date }
        let total = filtered.reduce(Decimal.zero) { $0 + $1.amount }
        self.totalSpent = total

        let numberOfDaysInMonth = Decimal(calendar.range(of: .day, in: .month, for: date)?.count ?? 30)
        if numberOfDaysInMonth > 0 {
            self.dailyAverage = total / numberOfDaysInMonth
        } else {
            self.dailyAverage = .zero
        }

        var categoryMap: [ExpenseCategory: Decimal] = [:]
        for expense in filtered {
            categoryMap[expense.category, default: .zero] += expense.amount
        }
        self.categoryTotals = ExpenseCategory.allCases
            .compactMap { category in
                if let amount = categoryMap[category], amount > 0 { return CategoryTotal(category: category, amount: amount) }
                return nil
            }
            .sorted { $0.amount > $1.amount }
    }
}

extension Decimal {
    func rounded(scale: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var result = Decimal()
        var value = self
        NSDecimalRound(&result, &value, scale, mode)
        return result
    }
}


