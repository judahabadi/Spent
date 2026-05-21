import Foundation

struct AppUsage: Identifiable, Codable {
    var id: UUID
    var bundleID: String
    var displayName: String
    var minutes: Int
    var category: AppCategory

    func cost(hourlyRate: Double) -> Double {
        (Double(minutes) / 60.0) * hourlyRate
    }

    var formattedDuration: String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }

    // For student mode: approximately how many 45-min study sessions
    var studySessions: Int { max(0, minutes / 45) }
}

enum AppCategory: String, Codable, CaseIterable {
    case spent = "Spent"
    case invested = "Invested"
    case neutral = "Neutral"
}
