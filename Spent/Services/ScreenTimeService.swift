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

    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            await MainActor.run { isAuthorized = true }
        } catch {
            await MainActor.run {
                self.authError = error
                self.isAuthorized = false
            }
        }
    }

    var authorizationStatus: AuthorizationStatus {
        center.authorizationStatus
    }

    // Start monitoring to populate DeviceActivity data
    func startMonitoring() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        do {
            try deviceActivityCenter.startMonitoring(.daily, during: schedule)
        } catch {
            // Already monitoring or not authorized — handled gracefully
        }
    }

    func stopMonitoring() {
        deviceActivityCenter.stopMonitoring([.daily])
    }
}

extension DeviceActivityName {
    static let daily = DeviceActivityName("daily")
}
