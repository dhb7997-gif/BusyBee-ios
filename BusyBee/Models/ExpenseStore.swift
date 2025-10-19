import Foundation

actor ExpenseStore {
    private let storageURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(filename: String = "expenses.json") {
        encoder.outputFormatting = .prettyPrinted
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        storageURL = directory.appendingPathComponent(filename)
    }

    func load() async throws -> [Expense] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return []
        }
        let data = try Data(contentsOf: storageURL)
        return try decoder.decode([Expense].self, from: data)
    }

    func save(_ expenses: [Expense]) async throws {
        let data = try encoder.encode(expenses)
        try data.write(to: storageURL, options: [.atomic, .completeFileProtection])
    }
}
