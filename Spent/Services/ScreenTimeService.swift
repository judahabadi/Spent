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

    // A single full-day schedule keeps Screen Time recording active for this app.
    // Apple caps monitoring at 20 simultaneous activities, and data segmentation is
    // driven by the report's DeviceActivityFilter — not by the number of schedules —
    // so one schedule is sufficient and stays well under the limit.
    func startMonitoring() {
        // Clean up the legacy 24-hourly schedules from older builds.
        let legacyNames = (0...23).map { DeviceActivityName.hour($0) }
        deviceActivityCenter.stopMonitoring(legacyNames + [.daily])

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let defaults = UserDefaults(suiteName: "group.app.spent")
        do {
            try deviceActivityCenter.startMonitoring(.daily, during: schedule)
            defaults?.set("schedule started ok (daily)", forKey: "spent.monitoring.diagnostics")
        } catch {
            defaults?.set("schedule FAILED: \(error.localizedDescription)", forKey: "spent.monitoring.diagnostics")
        }
        defaults?.set(Date.now.timeIntervalSince1970, forKey: "spent.monitoring.diagnostics.ts")
    }

    func stopMonitoring() {
        let names = (0...23).map { DeviceActivityName.hour($0) }
        deviceActivityCenter.stopMonitoring(names + [.daily])
    }
}

extension DeviceActivityName {
    static let daily = DeviceActivityName("daily")
    static func hour(_ h: Int) -> DeviceActivityName {
        DeviceActivityName("hour-\(String(format: "%02d", h))")
    }
}
