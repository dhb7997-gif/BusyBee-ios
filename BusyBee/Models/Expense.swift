import Foundation

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case food = "Food"
    case shopping = "Shopping"
    case transportation = "Transportation"
    case entertainment = "Entertainment"
    case personal = "Personal"
    case other = "Other"

    var id: String { rawValue }

    var defaultTitle: String { rawValue }
}

struct Expense: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var vendor: String
    var amount: Decimal
    var category: ExpenseCategory
    var date: Date
    var notes: String?

    init(id: UUID = UUID(), vendor: String, amount: Decimal, category: ExpenseCategory, date: Date = Date(), notes: String? = nil) {
        self.id = id
        self.vendor = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
        self.amount = amount
        self.category = category
        self.date = date
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Expense {
    static let demoData: [Expense] = [
        Expense(vendor: "DoorDash", amount: Decimal(24.75), category: .food),
        Expense(vendor: "Amazon", amount: Decimal(58.43), category: .shopping),
        Expense(vendor: "MTA", amount: Decimal(2.90), category: .transportation)
    ]
}
