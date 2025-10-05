import Foundation

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
}
