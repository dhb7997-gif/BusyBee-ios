import Foundation

struct VendorUsage: Identifiable, Codable, Sendable {
    var id: UUID
    var vendor: String
    var category: ExpenseCategory
    var usageCount: Int
    var lastUsed: Date
    
    init(id: UUID = UUID(), vendor: String, category: ExpenseCategory, usageCount: Int = 1, lastUsed: Date = Date()) {
        self.id = id
        self.vendor = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
        self.category = category
        self.usageCount = usageCount
        self.lastUsed = lastUsed
    }

    private enum CodingKeys: String, CodingKey {
        case id, vendor, category, usageCount, lastUsed
    }
}

actor VendorTracker {
    private let storageURL: URL
    private var vendorUsages: [String: VendorUsage] = [:]
    
    init(filename: String = "vendor_usage.json") {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        storageURL = directory.appendingPathComponent(filename)
    }
    
    func load() async throws {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return
        }
        let data = try Data(contentsOf: storageURL)
        let decoder = JSONDecoder()
        let usages = try decoder.decode([VendorUsage].self, from: data)
        
        for usage in usages {
            vendorUsages[usage.vendor.lowercased()] = usage
        }
    }
    
    func recordUsage(vendor: String, category: ExpenseCategory) async throws {
        let normalizedVendor = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = normalizedVendor.lowercased()
        
        if let existing = vendorUsages[key] {
            // Update existing vendor
            vendorUsages[key] = await VendorUsage(
                vendor: normalizedVendor,
                category: existing.category, // Keep existing category
                usageCount: existing.usageCount + 1,
                lastUsed: Date()
            )
        } else {
            // Create new vendor entry
            vendorUsages[key] = await VendorUsage(
                vendor: normalizedVendor,
                category: category,
                usageCount: 1,
                lastUsed: Date()
            )
        }
        
        try await save()
    }
    
    func getCategory(for vendor: String) -> ExpenseCategory? {
        let key = vendor.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return vendorUsages[key]?.category
    }
    
    func isKnownVendor(_ vendor: String) -> Bool {
        let key = vendor.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return vendorUsages[key] != nil
    }
    
    func getTopVendors(limit: Int = 6) -> [VendorUsage] {
        return vendorUsages.values
            .sorted { $0.usageCount > $1.usageCount }
            .prefix(limit)
            .map { $0 }
    }
    
    private func save() async throws {
        let usages = Array(vendorUsages.values)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(usages)
        try data.write(to: storageURL, options: [.atomic, .completeFileProtection])
    }
}
