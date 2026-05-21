import DeviceActivity
import SwiftUI
import ManagedSettings

// Rendered by the system inside the DeviceActivityReport extension.
// Converts raw activity context into AppUsage records and persists them
// to the shared App Group for the main app to read.
struct TotalActivityView: View {
    let context: DeviceActivityReport.Context

    var body: some View {
        // This view is rendered off-screen by the system to extract data.
        // The actual display is handled by the main app's ReceiptView.
        Color.clear
            .onAppear { persist(context: context) }
    }

    private func persist(context: DeviceActivityReport.Context) {
        let defaults = UserDefaults(suiteName: "group.app.spent")
        let categories = CategoryClassifier.load()

        var appUsages: [AppUsage] = []

        for (token, activity) in context.totalActivityDuration {
            guard let duration = activity.duration else { continue }
            let minutes = Int(duration / 60)
            guard minutes > 0 else { continue }

            let bundleID = token.bundleIdentifier ?? "unknown"
            let displayName = token.localizedDisplayName ?? bundleID

            let category = categories.classify(bundleID: bundleID, appleCategory: token.localizedCategories.first)
            let usage = AppUsage(
                id: UUID(),
                bundleID: bundleID,
                displayName: displayName,
                minutes: minutes,
                category: category
            )
            appUsages.append(usage)
        }

        // Filter out idle/background (< 1 min already filtered above)
        let settings = SpentSettings.load()
        let receipt = DailyReceipt(
            id: UUID(),
            date: .now,
            apps: appUsages,
            hourlyRate: settings.hourlyRate,
            mode: settings.userMode
        )

        if let data = try? JSONEncoder().encode(receipt) {
            defaults?.set(data, forKey: "today.receipt")
        }
    }
}

// Minimal SpentSettings mirror for the extension (shared model)
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
