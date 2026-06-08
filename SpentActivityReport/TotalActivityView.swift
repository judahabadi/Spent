import Foundation
import DeviceActivity
import SwiftUI

// MARK: - Context identifier

extension DeviceActivityReport.Context {
    static let totalActivity = Self("totalActivity")
}

// MARK: - Scene

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (ReceiptConfiguration) -> TotalActivityView

    init(@ViewBuilder content: @escaping (ReceiptConfiguration) -> TotalActivityView) {
        self.content = content
    }

    struct ReceiptConfiguration {
        var appUsages: [AppUsage] = []
        var settings: SpentSettings = SpentSettings()
    }

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ReceiptConfiguration {
        // Write proof-of-life BEFORE touching data so we know the process launched
        // even if the async data iteration hangs or the app group is misconfigured.
        let ud = UserDefaults(suiteName: "group.app.spent")
        let n = (ud?.integer(forKey: "spent.diag.calls") ?? 0) + 1
        ud?.set(n, forKey: "spent.diag.calls")
        ud?.set(Date.now.timeIntervalSince1970, forKey: "spent.diag.ts")
        ud?.synchronize()

        // Also write a plain file so the main app can detect the extension ran
        // even if UserDefaults cross-process sync is delayed.
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.spent"
        ) {
            let aliveData = "\(n)|\(Date.now.timeIntervalSince1970)".data(using: .utf8)
            try? aliveData?.write(
                to: containerURL.appendingPathComponent("ext-alive.txt"),
                options: .atomicWrite
            )
        }

        var totals: [String: (displayName: String, minutes: Int)] = [:]

        func accumulate(bundleID: String, displayName: String, duration: TimeInterval) {
            let minutes = Int(duration / 60)
            guard minutes > 0 else { return }
            if let existing = totals[bundleID] {
                totals[bundleID] = (existing.displayName, existing.minutes + minutes)
            } else {
                totals[bundleID] = (displayName, minutes)
            }
        }

        for await activityData in data {
            for await segment in activityData.activitySegments {
                for await categoryActivity in segment.categories {
                    for await appActivity in categoryActivity.applications {
                        let bundleID = appActivity.application.bundleIdentifier ?? "unknown"
                        let name = appActivity.application.localizedDisplayName ?? bundleID
                        accumulate(bundleID: bundleID, displayName: name, duration: appActivity.totalActivityDuration)
                    }
                }
            }
        }

        let settings = SpentSettings.load()
        let appUsages = totals.map { bundleID, info in
            AppUsage(
                id: UUID(),
                bundleID: bundleID,
                displayName: info.displayName,
                minutes: info.minutes,
                category: CategoryClassifier.classify(bundleID: bundleID)
            )
        }

        // Write to App Group container. Two formats for maximum reliability:
        // 1. apps-simple.json — pure primitives, no Codable complexity. Primary read path.
        // 2. today.receipt   — full JSON, secondary fallback.
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.spent"
        ) {
            let simpleApps = appUsages.map {
                SimpleApp(b: $0.bundleID, n: $0.displayName, m: $0.minutes, c: $0.category.rawValue)
            }
            if let simpleData = try? JSONEncoder().encode(simpleApps) {
                try? simpleData.write(
                    to: containerURL.appendingPathComponent("apps-simple.json"),
                    options: .atomicWrite
                )
            }
            let receipt = DailyReceipt(
                id: UUID(), date: Date.now, apps: appUsages,
                hourlyRate: settings.hourlyRate, mode: settings.userMode
            )
            if let receiptData = try? JSONEncoder().encode(receipt) {
                try? receiptData.write(
                    to: containerURL.appendingPathComponent("today.receipt"),
                    options: .atomicWrite
                )
            }
        }

        return ReceiptConfiguration(appUsages: appUsages, settings: settings)
    }
}

// Minimal struct for cross-process transfer — only primitives, no associated-value enums.
private struct SimpleApp: Codable {
    var b: String // bundleID
    var n: String // displayName
    var m: Int    // minutes
    var c: String // category rawValue
}

// MARK: - View

struct TotalActivityView: View {
    let configuration: TotalActivityReport.ReceiptConfiguration

    // DIAGNOSTIC: render a visible bar so we can confirm whether the extension
    // launches at all. If this green bar appears, the report extension ran.
    var body: some View {
        Text("EXT OK · \(configuration.appUsages.count) apps")
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.green)
    }
}

// MARK: - Backfill (historical) report

extension DeviceActivityReport.Context {
    static let backfill = Self("backfill")
}

// Per-day usage harvested from the historical (daily-segmented) filter.
struct BackfillDay: Codable {
    var date: TimeInterval     // start-of-day epoch
    var apps: [BackfillApp]
}

struct BackfillApp: Codable {
    var b: String // bundleID
    var n: String // displayName
    var m: Int    // minutes
    var c: String // category rawValue
}

struct BackfillReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .backfill
    let content: ([BackfillDay]) -> BackfillSummaryView

    init(@ViewBuilder content: @escaping ([BackfillDay]) -> BackfillSummaryView) {
        self.content = content
    }

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> [BackfillDay] {
        let cal = Calendar.current
        // day start-of-day -> bundleID -> (name, minutes)
        var days: [Date: [String: (name: String, minutes: Int)]] = [:]

        for await activityData in data {
            for await segment in activityData.activitySegments {
                let day = cal.startOfDay(for: segment.dateInterval.start)
                for await category in segment.categories {
                    for await app in category.applications {
                        let minutes = Int(app.totalActivityDuration / 60)
                        guard minutes > 0 else { continue }
                        let bundleID = app.application.bundleIdentifier ?? "unknown"
                        let name = app.application.localizedDisplayName ?? bundleID
                        var dayMap = days[day] ?? [:]
                        if let existing = dayMap[bundleID] {
                            dayMap[bundleID] = (existing.name, existing.minutes + minutes)
                        } else {
                            dayMap[bundleID] = (name, minutes)
                        }
                        days[day] = dayMap
                    }
                }
            }
        }

        let result: [BackfillDay] = days.map { day, apps in
            BackfillDay(
                date: day.timeIntervalSince1970,
                apps: apps.map { bundleID, info in
                    BackfillApp(
                        b: bundleID,
                        n: info.name,
                        m: info.minutes,
                        c: CategoryClassifier.classify(bundleID: bundleID).rawValue
                    )
                }
            )
        }.sorted { $0.date < $1.date }

        // Persist for the host app to read back.
        if let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.spent"
        ) {
            if let encoded = try? JSONEncoder().encode(result) {
                try? encoded.write(
                    to: url.appendingPathComponent("backfill.json"),
                    options: .atomicWrite
                )
            }
        }
        UserDefaults(suiteName: "group.app.spent")?
            .set(Date.now.timeIntervalSince1970, forKey: "spent.backfill.ts")

        return result
    }
}

struct BackfillSummaryView: View {
    let days: [BackfillDay]
    var body: some View {
        Text("Imported \(days.count) days")
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blue)
    }
}

// MARK: - Local type mirrors
// These must match the Codable layout of the identically-named types in the main app target.

enum AppCategory: String, Codable, CaseIterable {
    case spent = "Spent"
    case invested = "Invested"
    case neutral = "Neutral"
}

struct AppUsage: Identifiable, Codable {
    var id: UUID
    var bundleID: String
    var displayName: String
    var minutes: Int
    var category: AppCategory
}

struct DailyReceipt: Codable {
    var id: UUID
    var date: Date
    var apps: [AppUsage]
    var hourlyRate: Double
    var mode: UserMode
}

enum GPAScale: Double, Codable, CaseIterable {
    case us = 4.0
    case au = 7.0
    case uk = 100.0
}

enum UserMode: Codable, Equatable {
    case standard(hourlyRate: Double)
    case student(currentGPA: Double, scale: GPAScale)
}

struct SpentSettings: Codable {
    var wage: Double = 20.0
    var ratePeriod: RatePeriod = .hourly
    var userMode: UserMode = .standard(hourlyRate: 20.0)

    var hourlyRate: Double {
        switch userMode {
        case .standard(let rate): return rate
        case .student: return 0
        }
    }

    private static let key = "spent.settings"

    static func load() -> SpentSettings {
        let defaults = UserDefaults(suiteName: "group.app.spent")
        guard let data = defaults?.data(forKey: key),
              let settings = try? JSONDecoder().decode(SpentSettings.self, from: data) else {
            return SpentSettings()
        }
        return settings
    }

    enum RatePeriod: String, Codable, CaseIterable {
        case hourly = "Hourly"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        var hours: Double {
            switch self { case .hourly: 1; case .daily: 8; case .weekly: 40; case .monthly: 160 }
        }
    }
}

// MARK: - CategoryClassifier
// Do NOT use categoryActivity.category.localizedDisplayName — ManagedSettings property,
// crashes for individual (non-family) authorization. Use bundle ID patterns instead.

struct CategoryClassifier: Codable {
    var overrides: [String: AppCategory] = [:]

    static func classify(bundleID: String) -> AppCategory {
        let defaults = UserDefaults(suiteName: "group.app.spent")
        if let data = defaults?.data(forKey: "spent.categoryOverrides"),
           let classifier = try? JSONDecoder().decode(CategoryClassifier.self, from: data),
           let override = classifier.overrides[bundleID] {
            return override
        }
        return heuristic(bundleID: bundleID)
    }

    private static func heuristic(bundleID: String) -> AppCategory {
        let id = bundleID.lowercased()
        let spent = ["facebook", "instagram", "twitter", "snapchat", "tiktok", "bytedance",
                     "reddit", "discord", "telegram", "whatsapp", "messenger",
                     "netflix", "youtube", "hulu", "disneyplus", "twitch", "spotify",
                     "tinder", "bumble", "hinge", "mobilesafari", "chrome", "firefox",
                     "brave", "opera", "duckduckgo", "roblox", "minecraft", "fortnite"]
        let invested = ["notion", "evernote", "todoist", "things", "omnifocus",
                        "slack", "zoom", "msteams", "webex", "duolingo", "khanacademy",
                        "coursera", "udemy", "kindle", "strava", "myfitnesspal",
                        "headspace", "calm", "xcode", "github", "pages", "numbers",
                        "keynote", "word", "excel", "mobilenotes", "reminders",
                        "photoshop", "lightroom"]
        if spent.contains(where: { id.contains($0) }) { return .spent }
        if invested.contains(where: { id.contains($0) }) { return .invested }
        return .neutral
    }
}
