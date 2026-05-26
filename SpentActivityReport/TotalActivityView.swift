import Foundation
import DeviceActivity
import Foundation
import SwiftUI
import ManagedSettings

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

        for await activityData in data {
            for await segment in activityData.activitySegments {
                for await categoryActivity in segment.categories {
                    for await appActivity in categoryActivity.applications {
                        let bundleID = appActivity.application.bundleIdentifier ?? "unknown"
                        let displayName = appActivity.application.localizedDisplayName ?? bundleID
                        let minutes = Int(appActivity.totalActivityDuration / 60)
                        guard minutes > 0 else { continue }

                        if let existing = totals[bundleID] {
                            totals[bundleID] = (existing.displayName, existing.minutes + minutes)
                        } else {
                            totals[bundleID] = (displayName, minutes)
                        }
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

        return ReceiptConfiguration(appUsages: appUsages, settings: settings)
    }
}

// MARK: - View

// Rendered off-screen by the system to extract and persist receipt data to the shared App Group.
struct TotalActivityView: View {
    let configuration: TotalActivityReport.ReceiptConfiguration

    var body: some View {
        Color.clear
            .onAppear { persist() }
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
        case hourly, daily, weekly, monthly
        var hours: Double {
            switch self { case .hourly: 1; case .daily: 8; case .weekly: 40; case .monthly: 160 }
        }
    }
}

// MARK: - CategoryClassifier

// Reads per-app category overrides the user set in the main app (stored in the shared App Group).
struct CategoryClassifier {
    static func classify(bundleID: String) -> AppCategory {
        let defaults = UserDefaults(suiteName: "group.app.spent")
        guard let raw = defaults?.string(forKey: "category.\(bundleID)"),
              let category = AppCategory(rawValue: raw) else {
            return .neutral
        }
        return category
    }
}
