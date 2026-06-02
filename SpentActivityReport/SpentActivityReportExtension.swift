import DeviceActivity
import SwiftUI

@main
struct SpentActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { config in
            TotalActivityView(configuration: config)
        }
    }
}
