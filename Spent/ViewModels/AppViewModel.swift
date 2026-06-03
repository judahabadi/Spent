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
    private var isInitializing = false

    func initialize() async {
        guard !isInitializing else { return }
        isInitializing = true
        defer { isInitializing = false }
        await screenTime.requestAuthorization()
        if auth.isSignedIn {
            if settings.trialStartDate == nil {
                updateSettings { $0.trialStartDate = Date.now }
            }
            screenTime.startMonitoring()
            streak = await cloudKit.fetchStreak()
            await loadTodayReceipt()
            startLiveUpdates()
            // DeviceActivityReport renders after initialize() returns and triggers the
            // extension asynchronously. Poll at increasing intervals so the receipt
            // populates within seconds rather than waiting for the 30-second timer.
            Task {
                for delay: Double in [4, 10, 20] {
                    try? await Task.sleep(for: .seconds(delay))
                    await loadTodayReceipt()
                    if !self.todayReceipt.apps.isEmpty { break }
                }
            }
        }
    }

    var isDegraded: Bool {
        if storeKit.isSubscribed || storeKit.isTrialing { return false }
        guard let trialStart = settings.trialStartDate else { return true }
        let days = Calendar.current.dateComponents([.day], from: trialStart, to: .now).day ?? 0
        return days >= 7
    }

    var receiptLoadStatus: String = "not loaded"

    func loadTodayReceipt() async {
        let cached = SharedDataStore.loadTodayReceipt()
        await MainActor.run {
            self.receiptLoadStatus = SharedDataStore.lastLoadStatus
            self.todayReceipt = cached ?? .empty(date: .now, hourlyRate: settings.hourlyRate, mode: settings.userMode)
        }
    }

    func startLiveUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.reportRefreshID = UUID()      // forces DeviceActivityReport re-render → extension re-runs
                try? await Task.sleep(for: .seconds(8))   // wait for extension to finish writing
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

// Shared data store for app group communication with extensions
struct SharedDataStore {
    private static let suite = UserDefaults(suiteName: "group.app.spent")
    private static let groupID = "group.app.spent"

    // Last diagnostic from loadTodayReceipt — shown in Settings for debugging.
    static var lastLoadStatus: String = "not loaded"

    static func loadTodayReceipt() -> DailyReceipt? {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupID
        )

        // Primary: simple flat format written by the extension in makeConfiguration.
        // Uses only String/Int — no associated-value enum Codable issues possible.
        if let containerURL {
            let simpleURL = containerURL.appendingPathComponent("apps-simple.json")
            if let data = try? Data(contentsOf: simpleURL) {
                struct SimpleApp: Codable { var b: String; var n: String; var m: Int; var c: String }
                if let simpleApps = try? JSONDecoder().decode([SimpleApp].self, from: data),
                   !simpleApps.isEmpty {
                    let settings = SpentSettings.load()
                    let apps = simpleApps.map { app in
                        AppUsage(
                            id: UUID(),
                            bundleID: app.b,
                            displayName: app.n,
                            minutes: app.m,
                            category: AppCategory(rawValue: app.c) ?? .neutral
                        )
                    }
                    lastLoadStatus = "ok:\(apps.count)apps"
                    return DailyReceipt(
                        id: UUID(),
                        date: .now,
                        apps: apps,
                        hourlyRate: settings.hourlyRate,
                        mode: settings.userMode
                    )
                } else {
                    lastLoadStatus = "simple-parse-fail(\(data.count)b)"
                }
            } else {
                lastLoadStatus = "no-file"
            }
        } else {
            lastLoadStatus = "container-nil"
        }

        // Secondary: full receipt JSON.
        if let containerURL {
            let fileURL = containerURL.appendingPathComponent("today.receipt")
            if let data = try? Data(contentsOf: fileURL) {
                do {
                    let receipt = try JSONDecoder().decode(DailyReceipt.self, from: data)
                    lastLoadStatus = "full-ok:\(receipt.apps.count)apps"
                    return receipt
                } catch {
                    lastLoadStatus = "full-err:\(error)"
                }
            }
        }

        return nil
    }
}
