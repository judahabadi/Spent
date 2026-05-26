import DeviceActivity
import Foundation

private let sharedDefaults = UserDefaults(suiteName: "group.com.spent.app")

struct TotalActivityScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (TotalActivityModel) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async throws -> TotalActivityModel {
        var totalDuration: TimeInterval = 0
        var appItems: [TotalActivityModel.AppItem] = []

        for await activitySegment in data {
            totalDuration += activitySegment.totalActivityDuration
            for await appActivity in activitySegment.applications {
                appItems.append(TotalActivityModel.AppItem(
                    token: appActivity.application,
                    duration: appActivity.totalActivityDuration
                ))
            }
        }

        let stored = sharedDefaults?.double(forKey: "hourlyRate") ?? 0
        let hourlyRate = stored > 0 ? stored : 30.0

        return TotalActivityModel(
            totalDuration: totalDuration,
            hourlyRate: hourlyRate,
            appItems: appItems.sorted { $0.duration > $1.duration }
        )
    }
}
