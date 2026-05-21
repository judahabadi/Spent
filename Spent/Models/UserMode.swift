import Foundation

enum GPAScale: Double, Codable, CaseIterable {
    case us = 4.0     // United States
    case au = 7.0     // Australia
    case uk = 100.0   // UK percentage

    var label: String {
        switch self {
        case .us: return "4.0 Scale"
        case .au: return "7.0 Scale"
        case .uk: return "100 Scale"
        }
    }

    static var deviceDefault: GPAScale {
        let region = Locale.current.region?.identifier ?? "US"
        switch region {
        case "AU": return .au
        case "GB": return .uk
        default: return .us
        }
    }
}

enum RatePeriod: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"

    var hours: Double {
        switch self {
        case .daily: return 8.0
        case .weekly: return 40.0
        case .monthly: return 160.0
        case .yearly: return 2080.0
        }
    }
}

enum UserMode: Codable, Equatable {
    case standard(hourlyRate: Double)
    case student(currentGPA: Double, scale: GPAScale)

    var isStudent: Bool {
        if case .student = self { return true }
        return false
    }

    var hourlyRate: Double {
        if case .standard(let rate) = self { return rate }
        return 0
    }

    static func deriveHourlyRate(wage: Double, period: RatePeriod) -> Double {
        guard period.hours > 0 else { return 0 }
        return wage / period.hours
    }
}
