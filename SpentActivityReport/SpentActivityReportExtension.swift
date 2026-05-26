import DeviceActivity
import SwiftUI

// DeviceActivityReport extension — generates and persists the receipt data
// from raw DeviceActivity usage into the shared App Group container.
@main
struct SpentActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { context in
            TotalActivityView(context: context)
        }
    }
}
