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
        if let spokenDigits = extractSpokenDigitSequence(from: input) {
            return spokenDigits
        }
        if let digitPair = extractDigitPair(from: input) {
            return digitPair
        }
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

    private static func extractDigitPair(from input: String) -> Decimal? {
        let pattern = #"[0-9]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: (input as NSString).length)
        let matches = regex.matches(in: input, options: [], range: range)
        guard !matches.isEmpty else { return nil }

        let tokens = matches.map { (input as NSString).substring(with: $0.range) }
        if tokens.contains(where: { $0.contains(".") }) {
            if let token = tokens.first(where: { $0.contains(".") }), let value = Decimal(string: token) {
                return value
            }
        }

        if let first = tokens.first, tokens.count == 1 {
            return Decimal(string: first)
        }

        guard let dollarsToken = tokens.first, let dollars = Decimal(string: dollarsToken) else { return nil }

        let remaining = tokens.dropFirst().joined()
        guard !remaining.isEmpty else { return dollars }

        var centsToken = remaining
        if centsToken.count == 1, let third = tokens.dropFirst().first(where: { $0.count > 0 }) {
            centsToken += third.prefix(1)
        }
        centsToken = String(centsToken.prefix(2))

        if let cents = Decimal(string: centsToken) {
            return dollars + (cents / Decimal(100))
        }

        return dollars
    }

    private static let onesMap: [String: Int] = [
        "zero": 0, "oh": 0, "one": 1, "two": 2, "three": 3,
        "four": 4, "for": 4, "five": 5, "six": 6, "seven": 7,
        "eight": 8, "nine": 9
    ]

    private static let teensMap: [String: Int] = [
        "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
        "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17,
        "eighteen": 18, "nineteen": 19
    ]

    private static let tensMap: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90
    ]

    private static func extractSpokenDigitSequence(from input: String) -> Decimal? {
        let sanitized = input.lowercased().replacingOccurrences(of: "-", with: " ")
        let separators = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .subtracting(CharacterSet(charactersIn: "."))

        let rawTokens = sanitized.components(separatedBy: separators)
        let tokens = rawTokens
            .map { $0.trimmingCharacters(in: CharacterSet.punctuationCharacters) }
            .filter { !$0.isEmpty }

        var dollarTokens: [String] = []
        var centTokens: [String] = []
        var buffer: [String] = []
        var usingCents = false

        func flushBuffer(to cents: Bool) {
            if cents {
                centTokens.append(contentsOf: buffer)
            } else {
                dollarTokens.append(contentsOf: buffer)
            }
        }

        for token in tokens {
            if ["and", "a", "the"].contains(token) { continue }
            if ["dollar", "dollars", "buck", "bucks"].contains(token) {
                flushBuffer(to: usingCents)
                buffer.removeAll()
                continue
            }
            if ["point", "dot", "decimal"].contains(token) {
                flushBuffer(to: usingCents)
                buffer.removeAll()
                usingCents = true
                continue
            }
            if ["cent", "cents"].contains(token) {
                flushBuffer(to: true)
                buffer.removeAll()
                usingCents = true
                continue
            }

            buffer.append(token)
        }

        flushBuffer(to: usingCents)

        let dollarSegments = numericSegments(from: dollarTokens)
        let centSegments = numericSegments(from: centTokens)

        if !centTokens.isEmpty {
            let dollarsString = dollarSegments.joined()
            let centsString = centSegments.joined()

            let dollarsDecimal = dollarsString.isEmpty ? Decimal.zero : Decimal(string: dollarsString)
            let centsFraction: Decimal
            if centsString.isEmpty {
                centsFraction = .zero
            } else {
                let trimmed = String(centsString.prefix(2))
                centsFraction = (Decimal(string: trimmed) ?? .zero) / Decimal(100)
            }
            return (dollarsDecimal ?? .zero) + centsFraction
        }

        let segments = dollarSegments
        guard !segments.isEmpty else { return nil }

        if segments.count == 1, let value = Decimal(string: segments[0]) {
            return value
        }

        if segments.count >= 3, segments.allSatisfy({ $0.count == 1 }) {
            let combined = segments.joined()
            let dollarsPart = combined.dropLast(2)
            let centsPart = combined.suffix(2)
            let dollarsDecimal = dollarsPart.isEmpty ? Decimal.zero : (Decimal(string: String(dollarsPart)) ?? .zero)
            let centsDecimal = Decimal(string: String(centsPart)) ?? .zero
            return dollarsDecimal + (centsDecimal / Decimal(100))
        }

        let dollarsString = segments.dropLast().joined()
        let centsString = segments.last ?? "0"
        let dollarsDecimal = dollarsString.isEmpty ? Decimal.zero : (Decimal(string: dollarsString) ?? .zero)
        let centsFraction = (Decimal(string: String(centsString.prefix(2))) ?? .zero) / Decimal(100)
        return dollarsDecimal + centsFraction
    }

    private static func numericSegments(from tokens: [String]) -> [String] {
        var segments: [String] = []
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            let cleanedToken = token.trimmingCharacters(in: CharacterSet.punctuationCharacters)
            if cleanedToken.isEmpty {
                index += 1
                continue
            }

            let numericCharacterSet = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))
            if cleanedToken.rangeOfCharacter(from: numericCharacterSet.inverted) == nil {
                segments.append(cleanedToken)
                index += 1
                continue
            }

            if let teen = teensMap[cleanedToken] {
                segments.append(String(teen))
                index += 1
                continue
            }

            if let tens = tensMap[cleanedToken] {
                var value = tens
                var step = 1
                if index + 1 < tokens.count {
                    let nextToken = tokens[index + 1].trimmingCharacters(in: CharacterSet.punctuationCharacters)
                    if let ones = onesMap[nextToken] {
                        value += ones
                        step = 2
                    }
                }
                segments.append(String(value))
                index += step
                continue
            }

            if let ones = onesMap[cleanedToken] {
                segments.append(String(ones))
                index += 1
                continue
            }

            index += 1
        }
        return segments
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
