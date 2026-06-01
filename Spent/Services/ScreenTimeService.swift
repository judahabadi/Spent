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

    // Start 24 hourly monitoring schedules so each completed hour produces a segment
    // in DeviceActivityResults. A single daily schedule only creates a segment at 11:59PM,
    // leaving activitySegments empty for the entire day.
    func startMonitoring() {
        deviceActivityCenter.stopMonitoring([.daily])
        for hour in 0...23 {
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: hour, minute: 0),
                intervalEnd: DateComponents(hour: hour, minute: 59),
                repeats: true
            )
            try? deviceActivityCenter.startMonitoring(
                DeviceActivityName.hour(hour),
                during: schedule
            )
        }
    }

    func stopMonitoring() {
        let names = (0...23).map { DeviceActivityName.hour($0) }
        deviceActivityCenter.stopMonitoring(names)
    }
}

extension DeviceActivityName {
    static let daily = DeviceActivityName("daily")
    static func hour(_ h: Int) -> DeviceActivityName {
        DeviceActivityName("hour-\(String(format: "%02d", h))")
    }
}
