import Foundation

struct DailyReceipt: Identifiable, Codable {
    var id: UUID
    var date: Date
    var apps: [AppUsage]
    var hourlyRate: Double
    var mode: UserMode

    var spentApps: [AppUsage] { apps.filter { $0.category == .spent } }
    var investedApps: [AppUsage] { apps.filter { $0.category == .invested } }
    var neutralApps: [AppUsage] { apps.filter { $0.category == .neutral } }

    var spentCost: Double {
        spentApps.reduce(0) { $0 + $1.cost(hourlyRate: hourlyRate) }
    }

    var investedCredit: Double {
        investedApps.reduce(0) { $0 + $1.cost(hourlyRate: hourlyRate) }
    }

    var netTotal: Double {
        spentCost - investedCredit
    }

    var isProfitDay: Bool { netTotal <= 0 }

    // Student mode: net spent hours × 0.152 (peer-reviewed)
    var gpaImpact: Double {
        let netSpentMinutes = max(0, spentMinutesTotal - investedMinutesTotal)
        return (Double(netSpentMinutes) / 60.0) * 0.152
    }

    var spentMinutesTotal: Int { spentApps.reduce(0) { $0 + $1.minutes } }
    var investedMinutesTotal: Int { investedApps.reduce(0) { $0 + $1.minutes } }

    static func empty(date: Date = .now, hourlyRate: Double = 0, mode: UserMode = .standard(hourlyRate: 0)) -> DailyReceipt {
        DailyReceipt(id: UUID(), date: date, apps: [], hourlyRate: hourlyRate, mode: mode)
    }
}
