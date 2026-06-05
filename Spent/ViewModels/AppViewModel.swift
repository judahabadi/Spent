import Foundation
import SwiftUI
import FamilyControls

@Observable
final class AppViewModel {
    var auth = AuthService()
    var screenTime = ScreenTimeService()
    var cloudKit = CloudKitService()
    var storeKit = StoreKitService()
    var notifications = NotificationService()

    // Current display state
    var todayReceipt: DailyReceipt = .empty()
    var selectedPeriod: ReceiptPeriod = .daily
    var selectedDate: Date = .now
    var streak: StreakRecord = .empty
    var isShowingSettings = false
    var isShowingPaywall = false
    var isShowingAppSelection = false
    var receiptHistory: [DailyReceipt] = []
    var reportRefreshID = UUID()

    // Live update timer + interval-end observer
    private var updateTimer: Timer?
    private var intervalEndObserver: Timer?
    private var isInitializing = false

    // Observable mirror of the persisted tracked-app count so SwiftUI re-renders
    // (e.g. RootView switching away from AppSelectionView) when apps are saved.
    var trackedAppCount: Int = UserDefaults(suiteName: "group.app.spent")?.integer(forKey: "spent.apps.count") ?? 0

    // True when the user hasn't selected any apps to track yet.
    var needsAppSetup: Bool { trackedAppCount == 0 }

    func refreshTrackedAppCount() {
        trackedAppCount = UserDefaults(suiteName: "group.app.spent")?.integer(forKey: "spent.apps.count") ?? 0
    }

    func initialize() async {
        guard !isInitializing else { return }
        isInitializing = true
        defer { isInitializing = false }
        await screenTime.requestAuthorization()
        if auth.isSignedIn {
            if settings.trialStartDate == nil {
                updateSettings { $0.trialStartDate = Date.now }
            }
            streak = await cloudKit.fetchStreak()
            loadHistory()
            await loadTodayReceipt()
            startLiveUpdates()
        }
    }

    var isDegraded: Bool {
        if storeKit.isSubscribed || storeKit.isTrialing { return false }
        guard let trialStart = settings.trialStartDate else { return true }
        let days = Calendar.current.dateComponents([.day], from: trialStart, to: .now).day ?? 0
        return days >= 7
    }

    func loadTodayReceipt() async {
        let receipt = ThresholdDataStore.loadTodayReceipt(settings: settings)
        await MainActor.run {
            self.todayReceipt = receipt ?? .empty(date: .now, hourlyRate: settings.hourlyRate, mode: settings.userMode)
        }
    }

    // Called after the user saves a new app selection so the receipt updates.
    func reloadTrackedApps() {
        refreshTrackedAppCount()
        Task { await loadTodayReceipt() }
    }

    // MARK: - History (backfill)

    private static let historyKey = "spent.history"

    func loadHistory() {
        guard let data = UserDefaults(suiteName: "group.app.spent")?.data(forKey: Self.historyKey),
              let history = try? JSONDecoder().decode([DailyReceipt].self, from: data) else { return }
        receiptHistory = history.sorted { $0.date > $1.date }
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(receiptHistory) else { return }
        UserDefaults(suiteName: "group.app.spent")?.set(data, forKey: Self.historyKey)
    }

    private func receipt(from day: BackfillDay) -> DailyReceipt {
        let apps = day.apps.map { a in
            AppUsage(
                id: UUID(),
                bundleID: a.b,
                displayName: a.n,
                minutes: a.m,
                category: AppCategory(rawValue: a.c) ?? .neutral
            )
        }
        return DailyReceipt(
            id: UUID(),
            date: Date(timeIntervalSince1970: day.date),
            apps: apps,
            hourlyRate: settings.hourlyRate,
            mode: settings.userMode
        )
    }

    /// Reads the data the report extension wrote and merges it into history,
    /// one receipt per day. Returns the number of days imported.
    @discardableResult
    func importBackfill() -> Int {
        guard let days = BackfillStore.loadDays() else { return 0 }
        let imported = days.map { receipt(from: $0) }
        guard !imported.isEmpty else { return 0 }

        let cal = Calendar.current
        func key(_ date: Date) -> Date { cal.startOfDay(for: date) }

        var byDay: [Date: DailyReceipt] = [:]
        for r in receiptHistory { byDay[key(r.date)] = r }
        for r in imported { byDay[key(r.date)] = r } // imported wins

        receiptHistory = byDay.values.sorted { $0.date > $1.date }
        saveHistory()
        return imported.count
    }

    func startLiveUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.loadTodayReceipt()
            }
        }

        // Also reload immediately when SpentActivityMonitor writes a new threshold.
        intervalEndObserver?.invalidate()
        var lastKnownTs = UserDefaults(suiteName: "group.app.spent")?.double(forKey: "spent.threshold.ts") ?? 0
        intervalEndObserver = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            let ts = UserDefaults(suiteName: "group.app.spent")?.double(forKey: "spent.threshold.ts") ?? 0
            guard ts != lastKnownTs else { return }
            lastKnownTs = ts
            Task { @MainActor [weak self] in
                await self?.loadTodayReceipt()
            }
        }
    }

    func recordDayResult() async {
        if todayReceipt.isProfitDay {
            let newMilestones = streak.recordProfitDay(date: .now)
            for milestone in newMilestones {
                notifications.notifyStreakMilestone(milestone)
            }
        } else {
            streak.recordSpentDay()
        }
        await cloudKit.save(receipt: todayReceipt)
        await cloudKit.save(streak: streak)
    }

    var settings: SpentSettings = SpentSettings.load()

    func updateSettings(_ block: (inout SpentSettings) -> Void) {
        block(&settings)
        settings.save()
    }
}

enum ReceiptPeriod: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
}

struct SpentSettings: Codable {
    var wage: Double = 20.0
    var ratePeriod: RatePeriod = .hourly
    var userMode: UserMode = .standard(hourlyRate: 20.0)
    var notificationHour: Int = 20
    var notificationMinute: Int = 0
    var studentSessionMinutes: Int = 45
    var appLockEnabled: Bool = false
    var trialStartDate: Date? = nil

    var hourlyRate: Double {
        switch userMode {
        case .standard(let rate): return rate
        case .student: return 0
        }
    }

    var currentGPA: Double {
        get {
            if case .student(let gpa, _) = userMode { return gpa }
            return 3.5
        }
        set {
            if case .student(_, let scale) = userMode {
                userMode = .student(currentGPA: newValue, scale: scale)
            }
        }
    }

    var gpaScale: GPAScale {
        get {
            if case .student(_, let scale) = userMode { return scale }
            return .deviceDefault
        }
        set {
            if case .student(let gpa, _) = userMode {
                userMode = .student(currentGPA: gpa, scale: newValue)
            }
        }
    }

    private static let key = "spent.settings"
    private static let suite = UserDefaults(suiteName: "group.app.spent")

    static func load() -> SpentSettings {
        guard let data = suite?.data(forKey: key),
              let settings = try? JSONDecoder().decode(SpentSettings.self, from: data) else {
            return SpentSettings()
        }
        return settings
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.suite?.set(data, forKey: Self.key)
    }

    enum RatePeriod: String, Codable, CaseIterable {
        case hourly = "Hourly"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var hours: Double {
            switch self {
            case .hourly: return 1.0
            case .daily: return 8.0
            case .weekly: return 40.0
            case .monthly: return 160.0
            }
        }

        var label: String { rawValue }
    }
}

// Reads threshold data written by SpentActivityMonitor to build today's receipt.
struct ThresholdDataStore {
    private static let groupID = "group.app.spent"

    // Stable per-calendar-day key (yyyy-MM-dd) shared with the monitor extension.
    private static func dayStamp(_ date: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Clears all per-app threshold counters once per calendar day. The main app
    /// owns this reset because DeviceActivity's intervalDidStart callback is
    /// unreliable at midnight and also fires on every monitoring restart (which
    /// must NOT wipe mid-day edits). Both this and the monitor honor the shared
    /// "spent.threshold.resetDay" flag, so whichever runs first claims the day.
    static func resetIfNewDay() {
        let defaults = UserDefaults(suiteName: groupID)
        let today = dayStamp()
        guard defaults?.string(forKey: "spent.threshold.resetDay") != today else { return }
        let count = defaults?.integer(forKey: "spent.apps.count") ?? 0
        // Clear a generous range so stale indices from a larger previous selection
        // are also cleared, not just the current count.
        for i in 0..<max(count, 64) {
            defaults?.removeObject(forKey: "spent.threshold.app\(i)")
        }
        defaults?.set(today, forKey: "spent.threshold.resetDay")
    }

    static func loadTodayReceipt(settings: SpentSettings) -> DailyReceipt? {
        resetIfNewDay()
        let defaults = UserDefaults(suiteName: groupID)
        let count = defaults?.integer(forKey: "spent.apps.count") ?? 0
        guard count > 0 else { return nil }

        // Decode stored names.
        var names: [String] = (0..<count).map { "App \($0 + 1)" }
        if let data = defaults?.data(forKey: "spent.apps.names"),
           let stored = try? JSONDecoder().decode([String].self, from: data) {
            for (i, n) in stored.enumerated() where i < count {
                names[i] = n.isEmpty ? "App \(i + 1)" : n
            }
        }

        // Build an AppUsage entry for EVERY tracked app, not just ones that have
        // crossed the 1-minute threshold today. Otherwise lightly-used apps (and
        // any not yet used today) silently disappear, leaving only heavy-usage
        // social apps — making it look like only social apps were added.
        let apps: [AppUsage] = (0..<count).map { i in
            let minutes = defaults?.integer(forKey: "spent.threshold.app\(i)") ?? 0
            return AppUsage(
                id: UUID(),
                bundleID: "tracked.\(i)",
                displayName: names[i],
                minutes: minutes,
                category: .spent
            )
        }

        return DailyReceipt(
            id: UUID(), date: .now, apps: apps,
            hourlyRate: settings.hourlyRate, mode: settings.userMode
        )
    }
}
