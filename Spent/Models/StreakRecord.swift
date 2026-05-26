import Foundation

struct StreakRecord: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastProfitDate: Date?
    var milestones: Set<Int>  // days achieved: 7, 14, 30, 60, 100

    static let milestoneThresholds = [7, 14, 30, 60, 100]

    static var empty: StreakRecord {
        StreakRecord(currentStreak: 0, longestStreak: 0, lastProfitDate: nil, milestones: [])
    }

    mutating func recordProfitDay(date: Date) -> [Int] {
        var newMilestones: [Int] = []
        let calendar = Calendar.current

        if let last = lastProfitDate, calendar.isDate(last, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: date)!) {
            currentStreak += 1
        } else {
            currentStreak = 1
        }

        lastProfitDate = date
        longestStreak = max(longestStreak, currentStreak)

        for milestone in Self.milestoneThresholds where currentStreak == milestone && !milestones.contains(milestone) {
            milestones.insert(milestone)
            newMilestones.append(milestone)
        }

        return newMilestones
    }

    mutating func recordSpentDay() {
        currentStreak = 0
    }
}
