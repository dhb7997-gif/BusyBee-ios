import Foundation

struct ParsedVoiceExpense {
    var amount: Decimal?
    var vendor: String?
    var category: ExpenseCategory?
}

struct VoiceExpenseParser {
    static func parse(_ input: String, settings: AppSettings) -> ParsedVoiceExpense {
        var result = ParsedVoiceExpense()
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return result }

        result.amount = extractAmount(from: trimmed)
        let vendorAndCategory = extractVendorAndCategory(from: trimmed, settings: settings)
        result.vendor = vendorAndCategory.vendor
        result.category = vendorAndCategory.category ?? detectCategory(in: trimmed, settings: settings)
        if result.category == nil {
            result.category = detectCategory(in: trimmed, settings: settings)
        }
        return result
    }

    private static func extractAmount(from input: String) -> Decimal? {
        if let decimal = extractExplicitDecimal(from: input) {
            return decimal
        }
        if let dollarsAndCents = extractDollarsAndCents(from: input) {
            return dollarsAndCents
        }
        return nil
    }

    private static func extractExplicitDecimal(from input: String) -> Decimal? {
        let pattern = #"\$?\s*([0-9]+(?:\.[0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(location: 0, length: (input as NSString).length)
        let matches = regex.matches(in: input, options: [], range: range)
        guard !matches.isEmpty else { return nil }

        if let decimalMatch = matches.first(where: { match in
            match.numberOfRanges > 1 && (input as NSString).substring(with: match.range(at: 1)).contains(".")
        }) {
            let amountString = (input as NSString).substring(with: decimalMatch.range(at: 1))
            return Decimal(string: amountString)
        }

        guard let match = matches.last, match.numberOfRanges > 1 else { return nil }
        let amountString = (input as NSString).substring(with: match.range(at: 1))
        return Decimal(string: amountString)
    }

    private static func extractDollarsAndCents(from input: String) -> Decimal? {
        let pattern = #"(?i)([0-9]+)\s+(?:dollar|dollars|buck|bucks)(?:[^0-9]+([0-9]{1,2})\s+(?:cent|cents))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: (input as NSString).length)
        guard let match = regex.firstMatch(in: input, options: [], range: range) else { return nil }

        let dollarsString = (input as NSString).substring(with: match.range(at: 1))
        guard let dollars = Decimal(string: dollarsString) else { return nil }

        var cents: Decimal = .zero
        if match.numberOfRanges > 2, match.range(at: 2).location != NSNotFound {
            let centsString = (input as NSString).substring(with: match.range(at: 2))
            if let centsValue = Decimal(string: centsString) {
                cents = centsValue / 100
            }
        }

        return dollars + cents
    }

    private static func extractVendorAndCategory(from input: String, settings: AppSettings) -> (vendor: String?, category: ExpenseCategory?) {
        var vendor: String?
        var category: ExpenseCategory?

        let dashComponents = input.components(separatedBy: " - ")
        if dashComponents.count >= 2 {
            let possibleCategory = dashComponents.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            category = ExpenseCategory.allCases.first(where: { category in
                category.rawValue.caseInsensitiveCompare(possibleCategory) == .orderedSame ||
                settings.displayName(for: category).caseInsensitiveCompare(possibleCategory) == .orderedSame
            })
        }

        if let atRange = input.range(of: " at ", options: [.caseInsensitive, .diacriticInsensitive]) {
            var vendorString = String(input[atRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let dashRange = vendorString.range(of: "-", options: .literal) {
                vendorString = vendorString[..<dashRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            vendor = vendorString.isEmpty ? nil : vendorString
        }

        return (vendor, category)
    }

    private static func detectCategory(in input: String, settings: AppSettings) -> ExpenseCategory? {
        let normalized = input.lowercased()
        for category in ExpenseCategory.allCases {
            let raw = category.rawValue.lowercased()
            if normalized.contains(raw) {
                return category
            }
            let display = settings.displayName(for: category).lowercased()
            if normalized.contains(display) {
                return category
            }
        }
        return nil
    }
}
