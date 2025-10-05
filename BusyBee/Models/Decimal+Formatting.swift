import Foundation

extension Decimal {
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.locale = .current
        return formatter
    }()

    var currencyString: String {
        let number = NSDecimalNumber(decimal: self)
        return Self.currencyFormatter.string(from: number) ?? "-$0.00"
    }
}
