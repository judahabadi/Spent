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
        let defaults = UserDefaults(suiteName: "group.app.spent")

        // Write immediately so we know makeConfiguration was entered, even if it crashes later
        let callCount = (defaults?.integer(forKey: "spent.makeconfig.count") ?? 0) + 1
        defaults?.set(callCount, forKey: "spent.makeconfig.count")
        defaults?.set(Date.now.timeIntervalSince1970, forKey: "spent.makeconfig.ts")
        defaults?.synchronize()

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

        // Write app count so we know if ActivityResults had data
        defaults?.set(totals.count, forKey: "spent.makeconfig.appcount")
        defaults?.synchronize()

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

        let receipt = DailyReceipt(
            id: UUID(),
            date: Date.now,
            apps: appUsages,
            hourlyRate: settings.hourlyRate,
            mode: settings.userMode
        )
        if let encoded = try? JSONEncoder().encode(receipt) {
            // Primary: write to a file in the App Group container.
            // This is more reliable than UserDefaults across processes.
            if let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.app.spent"
            ) {
                let fileURL = containerURL.appendingPathComponent("today.receipt")
                try? encoded.write(to: fileURL, options: .atomicWrite)
            }
            // Fallback: also write via UserDefaults in case file write fails.
            let defaults = UserDefaults(suiteName: "group.app.spent")
            defaults?.set(encoded, forKey: "today.receipt")
            defaults?.synchronize()
        }

        return ReceiptConfiguration(appUsages: appUsages, settings: settings)
    }
}

// MARK: - View

struct TotalActivityView: View {
    let configuration: TotalActivityReport.ReceiptConfiguration

    private var containerStatus: String {
        let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.spent"
        )
        return url != nil ? "AG:OK" : "AG:NIL"
    }

    var body: some View {
        Text("\(containerStatus) \(configuration.appUsages.count)apps")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(containerStatus == "AG:OK" ? .green : .red)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        let defaults = UserDefaults(suiteName: "group.app.spent")
        guard let data = defaults?.data(forKey: "spent.categoryOverrides"),
              let classifier = try? JSONDecoder().decode(CategoryClassifier.self, from: data) else {
            return .neutral
        }
        return classifier.overrides[bundleID] ?? .neutral
    }
}
