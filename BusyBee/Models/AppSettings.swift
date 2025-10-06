import Foundation
import Combine
import UIKit

enum BudgetPeriod: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .daily: return "Per Day"
        case .weekly: return "Per Week"
        case .monthly: return "Per Month"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    @Published var animationsEnabled: Bool {
        didSet { defaults.set(animationsEnabled, forKey: Keys.animationsEnabled) }
    }
    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }
    @Published var budgetPeriod: BudgetPeriod {
        didSet { defaults.set(budgetPeriod.rawValue, forKey: Keys.budgetPeriod) }
    }
    @Published var morningReminders: Bool {
        didSet { 
            defaults.set(morningReminders, forKey: Keys.morningReminders)
            NotificationManager.shared.updateMorningReminders(enabled: morningReminders)
        }
    }
    @Published var endOfDaySummary: Bool {
        didSet { 
            defaults.set(endOfDaySummary, forKey: Keys.endOfDaySummary)
            NotificationManager.shared.updateEndOfDaySummary(enabled: endOfDaySummary)
        }
    }
    @Published var receiptStorageEnabled: Bool {
        didSet {
            defaults.set(receiptStorageEnabled, forKey: Keys.receiptStorageEnabled)
        }
    }
    @Published var presetAmounts: [Decimal] {
        didSet { 
            let amounts = presetAmounts.map { $0.description }
            defaults.set(amounts, forKey: Keys.presetAmounts)
        }
    }
    @Published private(set) var categoryDisplayNames: [String: String] = [:] {
        didSet {
            defaults.set(categoryDisplayNames, forKey: Keys.categoryDisplayNames)
        }
    }

    private struct Keys {
        static let animationsEnabled = "animationsEnabled"
        static let hapticsEnabled = "hapticsEnabled"
        static let budgetPeriod = "budgetPeriod"
        static let morningReminders = "morningReminders"
        static let endOfDaySummary = "endOfDaySummary"
        static let receiptStorageEnabled = "receiptStorageEnabled"
        static let presetAmounts = "presetAmounts"
        static let categoryDisplayNames = "categoryDisplayNames"
    }

    private init() {
        let defaultAnimations = defaults.object(forKey: Keys.animationsEnabled) as? Bool ?? true
        let defaultHaptics = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true
        let defaultPeriod = BudgetPeriod(rawValue: defaults.string(forKey: Keys.budgetPeriod) ?? BudgetPeriod.daily.rawValue) ?? .daily
        let defaultMorningReminders = defaults.object(forKey: Keys.morningReminders) as? Bool ?? true
        let defaultEndOfDaySummary = defaults.object(forKey: Keys.endOfDaySummary) as? Bool ?? true
        let defaultReceiptStorage = defaults.object(forKey: Keys.receiptStorageEnabled) as? Bool ?? false

        // Load preset amounts (default: 5, 10, 15, 25, 50)
        let defaultPresetAmounts = [Decimal(5), Decimal(10), Decimal(15), Decimal(25), Decimal(50)]
        let savedAmounts = defaults.stringArray(forKey: Keys.presetAmounts) ?? []
        let presetAmounts = savedAmounts.compactMap { Decimal(string: $0) }.isEmpty ? defaultPresetAmounts : savedAmounts.compactMap { Decimal(string: $0) }
        
        let categoryDisplayNames = defaults.dictionary(forKey: Keys.categoryDisplayNames) as? [String: String] ?? [:]
        
        self.animationsEnabled = defaultAnimations
        self.hapticsEnabled = defaultHaptics
        self.budgetPeriod = defaultPeriod
        self.morningReminders = defaultMorningReminders
        self.endOfDaySummary = defaultEndOfDaySummary
        self.receiptStorageEnabled = defaultReceiptStorage
        self.presetAmounts = presetAmounts
        self.categoryDisplayNames = categoryDisplayNames

        NotificationCenter.default.addObserver(forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.objectWillChange.send()
        }
        NotificationCenter.default.addObserver(forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var effectiveAnimationsEnabled: Bool {
        animationsEnabled && !UIAccessibility.isReduceMotionEnabled
    }

    var effectiveHapticsEnabled: Bool {
        hapticsEnabled // iOS doesn’t expose a system “disable haptics” API; keep toggle-only
    }
}

extension AppSettings {
    func displayName(for category: ExpenseCategory) -> String {
        let key = category.rawValue
        return categoryDisplayNames[key] ?? category.defaultTitle
    }

    func setCategoryNames(_ names: [ExpenseCategory: String]) {
        var overrides: [String: String] = [:]
        for category in ExpenseCategory.allCases {
            let key = category.rawValue
            let trimmed = names[category]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? category.defaultTitle
            let resolved = trimmed.isEmpty ? category.defaultTitle : trimmed
            if resolved != category.defaultTitle {
                overrides[key] = resolved
            }
        }
        categoryDisplayNames = overrides
    }

    func resetCategoryNames() {
        categoryDisplayNames = [:]
    }
}
