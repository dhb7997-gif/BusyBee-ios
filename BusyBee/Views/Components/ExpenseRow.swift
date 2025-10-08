import SwiftUI

struct ExpenseRow: View {
    let expense: Expense
    var onReceiptTapped: ((Expense) -> Void)? = nil
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(expense.vendor)
                        .font(.headline)
                    if expense.hasReceipt {
                        Button(action: { onReceiptTapped?(expense) }) {
                            Image(systemName: "paperclip")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("View receipt"))
                    }
                }
                HStack(spacing: 8) {
                    Text("\(categoryEmoji(for: expense.category)) \(settings.displayName(for: expense.category))")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(categoryColor(for: expense.category))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(categoryColor(for: expense.category).opacity(0.12))
                        .clipShape(Capsule())
                    Text(Self.timeFormatter.string(from: expense.date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(expense.amount.currencyString)
                .font(.headline.weight(.semibold))
                .foregroundColor(.red)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(categoryColor(for: expense.category).opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(categoryColor(for: expense.category).opacity(0.12))
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

private func categoryColor(for category: ExpenseCategory) -> Color {
    switch category {
    case .food: return Color.green
    case .shopping: return Color.purple
    case .transportation: return Color.orange
    case .entertainment: return Color.pink
    case .personal: return Color.teal
    case .other: return Color.gray
    }
}

private func categoryEmoji(for category: ExpenseCategory) -> String {
    switch category {
    case .food: return "🍔"
    case .shopping: return "🛍️"
    case .transportation: return "🚌"
    case .entertainment: return "🎬"
    case .personal: return "🧴"
    case .other: return "🔖"
    }
}

struct ExpenseRow_Previews: PreviewProvider {
    static var previews: some View {
        ExpenseRow(expense: Expense.demoData[0])
            .previewLayout(.sizeThatFits)
            .padding()
            .environmentObject(AppSettings.shared)
    }
}
