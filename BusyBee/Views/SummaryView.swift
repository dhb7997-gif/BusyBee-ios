import SwiftUI

struct SummaryView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @StateObject private var achievements = AchievementsEngine()
    @State private var recentlyUnlocked: [Achievement] = []
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                    Text("Your Progress")
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    let metrics = SummaryMetricsViewModel(
                        expenses: budgetViewModel.expenses,
                        limitStore: DailyLimitStore.shared,
                        settings: settings
                    )
                        ProgressHeader(totalSaved: metrics.piggyBankTotal)

                        GridSummary(metrics: metrics)

                        NavigationLink {
                            MonthlySummaryView()
                                .environmentObject(budgetViewModel)
                        } label: {
                            HStack {
                                Image(systemName: "chart.bar.doc.horizontal.fill")
                                Text("Monthly Summary")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color(.label), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .accessibilityLabel(Text("Open Monthly Summary"))

                        AchievementsPills(achievements: achievements.unlocked)
                    }
                    .padding(20)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Summary")
            .task {
                await achievements.loadInitial()
            }
            .task(id: budgetViewModel.expenses) {
                let metrics = SummaryMetricsViewModel(
                    expenses: budgetViewModel.expenses,
                    limitStore: DailyLimitStore.shared,
                    settings: settings
                )
                let newOnes = await achievements.evaluateAndUnlock(metrics: metrics)
                if !newOnes.isEmpty {
                    recentlyUnlocked = newOnes
                    if settings.effectiveHapticsEnabled { triggerHaptic() }
                }
            }
        }
    }
}

private struct ProgressHeader: View {
    let totalSaved: Decimal
    @State private var animateCoin = false
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 140, height: 140)
                    .shadow(color: .orange.opacity(0.25), radius: 12, x: 0, y: 6)
                VStack(spacing: 6) {
                    Text("🐷")
                        .font(.system(size: 28))
                    Text(totalSaved.currencyString)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                }
                Circle()
                    .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    .frame(width: 22, height: 22)
                    .overlay(Image(systemName: "dollarsign").font(.system(size: 10, weight: .bold)).foregroundColor(.white))
                    .offset(y: animateCoin ? 38 : -60)
                    .opacity(animateCoin ? 0 : 1)
                    .animation(.interpolatingSpring(stiffness: 140, damping: 12).speed(1.1), value: animateCoin)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Piggy bank total"))
        .accessibilityValue(Text(totalSaved.currencyString))
        .onChange(of: totalSaved) { _, _ in
            guard settings.animationsEnabled else { return }
            animateCoin = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                animateCoin = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { animateCoin = false }
            }
        }
    }
}

private struct GridSummary: View {
    let metrics: SummaryMetricsViewModel
    @EnvironmentObject private var settings: AppSettings
    
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                StatCard(title: "Day Streak", value: "\(metrics.currentPositiveStreak)")
                StatCard(title: "Avg Saved", value: metrics.averageSaved.currencyString)
            }
            HStack(spacing: 14) {
                StatCard(title: "This Month", value: "\(metrics.daysWithCredit)")
                let pct = Int((metrics.successRate * 100).rounded())
                StatCard(title: "Success Rate", value: "\(pct)%")
            }
            
            // Weekly/Monthly context
            if settings.budgetPeriod != .daily {
                HStack(spacing: 14) {
                    StatCard(
                        title: "\(settings.budgetPeriod.rawValue) Streak", 
                        value: "\(metrics.weeklyStreak)",
                        color: metrics.weeklyGoalMet ? .green : .orange
                    )
                    StatCard(
                        title: "\(settings.budgetPeriod.rawValue) Goal", 
                        value: metrics.weeklyGoalMet ? "✅ Met" : "❌ Over",
                        color: metrics.weeklyGoalMet ? .green : .red
                    )
                }
            }
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let color: Color?
    
    init(title: String, value: String, color: Color? = nil) {
        self.title = title
        self.value = value
        self.color = color
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(color ?? .primary)
            Text(title)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value))
    }
}

private struct AchievementsPills: View {
    let achievements: [Achievement]
    var body: some View {
        VStack(spacing: 12) {
            Text("Achievements")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            if achievements.isEmpty {
                Text("Keep going to unlock your first badge!")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                let firstSix = Array(achievements.prefix(6))
                ForEach(0..<firstSix.count, id: \.self) { idx in
                    if idx % 3 == 0 {
                        HStack(spacing: 10) {
                            ForEach(idx..<min(idx + 3, firstSix.count), id: \.self) { i in
                                let ach = firstSix[i]
                                Pill(text: "\(ach.type.emoji) \(ach.type.title)")
                            }
                        }
                    }
                }
            }
            NextTargetsRow()
        }
    }
}

private struct NextTargetsRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next Targets")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 10) {
                ProgressPill(text: "🔥 5-Day Streak", progress: 0.6)
                ProgressPill(text: "🐷 $100 Saved", progress: 0.4)
                ProgressPill(text: "🥇 Week Winner", progress: 0.7)
            }
        }
    }
}

private struct ProgressPill: View {
    let text: String
    let progress: Double
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.purple.opacity(0.12))
            GeometryReader { geo in
                Capsule()
                    .fill(Color.purple.opacity(0.35))
                    .frame(width: max(8, geo.size.width * progress))
            }
            Text(text)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(height: 32)
    }
}

private func triggerHaptic() {
    #if os(iOS)
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
    #endif
}

private struct Pill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.purple.opacity(0.15), in: Capsule())
    }
}

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = AppSettings.shared
        let store = DailyLimitStore.shared
        SummaryView()
            .environmentObject(BudgetViewModel(dailyLimitStore: store, settings: settings))
            .environmentObject(settings)
    }
}
