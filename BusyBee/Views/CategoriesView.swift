import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var editingNames: [ExpenseCategory: String] = [:]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section(header: Text("Category Names")) {
                ForEach(ExpenseCategory.allCases) { category in
                    LabeledContent {
                        TextField(
                            "Category Name",
                            text: Binding(
                                get: { editingNames[category] ?? settings.displayName(for: category) },
                                set: { editingNames[category] = $0 }
                            )
                        )
                        .multilineTextAlignment(.trailing)
                    } label: {
                        Text(category.defaultTitle)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                Button("Restore Defaults", role: .destructive) {
                    restoreDefaults()
                }
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    loadCurrentNames()
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    save()
                    dismiss()
                }
            }
        }
        .onAppear(perform: loadCurrentNames)
    }
    
    private func loadCurrentNames() {
        editingNames = Dictionary(uniqueKeysWithValues: ExpenseCategory.allCases.map { category in
            (category, settings.displayName(for: category))
        })
    }
    
    private func save() {
        settings.setCategoryNames(editingNames)
    }
    
    private func restoreDefaults() {
        for category in ExpenseCategory.allCases {
            editingNames[category] = category.defaultTitle
        }
    }
}

struct CategoriesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CategoriesView()
                .environmentObject(AppSettings.shared)
        }
    }
}
