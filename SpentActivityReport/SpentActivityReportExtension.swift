import DeviceActivity
import SwiftUI

// DeviceActivityReport extension — generates and persists the receipt data
// from raw DeviceActivity usage into the shared App Group container.
@main
struct SpentActivityReportExtension: DeviceActivityReportExtension {
    init() {
        // Written the moment the extension process starts — before makeConfiguration.
        // If this key appears in diagnostics but "running..." never does, the extension
        // launches but crashes inside makeConfiguration.
        let defaults = UserDefaults(suiteName: "group.app.spent")
        defaults?.set(Date.now.timeIntervalSince1970, forKey: "spent.extension.launch.ts")
    }

    var body: some DeviceActivityReportScene {
        TotalActivityReport { config in
            TotalActivityView(configuration: config)
        }
    }
}
