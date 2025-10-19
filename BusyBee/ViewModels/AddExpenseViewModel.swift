import Foundation
import Combine

@MainActor
final class AddExpenseViewModel: ObservableObject {
    @Published var vendor: String = ""
    @Published var amountString: String = ""
    @Published var category: ExpenseCategory = .food
    @Published var notes: String = ""
    @Published private(set) var isValid: Bool = false

    private var cancellables = Set<AnyCancellable>()

    // Maximum amount allowed for v1.0 - will be parent-configurable in v1.5 Family Edition
    private let maxAmount: Decimal = 999_999.99

    init() {
        Publishers.CombineLatest($vendor, $amountString)
            .map { [weak self] vendor, amount in
                guard let self = self else { return false }
                guard !vendor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let decimal = Decimal(string: amount.filter { !$0.isWhitespace }) else {
                    return false
                }
                return decimal > 0 && decimal <= self.maxAmount
            }
            .assign(to: &$isValid)
    }

    func reset() {
        vendor = ""
        amountString = ""
        category = .food
        notes = ""
    }

    func makeExpense(date: Date = Date()) -> Expense? {
        let trimmedVendor = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedVendor.isEmpty,
              let decimal = Decimal(string: amountString.filter { !$0.isWhitespace }),
              decimal > 0,
              decimal <= maxAmount else {
            return nil
        }
        return Expense(vendor: trimmedVendor, amount: decimal, category: category, date: date, notes: notes)
    }
}
