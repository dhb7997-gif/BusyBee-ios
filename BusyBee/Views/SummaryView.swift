import SwiftUI

struct SummaryView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                    .padding()
                    .background(Color(.systemBackground), in: Circle())
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)

                Text("Summary coming soon")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.secondary)

                Text("Track weekly trends, top categories, and savings streaks here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Summary")
        }
    }
}

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryView()
    }
}
