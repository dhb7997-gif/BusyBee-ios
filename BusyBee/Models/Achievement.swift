import Foundation

enum AchievementType: String, Codable, CaseIterable, Identifiable {
    case fiveDayStreak
    case sevenDayStreak
    case piggy50
    case piggy100
    case weekWinner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fiveDayStreak: return "5-Day Streak"
        case .sevenDayStreak: return "7-Day Streak"
        case .piggy50: return "$50 Saved"
        case .piggy100: return "$100 Saved"
        case .weekWinner: return "Week Winner"
        }
    }

    var emoji: String {
        switch self {
        case .fiveDayStreak: return "🔥"
        case .sevenDayStreak: return "⚡️"
        case .piggy50: return "🐷"
        case .piggy100: return "🏆"
        case .weekWinner: return "🥇"
        }
    }
}

struct Achievement: Identifiable, Codable, Hashable {
    let id: UUID
    let type: AchievementType
    let awardedDate: Date

    init(id: UUID = UUID(), type: AchievementType, awardedDate: Date = Date()) {
        self.id = id
        self.type = type
        self.awardedDate = awardedDate
    }
}




