import SwiftUI

struct CustomAmountEntryView: View {
    @Binding var isPresented: Bool
    var initialAmount: Decimal?
    var onConfirm: (Decimal) -> Void

    @State private var input: String = "0"

    private let keypad: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(displayAmount)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 32)

                VStack(spacing: 12) {
                    ForEach(keypad, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(row, id: \.self) { key in
                                Button(action: { handleKey(key) }) {
                                    Text(key)
                                        .font(.system(size: 32, weight: .medium, design: .rounded))
                                        .frame(maxWidth: .infinity, minHeight: 68)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(18)
                                }
                            }
                        }
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)

                    Button("Add Expense") {
                        confirm()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canConfirm ? Color.accentColor : Color.accentColor.opacity(0.2))
                    .foregroundColor(canConfirm ? .white : Color.accentColor)
                    .cornerRadius(16)
                    .disabled(!canConfirm)
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal)
            .navigationTitle("Custom Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            if let initial = initialAmount {
                input = NSDecimalNumber(decimal: initial).stringValue
            }
        }
    }

    private var displayAmount: String {
        if input.isEmpty || input == "." {
            return "$0.00"
        }
        let sanitized = input.hasSuffix(".") ? String(input.dropLast()) : input
        let decimal = Decimal(string: sanitized) ?? .zero
        return decimal.currencyString
    }

    private var canConfirm: Bool {
        guard let decimal = Decimal(string: sanitizedInput) else { return false }
        return decimal > .zero
    }

    private var sanitizedInput: String {
        if input.hasSuffix(".") {
            return String(input.dropLast())
        }
        if input.isEmpty {
            return "0"
        }
        return input
    }

    private func handleKey(_ key: String) {
        switch key {
        case "⌫":
            if !input.isEmpty {
                input.removeLast()
            }
            if input.isEmpty {
                input = "0"
            }
        case ".":
            if !input.contains(".") {
                input.append(key)
            }
        default:
            appendDigit(key)
        }
    }

    private func appendDigit(_ digit: String) {
        if input == "0" && digit != "." {
            input = digit
            return
        }
        if let dotIndex = input.firstIndex(of: ".") {
            let decimals = input[input.index(after: dotIndex)...]
            if decimals.count >= 2 {
                return
            }
        }
        input.append(digit)
    }

    private func confirm() {
        guard let decimal = Decimal(string: sanitizedInput), decimal > .zero else { return }
        onConfirm(decimal)
        isPresented = false
    }
}

struct CustomAmountEntryView_Previews: PreviewProvider {
    static var previews: some View {
        CustomAmountEntryView(isPresented: .constant(true), initialAmount: Decimal(12.5)) { _ in }
    }
}
