import SwiftUI

struct PresetAmountsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var editingAmounts: [Decimal] = []
    @State private var newAmountString: String = ""
    @State private var showingAddAmount = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Preset Amounts")) {
                    ForEach(editingAmounts.indices, id: \.self) { index in
                        HStack {
                            Text(editingAmounts[index].currencyString)
                                .font(.headline)
                            Spacer()
                            Button("Remove") {
                                editingAmounts.remove(at: index)
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet.sorted().reversed() {
                            editingAmounts.remove(at: index)
                        }
                    }
                }
                
                Section(header: Text("Add Amount")) {
                    HStack {
                        TextField("Enter amount", text: $newAmountString)
                            .keyboardType(.decimalPad)
                        Button("Add") {
                            addAmount()
                        }
                        .disabled(newAmountString.isEmpty)
                    }
                }
            }
            .navigationTitle("Preset Amounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        editingAmounts = settings.presetAmounts
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("Reset") {
                            editingAmounts = [Decimal(5), Decimal(10), Decimal(15), Decimal(25), Decimal(50)]
                        }
                        Button("Save") {
                            saveAmounts()
                        }
                    }
                }
            }
            .onAppear {
                editingAmounts = settings.presetAmounts
            }
        }
    }
    
    private func addAmount() {
        guard let amount = Decimal(string: newAmountString), amount > 0 else { return }
        editingAmounts.append(amount)
        editingAmounts.sort()
        newAmountString = ""
    }
    
    private func saveAmounts() {
        settings.presetAmounts = editingAmounts
    }
}

struct PresetAmountsView_Previews: PreviewProvider {
    static var previews: some View {
        PresetAmountsView()
    }
}
