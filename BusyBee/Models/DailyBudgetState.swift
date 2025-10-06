import Foundation

// Store historical daily limits to prevent retroactive changes
struct DailyLimitEntry: Codable, Equatable {
    let date: Date
    let dailyLimit: Decimal
}
