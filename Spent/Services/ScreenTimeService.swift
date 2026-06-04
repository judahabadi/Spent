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
        let newTokenSet = selection.applicationTokens
        guard !newTokenSet.isEmpty else { return }
        let defaults = UserDefaults(suiteName: "group.app.spent")

        // Load the previously tracked tokens and the minutes already recorded for
        // each, so re-selecting apps doesn't wipe today's progress for apps the
        // user keeps. (Array(Set) has no stable order, which previously reshuffled
        // indices and reset counters on every re-selection.)
        var oldTokens: [ApplicationToken] = []
        if let data = defaults?.data(forKey: "spent.apps.tokens"),
           let decoded = try? JSONDecoder().decode([ApplicationToken].self, from: data) {
            oldTokens = decoded
        }
        var minutesByToken: [ApplicationToken: Int] = [:]
        for (i, token) in oldTokens.enumerated() {
            let minutes = defaults?.integer(forKey: "spent.threshold.app\(i)") ?? 0
            if minutes > 0 { minutesByToken[token] = minutes }
        }

        // Stable ordering: retained tokens keep their previous relative order,
        // newly added tokens are appended. This keeps indices (and thus recorded
        // minutes) stable for apps that remain selected.
        let retained = oldTokens.filter { newTokenSet.contains($0) }
        let added = newTokenSet.subtracting(oldTokens)
        let tokens = retained + Array(added)

        // Persist tokens, fallback display names, and count.
        if let data = try? JSONEncoder().encode(tokens) {
            defaults?.set(data, forKey: "spent.apps.tokens")
        }
        let finalNames = (0..<tokens.count).map { i in i < names.count ? names[i] : "App \(i + 1)" }
        if let data = try? JSONEncoder().encode(finalNames) {
            defaults?.set(data, forKey: "spent.apps.names")
        }
        defaults?.set(tokens.count, forKey: "spent.apps.count")

        // Persist the full selection so reopening the picker pre-selects current apps.
        if let data = try? JSONEncoder().encode(selection) {
            defaults?.set(data, forKey: "spent.apps.selection")
        }

        // Re-write preserved minutes at each app's (possibly new) index; clear
        // counters for indices with no carried-over value, and any stale indices
        // beyond the new count.
        let maxIndex = max(tokens.count, oldTokens.count)
        for i in 0..<maxIndex {
            if i < tokens.count, let minutes = minutesByToken[tokens[i]] {
                defaults?.set(minutes, forKey: "spent.threshold.app\(i)")
            } else {
                defaults?.removeObject(forKey: "spent.threshold.app\(i)")
            }
        }

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
