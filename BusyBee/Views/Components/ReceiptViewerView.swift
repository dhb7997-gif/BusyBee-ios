import SwiftUI
import UIKit

struct ReceiptViewerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var budgetViewModel: BudgetViewModel

    let expense: Expense
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.4)
                } else if let image {
                    GeometryReader { geo in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .background(Color.black.opacity(0.9))
                            .edgesIgnoringSafeArea(.bottom)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Receipt not available")
                            .foregroundColor(.secondary)
                        Text("If this expense should have a receipt, try capturing it again.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            .navigationTitle(expense.vendor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete") {
                        Task {
                            await budgetViewModel.removeReceipt(for: expense.id)
                            await MainActor.run {
                                image = nil
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
        .background(Color.black.opacity(0.95).ignoresSafeArea())
        .task(id: expense.id) {
            await MainActor.run {
                isLoading = true
                image = nil
            }
            let loaded = await budgetViewModel.receiptImage(for: expense.id)
            await MainActor.run {
                self.image = loaded
                self.isLoading = false
            }
        }
    }
}

struct ReceiptViewerView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = AppSettings.shared
        let store = DailyLimitStore.shared
        let viewModel = BudgetViewModel(dailyLimitStore: store, settings: settings)
        return ReceiptViewerView(expense: Expense.demoData[0])
            .environmentObject(viewModel)
    }
}
