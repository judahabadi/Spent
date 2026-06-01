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

    // DeviceActivityReport only calls makeConfiguration after a monitoring interval
    // COMPLETES. A daily schedule (00:00–23:59) won't complete until 23:59, so the
    // extension never runs during the day. Hourly schedules complete every hour,
    // triggering the extension throughout the day. Apple caps at 20 simultaneous
    // activities, so we monitor hours 0–19 (midnight–8PM). Hours 20–23 are omitted
    // but the report filter still aggregates the day's data correctly.
    func startMonitoring() {
        // Stop any previous schedules (daily or hourly).
        let allNames = (0...23).map { DeviceActivityName.hour($0) } + [.daily]
        deviceActivityCenter.stopMonitoring(allNames)

        var started = 0
        var failed = 0
        for hour in 0...19 {
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: hour, minute: 0),
                intervalEnd: DateComponents(hour: hour, minute: 59),
                repeats: true
            )
            do {
                try deviceActivityCenter.startMonitoring(.hour(hour), during: schedule)
                started += 1
            } catch {
                failed += 1
            }
        }
        let defaults = UserDefaults(suiteName: "group.app.spent")
        defaults?.set("schedules started=\(started) failed=\(failed)", forKey: "spent.monitoring.diagnostics")
        defaults?.set(Date.now.timeIntervalSince1970, forKey: "spent.monitoring.diagnostics.ts")
    }

    func stopMonitoring() {
        let names = (0...23).map { DeviceActivityName.hour($0) } + [.daily]
        deviceActivityCenter.stopMonitoring(names)
    }
}

extension DeviceActivityName {
    static let daily = DeviceActivityName("daily")
    static func hour(_ h: Int) -> DeviceActivityName {
        DeviceActivityName("hour-\(String(format: "%02d", h))")
    }
}
