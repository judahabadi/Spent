import DeviceActivity
import SwiftUI

@main
struct SpentActivityReportExtension: DeviceActivityReportExtension {
    init() {
        // Fires when the extension PROCESS starts — before makeConfiguration.
        // If this timestamp appears but makeConfig calls = 0, the process
        // launches but makeConfiguration is never invoked.
        let ud = UserDefaults(suiteName: "group.app.spent")
        ud?.set(Date.now.timeIntervalSince1970, forKey: "spent.diag.ext.init")
        ud?.synchronize()
    }

    var body: some DeviceActivityReportScene {
        TotalActivityReport { config in
            TotalActivityView(configuration: config)
        }
    }
}
