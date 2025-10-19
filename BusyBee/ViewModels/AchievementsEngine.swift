import Foundation
import Combine
import os

actor AchievementsStore {
    private let logger = Logger(subsystem: "com.caerusfund.busybee", category: "achievements")
    private let url: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(filename: String = "achievements.json") {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        url = dir.appendingPathComponent(filename)
    }

    func load() async -> [Achievement] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([Achievement].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ achievements: [Achievement]) async {
        do {
            let data = try encoder.encode(achievements)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("Failed to save achievements: \(error.localizedDescription, privacy: .public)")
        }
    }
}

@MainActor
final class AchievementsEngine: ObservableObject {
    @Published private(set) var unlocked: [Achievement] = []
    private let store: AchievementsStore

    init(store: AchievementsStore = AchievementsStore()) {
        self.store = store
    }

    func loadInitial() async {
        let loaded = await store.load()
        self.unlocked = loaded
    }

    func evaluateAndUnlock(metrics: SummaryMetricsViewModel) async -> [Achievement] {
        var newlyUnlocked: [Achievement] = []
        let already = Set(unlocked.map { $0.type })

        if metrics.currentPositiveStreak >= 5 && !already.contains(.fiveDayStreak) {
            newlyUnlocked.append(Achievement(type: .fiveDayStreak))
        }
        if metrics.currentPositiveStreak >= 7 && !already.contains(.sevenDayStreak) {
            newlyUnlocked.append(Achievement(type: .sevenDayStreak))
        }
        if metrics.piggyBankTotal >= 50 && !already.contains(.piggy50) {
            newlyUnlocked.append(Achievement(type: .piggy50))
        }
        if metrics.piggyBankTotal >= 100 && !already.contains(.piggy100) {
            newlyUnlocked.append(Achievement(type: .piggy100))
        }
        // Week Winner: 5 positive days in the last 7
        let last7 = metrics.dayStats.suffix(7)
        let positives = last7.filter { $0.leftover > 0 }.count
        if positives >= 5 && !already.contains(.weekWinner) {
            newlyUnlocked.append(Achievement(type: .weekWinner))
        }

        guard !newlyUnlocked.isEmpty else { return [] }
        unlocked.append(contentsOf: newlyUnlocked)
        await store.save(unlocked)
        return newlyUnlocked
    }
}


