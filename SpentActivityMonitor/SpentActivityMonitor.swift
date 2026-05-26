import Foundation
import DeviceActivity
import Foundation
import FamilyControls
import ManagedSettings

// Woken by the system at interval boundaries and usage threshold events.
// Writes aggregate usage into the shared App Group container for the main app to read.
final class SpentDeviceActivityMonitor: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()
    private let defaults = UserDefaults(suiteName: "group.app.spent")

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        resetDailyData()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Trigger report generation via shared defaults flag
        defaults?.set(Date(), forKey: "lastIntervalEnd")
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        defaults?.set(Date(), forKey: "lastThresholdReached")
    }

    private func resetDailyData() {
        defaults?.set(Date(), forKey: "dailyResetDate")
    }
}
