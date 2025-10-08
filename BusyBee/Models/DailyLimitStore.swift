import Foundation
import Combine

@MainActor
class DailyLimitStore: ObservableObject {
    private let key = "dailyLimits"
    private let defaults = UserDefaults.standard

    @Published private(set) var entries: [DailyLimitEntry] = []

    static let shared = DailyLimitStore()

    private init() {
        load()
    }

    func load() {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode([DailyLimitEntry].self, from: data) else {
            entries = []
            return
        }
        self.entries = saved.sorted { $0.date < $1.date }
    }

    func save() {
        let sorted = entries.sorted { $0.date < $1.date }
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        defaults.set(data, forKey: key)
        entries = sorted
    }

    func getDailyLimit(for date: Date) -> Decimal {
        guard !entries.isEmpty else { return 25 }
        let normalizedDate = Calendar.current.startOfDay(for: date)
        if let earliest = earliestEntryDate, normalizedDate < earliest {
            return .zero
        }
        if let match = entries.last(where: { Calendar.current.startOfDay(for: $0.date) <= normalizedDate }) {
            return match.dailyLimit
        }
        return entries.first?.dailyLimit ?? 25
    }

    func recordDailyLimit(_ limit: Decimal, for date: Date) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let entry = DailyLimitEntry(date: normalizedDate, dailyLimit: limit)

        // Remove any existing entry for this date
        entries.removeAll { Calendar.current.startOfDay(for: $0.date) == normalizedDate }

        // Add new entry
        entries.append(entry)
        entries.sort { $0.date < $1.date }
        save()
    }

    func getAllEntries() -> [DailyLimitEntry] {
        return entries
    }

    var earliestEntryDate: Date? {
        entries.map(
            \DailyLimitEntry.date
        ).min()
    }

    var isEmpty: Bool {
        entries.isEmpty
    }
}
