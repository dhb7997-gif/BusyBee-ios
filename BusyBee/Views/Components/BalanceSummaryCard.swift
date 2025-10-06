import SwiftUI

struct BalanceSummaryCard: View {
    let state: DailyBudgetState
    let weeklyRemaining: Decimal
    let budgetPeriod: BudgetPeriod

    var body: some View {
        VStack(spacing: 10) {
            Text("Remaining Today")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(state.remaining.currencyString)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)

            ProgressView(value: state.progressValue, total: 1)
                .progressViewStyle(BudgetProgressStyle(status: state.displayStatus))

            // Weekly/Monthly context
            if budgetPeriod != .daily {
                HStack {
                    VStack(alignment: .leading) {
                        Text(budgetPeriod == .weekly ? "Remaining This Week" : "Remaining This Month")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(weeklyRemaining.currencyString)
                            .font(.headline)
                            .foregroundColor(weeklyRemaining >= 0 ? .green : .red)
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spent Today")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(state.totalSpent.currencyString)
                        .font(.subheadline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Daily Limit")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(state.dailyLimit.currencyString)
                        .font(.subheadline)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

private extension DailyBudgetState {
    var progressValue: Double {
        let spent = NSDecimalNumber(decimal: totalSpent).doubleValue
        let total = NSDecimalNumber(decimal: dailyLimit).doubleValue // Use daily limit as the denominator for progress
        guard total > 0 else { return 0 }
        return min(spent / total, 1)
    }
}

struct BalanceSummaryCard_Previews: PreviewProvider {
    static var previews: some View {
        BalanceSummaryCard(
            state: DailyBudgetState(date: Date(), dailyLimit: Decimal(200), rollover: Decimal(0), totalSpent: Decimal(80), remaining: Decimal(20)), // Daily equivalent for weekly mode
            weeklyRemaining: Decimal(150),
            budgetPeriod: .weekly
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
