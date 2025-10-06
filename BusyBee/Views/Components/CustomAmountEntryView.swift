import SwiftUI

struct CustomAmountEntryView: View {
    @Binding var isPresented: Bool
    var initialAmount: Decimal?
    var onConfirm: (Decimal) -> Void

    @State private var input: String = "000"

    private let keypad: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["⌫", "0", "C"]
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

                    Button("Vendor/Category") {
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
            .onAppear {
                if let initial = initialAmount {
                    // Convert decimal to right-to-left input (cents)
                    let cents = Int(NSDecimalNumber(decimal: initial * 100).intValue)
                    input = String(format: "%03d", cents)
                }
            }
        }
    }

    private var displayAmount: String {
        if input.isEmpty {
            return "$0.00"
        }
        // Convert right-to-left input to decimal
        let cents = Int(input) ?? 0
        let dollars = Decimal(cents) / 100
        return dollars.currencyString
    }

    private var canConfirm: Bool {
        let cents = Int(input) ?? 0
        return cents > 0
    }

    private func handleKey(_ key: String) {
        switch key {
        case "⌫":
            if input.count > 3 { // Keep at least "000"
                input.removeLast()
            }
        case "C":
            input = "000" // Clear to $0.00
        default:
            appendDigit(key)
        }
    }

    private func appendDigit(_ digit: String) {
        if input.count < 6 { // Limit to $999.99
            input.append(digit)
        }
    }

    private func confirm() {
        let cents = Int(input) ?? 0
        guard cents > 0 else { return }
        let dollars = Decimal(cents) / 100
        onConfirm(dollars)
        isPresented = false
    }
}

struct CustomAmountEntryView_Previews: PreviewProvider {
    static var previews: some View {
        CustomAmountEntryView(isPresented: .constant(true), initialAmount: Decimal(12.5)) { _ in }
    }
}