import Foundation
import DeviceActivity

struct TotalActivityModel {
    var totalDuration: TimeInterval
    var hourlyRate: Double
    var appItems: [AppItem]

    var totalCost: Double { (totalDuration / 3600.0) * hourlyRate }

    struct AppItem: Identifiable {
        let id = UUID()
        let token: ApplicationToken
        let duration: TimeInterval

        func cost(hourlyRate: Double) -> Double {
            (duration / 3600.0) * hourlyRate
        }
    }
}
