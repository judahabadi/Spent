import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings

// Woken by the system at interval boundaries and usage threshold events.
// Event name format: "app<N>-<minutes>" where N is the app's index in the
// stored token array. Writes the highest reached threshold per app into the
// shared App Group so the main app can build the receipt without needing the
// DeviceActivityReport extension.
final class SpentDeviceActivityMonitor: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()
    private let defaults = UserDefaults(suiteName: "group.app.spent")

    // Fires at the start of each daily interval (midnight). Clears all threshold
    // counters so today's receipt starts from zero.
    //
    // iOS ALSO calls this immediately when startMonitoring is invoked while the
    // schedule window is already active (e.g. the user edits their app selection
    // mid-day). To avoid wiping today's progress on every such restart, the reset
    // is gated by a shared, once-per-calendar-day flag ("spent.threshold.resetDay")
    // that the main app sets too. We only clear when that flag is not yet today.
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity.rawValue.hasPrefix("tracking-") else { return }

        let today = Self.dayStamp(.now)
        guard defaults?.string(forKey: "spent.threshold.resetDay") != today else {
            // Already reset today (by the app or an earlier callback). This is a
            // mid-day monitoring restart, not a new day — keep existing counts.
            return
        }

        let count = defaults?.integer(forKey: "spent.apps.count") ?? 0
        for i in 0..<count {
            defaults?.removeObject(forKey: "spent.threshold.app\(i)")
        }
        defaults?.set(today, forKey: "spent.threshold.resetDay")
    }

    // Stable per-calendar-day key (yyyy-MM-dd) used to guard daily resets.
    private static func dayStamp(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        defaults?.set(Date(), forKey: "lastIntervalEnd")
    }

    // Event name: "app<N>-<minutes>". Record the highest threshold seen per app
    // so the main app can read it as approximate minutes used today.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        let raw = event.rawValue
        let parts = raw.components(separatedBy: "-")
        guard parts.count == 2,
              parts[0].hasPrefix("app"),
              let appIndex = Int(parts[0].dropFirst(3)),
              let minutes = Int(parts[1]) else { return }
        let key = "spent.threshold.app\(appIndex)"
        let current = defaults?.integer(forKey: key) ?? 0
        if minutes > current {
            defaults?.set(minutes, forKey: key)
        }
        defaults?.set(Date().timeIntervalSince1970, forKey: "spent.threshold.ts")
    }

    static let appsPerGroup = 4
}
