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

        // Write to App Group container inside makeConfiguration — the only guaranteed execution
        // point in an extension process. onAppear/onChange on extension views is unreliable.
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.spent"
        ) {
            // Simple format: pure primitives only, no associated-value enums.
            // This is the primary path the main app reads from.
            let simpleApps = appUsages.map {
                SimpleApp(b: $0.bundleID, n: $0.displayName, m: $0.minutes, c: $0.category.rawValue)
            }
            if let simpleData = try? JSONEncoder().encode(simpleApps) {
                try? simpleData.write(
                    to: containerURL.appendingPathComponent("apps-simple.json"),
                    options: .atomicWrite
                )
            }

            // Full receipt JSON as secondary path.
            let receipt = DailyReceipt(
                id: UUID(),
                date: Date.now,
                apps: appUsages,
                hourlyRate: settings.hourlyRate,
                mode: settings.userMode
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

// Simple codable used only for cross-process file transfer. Short keys reduce file size.
private struct SimpleApp: Codable {
    var b: String // bundleID
    var n: String // displayName
    var m: Int    // minutes
    var c: String // category rawValue
}

// MARK: - View

struct TotalActivityView: View {
    let configuration: TotalActivityReport.ReceiptConfiguration

    var body: some View {
        Color.clear
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

struct CategoryClassifier: Codable {
    var overrides: [String: AppCategory] = [:]

    static func classify(bundleID: String) -> AppCategory {
        // User overrides take priority.
        let defaults = UserDefaults(suiteName: "group.app.spent")
        if let data = defaults?.data(forKey: "spent.categoryOverrides"),
           let classifier = try? JSONDecoder().decode(CategoryClassifier.self, from: data),
           let override = classifier.overrides[bundleID] {
            return override
        }
        return heuristic(bundleID: bundleID)
    }

    // Pattern-based classification for common apps.
    // Social/entertainment → Spent; productivity/education/health → Invested.
    private static func heuristic(bundleID: String) -> AppCategory {
        let id = bundleID.lowercased()

        let spentKeywords: [String] = [
            // Social
            "facebook", "instagram", "twitter", "snapchat", "tiktok", "bytedance",
            "reddit", "tumblr", "pinterest", "linkedin", "bereal", "discord",
            "telegram", "whatsapp", "messenger", "signal", "wechat",
            // Entertainment
            "netflix", "youtube", "hulu", "disneyplus", "disney.plus", "hbomax",
            "twitch", "peacocktv", "paramountplus", "appletv",
            "spotify", "applemusic", "soundcloud", "pandora", "deezer",
            "tinder", "bumble", "hinge", "match",
            // Browsers (general surfing)
            "mobilesafari", "chrome", "firefox", "brave", "opera", "duckduckgo",
            // Games (common patterns)
            ".game.", "games.", "gaming", "clash", "candy", "angry", "subway",
            "roblox", "minecraft", "fortnite", "among", "wordle", "nytimes.games",
        ]

        let investedKeywords: [String] = [
            // Productivity
            "notion", "evernote", "bear", "obsidian", "day-one", "dayone",
            "todoist", "things3", "things.", "omnifocus", "ticktick", "habitica",
            "mobilenotes", "reminders",
            "pages", "numbers", "keynote",
            "word", "excel", "powerpoint", "onenote", "office",
            "photoshop", "lightroom", "procreate", "figma", "sketch", "canva",
            // Communication (work)
            "slack", "msteams", "zoom", "webex", "meet", "googlemeet",
            // Education
            "duolingo", "khanacademy", "coursera", "udemy", "edx",
            "quizlet", "anki", "brainscape",
            "kindle", "books", "audible", "libby",
            // Health & fitness
            "health", "fitness", "workout", "gymkit", "strava", "runkeeper",
            "myfitnesspal", "headspace", "calm", "waking", "sleep",
            // Dev / creative tools
            "xcode", "vscode", "github", "jira", "linear", "asana",
            // Finance
            "mint", "ynab", "personalcapital",
        ]

        for kw in spentKeywords where id.contains(kw) { return .spent }
        for kw in investedKeywords where id.contains(kw) { return .invested }
        return .neutral
    }
}
