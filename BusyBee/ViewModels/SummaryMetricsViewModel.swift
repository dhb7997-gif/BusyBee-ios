import Foundation

@MainActor
struct SummaryMetricsViewModel {
    struct DayStat {
        let date: Date
        let allowance: Decimal
        let totalSpent: Decimal
        let leftover: Decimal
    }

    let dayStats: [DayStat]
    let piggyBankTotal: Decimal
    let currentPositiveStreak: Int
    let daysWithCredit: Int
    let successRate: Double
    let averageSaved: Decimal
    let weeklyGoalMet: Bool
    let weeklyStreak: Int
    private let calendar: Calendar

    init(
        expenses: [Expense],
        calendar: Calendar = .current,
        today: Date = Date(),
        limitStore: DailyLimitStore,
        settings: AppSettings
    ) {
        self.calendar = calendar
        let startOfToday = calendar.startOfDay(for: today)
        var spendingByDay: [Date: Decimal] = [:]
        for expense in expenses {
            let day = calendar.startOfDay(for: expense.date)
            spendingByDay[day, default: .zero] += expense.amount
        }

        let earliestExpense = spendingByDay.keys.min()
        let earliestRecord = limitStore.earliestEntryDate.map { calendar.startOfDay(for: $0) }
        let rangeStart = [earliestExpense, earliestRecord].compactMap { $0 }.min() ?? startOfToday

        var stats: [DayStat] = []
        var cursor = rangeStart
        while cursor <= startOfToday {
            let allowanceForDay = limitStore.getDailyLimit(for: cursor)
            let spent = spendingByDay[cursor] ?? .zero
            let leftover = max(.zero, allowanceForDay - spent)
            stats.append(DayStat(date: cursor, allowance: allowanceForDay, totalSpent: spent, leftover: leftover))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        stats.sort { $0.date < $1.date }

        let piggyTotal = stats.reduce(Decimal.zero) { $0 + max(.zero, $1.leftover) }
        let daysElapsed = stats.count
        let daysWithCreditCount = stats.filter { $0.leftover > 0 }.count
        let successRateValue = daysElapsed > 0 ? Double(daysWithCreditCount) / Double(daysElapsed) : 0
        let averageSavedValue = daysElapsed > 0 ? (piggyTotal / Decimal(daysElapsed)) : .zero

        var streak = 0
        for stat in stats.reversed() {
            if stat.leftover > 0 {
                streak += 1
            } else {
                break
            }
        }

        let (weeklyGoal, weeklyStreakCount) = Self.calculateWeeklyMetrics(for: today, period: settings.budgetPeriod, stats: stats, currentStreak: streak, calendar: calendar)

        self.dayStats = stats
        self.piggyBankTotal = piggyTotal
        self.daysWithCredit = daysWithCreditCount
        self.successRate = successRateValue
        self.averageSaved = averageSavedValue
        self.currentPositiveStreak = streak
        self.weeklyGoalMet = weeklyGoal
        self.weeklyStreak = weeklyStreakCount
    }
    
    private static func calculateWeeklyMetrics(for date: Date, period: BudgetPeriod, stats: [DayStat], currentStreak: Int, calendar: Calendar) -> (Bool, Int) {
        switch period {
        case .daily:
            return (currentStreak > 0, currentStreak)
        case .weekly:
            // Check if current week's total is under weekly limit
            let weekStats = stats.filter { stat in
                calendar.isDate(stat.date, equalTo: date, toGranularity: .weekOfYear)
            }
            let weekSpent = weekStats.reduce(Decimal.zero) { $0 + $1.totalSpent }
            let weekAllowance = weekStats.reduce(Decimal.zero) { $0 + $1.allowance }
            let goalMet = weekSpent <= weekAllowance
            
            // Count consecutive weeks where goal was met
            var streak = 0
            var checkDate = date
            while let weekStart = calendar.dateInterval(of: .weekOfYear, for: checkDate)?.start {
                let weekStats = stats.filter { stat in
                    weekStart <= stat.date && stat.date < calendar.date(byAdding: .day, value: 7, to: weekStart) ?? stat.date
                }
                let weekSpent = weekStats.reduce(Decimal.zero) { $0 + $1.totalSpent }
                let weekAllowance = weekStats.reduce(Decimal.zero) { $0 + $1.allowance }

                if !weekStats.isEmpty && weekSpent <= weekAllowance {
                    streak += 1
                    checkDate = calendar.date(byAdding: .weekOfYear, value: -1, to: checkDate) ?? checkDate
                } else {
                    break
                }
            }
            return (goalMet, streak)
        case .monthly:
            let monthStats = stats.filter { stat in
                calendar.isDate(stat.date, equalTo: date, toGranularity: .month)
            }
            let monthSpent = monthStats.reduce(Decimal.zero) { $0 + $1.totalSpent }
            let monthAllowance = monthStats.reduce(Decimal.zero) { $0 + $1.allowance }
            let goalMet = monthSpent <= monthAllowance

            // Count consecutive months where goal was met
            var streak = 0
            var checkDate = date
            while let monthStart = calendar.dateInterval(of: .month, for: checkDate)?.start {
                let monthStats = stats.filter { stat in
                    monthStart <= stat.date && stat.date < calendar.date(byAdding: .month, value: 1, to: monthStart) ?? stat.date
                }
                let monthSpent = monthStats.reduce(Decimal.zero) { $0 + $1.totalSpent }
                let monthAllowance = monthStats.reduce(Decimal.zero) { $0 + $1.allowance }

                if !monthStats.isEmpty && monthSpent <= monthAllowance {
                    streak += 1
                    checkDate = calendar.date(byAdding: .month, value: -1, to: checkDate) ?? checkDate
                } else {
                    break
                }
            }
            return (goalMet, streak)
        }
    }
}
