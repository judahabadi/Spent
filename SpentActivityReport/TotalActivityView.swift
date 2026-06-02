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
        // Write immediately so diagnostics shows "running…" if the extension launched
        // but stalls in the loops. If this never appears, the function is never invoked.
        let defaults = UserDefaults(suiteName: "group.app.spent")
        defaults?.set("running...", forKey: "spent.diagnostics")
        defaults?.set(Date.now.timeIntervalSince1970, forKey: "spent.diagnostics.ts")

        var totals: [String: (displayName: String, minutes: Int)] = [:]
        var scheduleCount = 0, segmentCount = 0, categoryCount = 0, appCount = 0

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
            scheduleCount += 1
            for await segment in activityData.activitySegments {
                segmentCount += 1
                for await categoryActivity in segment.categories {
                    categoryCount += 1
                    for await appActivity in categoryActivity.applications {
                        appCount += 1
                        let bundleID = appActivity.application.bundleIdentifier ?? "unknown"
                        let name = appActivity.application.localizedDisplayName ?? bundleID
                        accumulate(bundleID: bundleID, displayName: name, duration: appActivity.totalActivityDuration)
                    }
                }
            }
        }

        defaults?.set("schedules=\(scheduleCount) segments=\(segmentCount) categories=\(categoryCount) apps=\(appCount)", forKey: "spent.diagnostics")
        defaults?.set(Date.now.timeIntervalSince1970, forKey: "spent.diagnostics.ts")

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

        return ReceiptConfiguration(appUsages: appUsages, settings: settings)
    }
}

// MARK: - View

// Renders the extension's output. Made visible so the host app can confirm the
// extension actually launched (independent of the App Group write-back channel).
struct TotalActivityView: View {
    let configuration: TotalActivityReport.ReceiptConfiguration

    private var totalMinutes: Int {
        configuration.appUsages.reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("EXT OK")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
            Text("\(configuration.appUsages.count) apps · \(totalMinutes) min")
                .font(.system(size: 10, design: .monospaced))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { persist() }
        .onChange(of: configuration.appUsages.count) { _, _ in persist() }
    }

    private func persist() {
        let defaults = UserDefaults(suiteName: "group.app.spent")
        let settings = configuration.settings
        let receipt = DailyReceipt(
            id: UUID(),
            date: Date.now,
            apps: configuration.appUsages,
            hourlyRate: settings.hourlyRate,
            mode: settings.userMode
        )
        if let data = try? JSONEncoder().encode(receipt) {
            defaults?.set(data, forKey: "today.receipt")
        }
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

// Reads per-app category overrides the user set in the main app (stored in the shared App Group).
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
