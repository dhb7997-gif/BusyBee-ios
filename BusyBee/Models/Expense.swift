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
    var hasReceipt: Bool

    init(id: UUID = UUID(), vendor: String, amount: Decimal, category: ExpenseCategory, date: Date = Date(), notes: String? = nil, hasReceipt: Bool = false) {
        self.id = id
        self.vendor = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
        self.amount = amount
        self.category = category
        self.date = date
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hasReceipt = hasReceipt
    }

    enum CodingKeys: String, CodingKey {
        case id, vendor, amount, category, date, notes, hasReceipt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        vendor = try container.decode(String.self, forKey: .vendor)
        amount = try container.decode(Decimal.self, forKey: .amount)
        category = try container.decode(ExpenseCategory.self, forKey: .category)
        date = try container.decode(Date.self, forKey: .date)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        hasReceipt = try container.decodeIfPresent(Bool.self, forKey: .hasReceipt) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(vendor, forKey: .vendor)
        try container.encode(amount, forKey: .amount)
        try container.encode(category, forKey: .category)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(hasReceipt, forKey: .hasReceipt)
    }
}

extension Expense {
    static let demoData: [Expense] = [
        Expense(vendor: "DoorDash", amount: Decimal(24.75), category: .food),
        Expense(vendor: "Amazon", amount: Decimal(58.43), category: .shopping),
        Expense(vendor: "MTA", amount: Decimal(2.90), category: .transportation)
    ]
}
