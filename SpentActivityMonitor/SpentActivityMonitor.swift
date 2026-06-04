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

    // Fires at the start of each daily interval (midnight). Reset all threshold
    // counters so today's receipt starts from zero.
    //
    // IMPORTANT: iOS also calls this immediately when startMonitoring is invoked
    // while the schedule window is already active (e.g. the user edits their app
    // selection mid-day). Without a per-day guard, that would wipe today's
    // counters every time apps are re-selected, zeroing the receipt. So only
    // reset a group's counters the first time the interval starts on a given
    // calendar day.
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity.rawValue.hasPrefix("tracking-") else { return }
        let groupIndex = Int(activity.rawValue.dropFirst("tracking-".count)) ?? 0

        let today = Self.dayStamp(.now)
        let guardKey = "spent.threshold.resetDay.\(activity.rawValue)"
        if defaults?.string(forKey: guardKey) == today {
            // Already reset this group today — this is a mid-day monitoring
            // restart (app re-selection), not a new day. Preserve existing counts.
            return
        }

        let base = groupIndex * Self.appsPerGroup
        let count = defaults?.integer(forKey: "spent.apps.count") ?? 0
        for i in base..<min(base + Self.appsPerGroup, count) {
            defaults?.removeObject(forKey: "spent.threshold.app\(i)")
        }
        defaults?.set(today, forKey: guardKey)
        defaults?.set(
            ISO8601DateFormatter().string(from: .now),
            forKey: "spent.threshold.resetDate"
        )
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
