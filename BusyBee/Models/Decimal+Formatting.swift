import Foundation

extension Decimal {
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.locale = .current
        return formatter
    }()

    var currencyString: String {
        let number = NSDecimalNumber(decimal: self)
        return Self.currencyFormatter.string(from: number) ?? "-$0.00"
    }
}

struct CSVExporter {
    static func exportMonthly(expenses: [Expense]) async -> URL? {
        let header = "id,vendor,amount,category,date,dayOfWeek,notes\n"
        let rows = expenses.map { expense -> String in
            let id = expense.id.uuidString
            let vendor = escapeCSV(expense.vendor)
            let amount = "\(expense.amount)"
            let category = escapeCSV(expense.category.rawValue)
            let date = ISO8601DateFormatter().string(from: expense.date)
            let dowFormatter = DateFormatter()
            dowFormatter.locale = .current
            dowFormatter.dateFormat = "EEEE"
            let dayOfWeek = escapeCSV(dowFormatter.string(from: expense.date))
            let notes = escapeCSV(expense.notes ?? "")
            return "\(id),\(vendor),\(amount),\(category),\(date),\(dayOfWeek),\(notes)"
        }.joined(separator: "\n")
        let csv = header + rows + "\n"
        guard let data = csv.data(using: .utf8) else { return nil }

        do {
            let tmp = FileManager.default.temporaryDirectory
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            let name = "BusyBee-Expenses-\(formatter.string(from: Date())).csv"
            let url = tmp.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("Failed to write CSV: \(error)")
            return nil
        }
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\n") || value.contains("\"") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
