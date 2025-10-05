import SwiftUI

struct BalanceSummaryCard: View {
    let state: DailyBudgetState

    var body: some View {
        VStack(spacing: 16) {
            Text("Remaining Today")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(state.remaining.currencyString)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)

            ProgressView(value: state.progressValue, total: 1)
                .progressViewStyle(BudgetProgressStyle(status: state.displayStatus))

            HStack {
                VStack(alignment: .leading) {
                    Text("Spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(state.totalSpent.currencyString)
                        .font(.body)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Daily Limit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(state.dailyLimit.currencyString)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
    }
}

private extension DailyBudgetState {
    var progressValue: Double {
        let spent = NSDecimalNumber(decimal: totalSpent).doubleValue
        let total = NSDecimalNumber(decimal: dailyLimit + rollover).doubleValue
        guard total > 0 else { return 0 }
        return min(spent / total, 1)
    }
}

struct BalanceSummaryCard_Previews: PreviewProvider {
    static var previews: some View {
        BalanceSummaryCard(state: DailyBudgetState(date: Date(), dailyLimit: Decimal(200), rollover: Decimal(25), totalSpent: Decimal(80), remaining: Decimal(145)))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
