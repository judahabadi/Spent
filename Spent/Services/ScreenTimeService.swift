import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings

@Observable
final class ScreenTimeService {
    var isAuthorized = false
    var authError: Error?

    private let center = AuthorizationCenter.shared
    private let deviceActivityCenter = DeviceActivityCenter()

    var authorizationStatus: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus

    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            await MainActor.run {
                self.authorizationStatus = self.center.authorizationStatus
                isAuthorized = true
            }
        } catch {
            await MainActor.run {
                self.authorizationStatus = self.center.authorizationStatus
                self.authError = error
                self.isAuthorized = false
            }
        }
    }

    func recheckAuthorization() {
        authorizationStatus = center.authorizationStatus
    }

    // Called once after the user selects apps via FamilyActivityPicker.
    // Creates one DeviceActivityName per group of appsPerGroup apps, each with
    // threshold events at every milestone minute. SpentActivityMonitor records
    // the highest threshold reached per app — that becomes the minute count.
    func setupAppTracking(selection: FamilyActivitySelection, names: [String]) {
        let tokens = Array(selection.applicationTokens)
        guard !tokens.isEmpty else { return }
        let defaults = UserDefaults(suiteName: "group.app.spent")

        // Persist tokens and user-assigned display names.
        if let data = try? JSONEncoder().encode(tokens) {
            defaults?.set(data, forKey: "spent.apps.tokens")
        }
        if let data = try? JSONEncoder().encode(names) {
            defaults?.set(data, forKey: "spent.apps.names")
        }
        defaults?.set(tokens.count, forKey: "spent.apps.count")

        // Stop any existing tracking activities.
        let old = (0..<5).map { DeviceActivityName("tracking-\($0)") }
        deviceActivityCenter.stopMonitoring(old)

        // Minute thresholds: gives ≤12 events per app, 48 per group (under limit).
        let thresholds = [1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120]
        let groupSize = 4
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        var started = 0
        for groupStart in stride(from: 0, to: tokens.count, by: groupSize) {
            let groupIndex = groupStart / groupSize
            var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
            for offset in 0..<groupSize {
                let appIndex = groupStart + offset
                guard appIndex < tokens.count else { break }
                for minutes in thresholds {
                    events[DeviceActivityEvent.Name("app\(appIndex)-\(minutes)")] = DeviceActivityEvent(
                        applications: [tokens[appIndex]],
                        threshold: DateComponents(minute: minutes)
                    )
                }
            }
            let name = DeviceActivityName("tracking-\(groupIndex)")
            if (try? deviceActivityCenter.startMonitoring(name, during: schedule, events: events)) != nil {
                started += 1
            }
        }
        defaults?.set("tracking started=\(started)", forKey: "spent.monitoring.diagnostics")
        defaults?.set(Date.now.timeIntervalSince1970, forKey: "spent.monitoring.diagnostics.ts")
    }

    func stopMonitoring() {
        let names = (0...4).map { DeviceActivityName("tracking-\($0)") } + [.daily]
            + (0...23).map { DeviceActivityName.hour($0) }
        deviceActivityCenter.stopMonitoring(names)
    }
}

extension DeviceActivityName {
    static let daily = DeviceActivityName("daily")
    static func hour(_ h: Int) -> DeviceActivityName { DeviceActivityName("hour-\(String(format: "%02d", h))") }
}
