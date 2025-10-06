import SwiftUI

struct MonthlySummaryView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var showingShare: Bool = false
    @State private var csvURL: URL?

    private var viewModel: MonthlySummaryViewModel {
        MonthlySummaryViewModel(expenses: budgetViewModel.expenses)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                averageCard
                categoryList
                exportButton
            }
            .padding(20)
        }
        .navigationTitle(monthTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShare, onDismiss: { csvURL = nil }) {
            if let url = csvURL {
                ActivityView(activityItems: [url])
            }
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: Date())
    }

    private var header: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("Total Spent")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(viewModel.totalSpent.currencyString)
                .font(.title.weight(.bold))
                .foregroundColor(.red)
        }
        .frame(maxWidth: .infinity)
    }

    private var averageCard: some View {
        VStack(spacing: 8) {
            Text("Daily Average")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(viewModel.dailyAverage.currencyString)
                .font(.title2.weight(.bold))
                .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)
            ForEach(viewModel.categoryTotals) { item in
                HStack {
                    Text(settings.displayName(for: item.category))
                    Spacer()
                    Text(item.amount.currencyString)
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
                .padding(12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var exportButton: some View {
        Button(action: { Task { await exportCSV() } }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Export CSV Report")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.white)
            .background(Color.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func exportCSV() async {
        let url = await CSVExporter.exportMonthly(expenses: viewModel.filteredExpenses)
        csvURL = url
        showingShare = url != nil
    }
}

struct MonthlySummaryView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = AppSettings.shared
        let store = DailyLimitStore.shared
        NavigationView {
            MonthlySummaryView()
                .environmentObject(BudgetViewModel(dailyLimitStore: store, settings: settings))
                .environmentObject(settings)
        }
    }
}
