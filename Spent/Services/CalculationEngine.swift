import Foundation

@Observable
final class CalculationEngine {

    // Standard mode cost calculation
    static func computeCost(minutes: Int, hourlyRate: Double) -> Double {
        (Double(minutes) / 60.0) * hourlyRate
    }

    // Net total (can be negative = profit)
    static func computeNetTotal(spentMinutes: Int, investedMinutes: Int, hourlyRate: Double) -> Double {
        let spent = computeCost(minutes: spentMinutes, hourlyRate: hourlyRate)
        let invested = computeCost(minutes: investedMinutes, hourlyRate: hourlyRate)
        return spent - invested
    }

    // Student mode GPA impact
    static func computeGPAImpact(spentMinutes: Int, investedMinutes: Int) -> Double {
        let netSpentMinutes = max(0, spentMinutes - investedMinutes)
        return (Double(netSpentMinutes) / 60.0) * 0.152
    }

    // Derive hourly rate from wage + period
    static func deriveHourlyRate(wage: Double, hoursPerPeriod: Double) -> Double {
        guard hoursPerPeriod > 0 else { return 0 }
        return wage / hoursPerPeriod
    }

    // Format currency
    static func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: abs(amount))) ?? "$0.00"
    }

    // Format duration
    static func formatDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }

    // Study sessions (45 min each)
    static func studySessions(minutes: Int) -> Int {
        max(0, minutes / 45)
    }
}
