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
    var receiptHistory: [DailyReceipt] = []
    var reportRefreshID = UUID()

    // Live update timer
    private var updateTimer: Timer?

    func initialize() async {
        await screenTime.requestAuthorization()
        if auth.isSignedIn {
            if settings.trialStartDate == nil {
                updateSettings { $0.trialStartDate = Date.now }
            }
            screenTime.startMonitoring()
            streak = await cloudKit.fetchStreak()
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
        // In production: read from DeviceActivity report extension shared container
        // Here: build from cached shared UserDefaults suite
        let cached = SharedDataStore.loadTodayReceipt()
        await MainActor.run {
            self.todayReceipt = cached ?? .empty(date: .now, hourlyRate: settings.hourlyRate, mode: settings.userMode)
        }
    }

    func startLiveUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.reportRefreshID = UUID()
                try? await Task.sleep(for: .seconds(3))
                await self.loadTodayReceipt()
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

    var settings: SpentSettings {
        get { SpentSettings.load() }
        set { newValue.save() }
    }

    func updateSettings(_ block: (inout SpentSettings) -> Void) {
        var s = settings
        block(&s)
        s.save()
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

// Shared data store for app group communication with extensions
struct SharedDataStore {
    private static let suite = UserDefaults(suiteName: "group.app.spent")
    private static let receiptKey = "today.receipt"

    static func loadTodayReceipt() -> DailyReceipt? {
        guard let data = suite?.data(forKey: receiptKey) else { return nil }
        return try? JSONDecoder().decode(DailyReceipt.self, from: data)
    }

    static func saveTodayReceipt(_ receipt: DailyReceipt) {
        guard let data = try? JSONEncoder().encode(receipt) else { return }
        suite?.set(data, forKey: receiptKey)
    }
}
