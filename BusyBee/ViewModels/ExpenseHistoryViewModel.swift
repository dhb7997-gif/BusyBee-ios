import Foundation

enum ExpenseHistoryFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .today: return "☀️"
        case .week: return "📅"
        case .month: return "🗓️"
        }
    }
}

struct ExpenseSection: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let items: [Expense]

    var total: Decimal {
        items.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var formattedDate: String {
        Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

@MainActor
struct ExpenseHistoryViewModel {
    let sections: [ExpenseSection]

    init(expenses: [Expense], calendar: Calendar = .current) {
        let grouped = Dictionary(grouping: expenses) { expense in
            calendar.startOfDay(for: expense.date)
        }
        sections = grouped
            .map { key, value in
                let sorted = value.sorted { $0.date > $1.date }
                return ExpenseSection(date: key, items: sorted)
            }
            .sorted { $0.date > $1.date }
    }

    init(expenses: [Expense], filter: ExpenseHistoryFilter, calendar: Calendar = .current) {
        let now = Date()
        let filtered: [Expense]
        switch filter {
        case .today:
            filtered = expenses.filter { calendar.isDate($0.date, inSameDayAs: now) }
        case .week:
            if let interval = calendar.dateInterval(of: .weekOfYear, for: now) {
                filtered = expenses.filter { interval.contains($0.date) }
            } else {
                filtered = expenses
            }
        case .month:
            if let interval = calendar.dateInterval(of: .month, for: now) {
                filtered = expenses.filter { interval.contains($0.date) }
            } else {
                filtered = expenses
            }
        }

        let grouped = Dictionary(grouping: filtered) { expense in
            calendar.startOfDay(for: expense.date)
        }
        sections = grouped
            .map { key, value in
                let sorted = value.sorted { $0.date > $1.date }
                return ExpenseSection(date: key, items: sorted)
            }
            .sorted { $0.date > $1.date }
    }
}
