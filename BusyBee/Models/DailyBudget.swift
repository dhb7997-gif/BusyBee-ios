import Foundation

struct DailyBudget: Codable, Equatable {
    var date: Date
    var dailyLimit: Decimal
    var rollover: Decimal

    var normalizedDate: Date {
        Calendar.current.startOfDay(for: date)
    }

    var availableToday: Decimal {
        dailyLimit + rollover
    }

    func updating(for expenses: [Expense], calendar: Calendar = .current) -> DailyBudgetState {
        let totalSpent = expenses
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(into: Decimal.zero) { partial, expense in
                partial += expense.amount
            }
        let remaining = availableToday - totalSpent
        return DailyBudgetState(date: normalizedDate, dailyLimit: dailyLimit, rollover: rollover, totalSpent: totalSpent, remaining: remaining)
    }
}

struct DailyBudgetState: Codable, Equatable {
    let date: Date
    let dailyLimit: Decimal
    let rollover: Decimal
    let totalSpent: Decimal
    let remaining: Decimal

    var displayStatus: BudgetStatus {
        switch remaining {
        case let value where value >= dailyLimit * Decimal(0.5):
            return .comfortable
        case let value where value >= 0:
            return .caution
        default:
            return .overLimit
        }
    }
}

enum BudgetStatus: String, Codable {
    case comfortable
    case caution
    case overLimit

    var colorName: String {
        switch self {
        case .comfortable:
            return "Green"
        case .caution:
            return "Yellow"
        case .overLimit:
            return "Red"
        }
    }
}
