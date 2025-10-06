import SwiftUI

struct SpendingLimitEditorView: View {
    let initialAmount: Decimal
    let onCancel: () -> Void
    let onSave: (Decimal) -> Void
    
    @State private var amountString: String = ""
    @FocusState private var fieldFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Amount")) {
                    TextField("$0.00", text: $amountString)
                        .keyboardType(.decimalPad)
                        .focused($fieldFocused)
                }
                Section(footer: Text("Enter your spending limit in dollars")) { EmptyView() }
            }
            .navigationTitle("Edit Limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { commit() }.bold()
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Cancel", action: onCancel)
                    Spacer()
                    Button("Save") { commit() }.bold()
                }
            }
            .onAppear {
                amountString = initialAmount.currencyString
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { fieldFocused = true }
            }
        }
    }
    
    private func commit() {
        let sanitized = amountString
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let decimal = Decimal(string: sanitized), decimal >= 0 else { return }
        onSave(decimal)
    }
}

struct SpendingLimitEditorView_Previews: PreviewProvider {
    static var previews: some View {
        SpendingLimitEditorView(initialAmount: 200, onCancel: {}, onSave: { _ in })
    }
}


