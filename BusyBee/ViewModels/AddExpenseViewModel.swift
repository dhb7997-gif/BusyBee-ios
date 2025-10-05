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

    init() {
        Publishers.CombineLatest($vendor, $amountString)
            .map { vendor, amount in
                !vendor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Decimal(string: amount.filter { !$0.isWhitespace }) != nil
            }
            .assign(to: &$isValid)
    }

    func reset() {
        vendor = ""
        amountString = ""
        category = .food
        notes = ""
    }

    func makeExpense() -> Expense? {
        let trimmedVendor = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedVendor.isEmpty,
              let decimal = Decimal(string: amountString.filter { !$0.isWhitespace }) else {
            return nil
        }
        return Expense(vendor: trimmedVendor, amount: decimal, category: category, notes: notes)
    }
}
