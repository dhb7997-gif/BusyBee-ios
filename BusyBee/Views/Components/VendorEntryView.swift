import SwiftUI

struct VendorEntryView: View {
    @Binding var isPresented: Bool
    var initialVendor: String?
    var onSelect: (String) -> Void

    @State private var vendorName: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Vendor")) {
                    TextField("Enter vendor name", text: $vendorName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Choose Vendor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        confirm()
                    }
                    .disabled(vendorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if let initial = initialVendor {
                vendorName = initial
            }
        }
    }

    private func confirm() {
        let trimmed = vendorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSelect(trimmed)
        isPresented = false
    }
}

struct VendorEntryView_Previews: PreviewProvider {
    static var previews: some View {
        VendorEntryView(isPresented: .constant(true), initialVendor: "", onSelect: { _ in })
    }
}
