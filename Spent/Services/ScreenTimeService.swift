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

    // Apple docs: "If you present the report in the middle of an active interval,
    // the system calls the extension to provide a report of the activity that has
    // occurred so far during that interval." A single daily schedule keeps one
    // interval permanently active throughout the day, so the extension is called
    // every time the DeviceActivityReport view renders — no need for 20 hourly
    // schedules. Hourly schedules were tried in builds 73-76; the extension never
    // invoked. Single daily schedule is simpler and matches Apple's sample code.
    func startMonitoring() {
        let allNames = (0...23).map { DeviceActivityName.hour($0) } + [.daily]
        deviceActivityCenter.stopMonitoring(allNames)

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let defaults = UserDefaults(suiteName: "group.app.spent")
        do {
            try deviceActivityCenter.startMonitoring(.daily, during: schedule)
            defaults?.set("daily started=1 failed=0", forKey: "spent.monitoring.diagnostics")
        } catch {
            defaults?.set("daily failed: \(error.localizedDescription)", forKey: "spent.monitoring.diagnostics")
        }
        defaults?.set(Date.now.timeIntervalSince1970, forKey: "spent.monitoring.diagnostics.ts")
    }

    func stopMonitoring() {
        let names = (0...23).map { DeviceActivityName.hour($0) } + [.daily]
        deviceActivityCenter.stopMonitoring(names)
    }
}

extension DeviceActivityName {
    static let daily = DeviceActivityName("daily")
    static func hour(_ h: Int) -> DeviceActivityName { DeviceActivityName("hour-\(String(format: "%02d", h))") }
}
