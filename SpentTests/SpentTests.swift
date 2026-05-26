import XCTest
@testable import Spent

final class SpentTests: XCTestCase {

    func testCalculationEngine_standardMode() {
        let cost = CalculationEngine.computeCost(minutes: 60, hourlyRate: 20.0)
        XCTAssertEqual(cost, 20.0, accuracy: 0.001)
    }

    func testCalculationEngine_partialHour() {
        let cost = CalculationEngine.computeCost(minutes: 30, hourlyRate: 20.0)
        XCTAssertEqual(cost, 10.0, accuracy: 0.001)
    }

    func testCalculationEngine_netTotal_profit() {
        let net = CalculationEngine.computeNetTotal(spentMinutes: 30, investedMinutes: 60, hourlyRate: 20.0)
        XCTAssertLessThan(net, 0, "Investing more than spending should yield a negative (profit) net total")
    }

    func testCalculationEngine_netTotal_loss() {
        let net = CalculationEngine.computeNetTotal(spentMinutes: 60, investedMinutes: 0, hourlyRate: 20.0)
        XCTAssertGreaterThan(net, 0)
        XCTAssertEqual(net, 20.0, accuracy: 0.001)
    }

    func testCalculationEngine_gpaImpact() {
        // 2h spent, 0h invested → 2 * 0.152 = 0.304
        let impact = CalculationEngine.computeGPAImpact(spentMinutes: 120, investedMinutes: 0)
        XCTAssertEqual(impact, 0.304, accuracy: 0.001)
    }

    func testCalculationEngine_gpaImpact_noNegative() {
        // Invested > Spent should clamp to 0
        let impact = CalculationEngine.computeGPAImpact(spentMinutes: 30, investedMinutes: 60)
        XCTAssertEqual(impact, 0.0, accuracy: 0.001)
    }

    func testDailyReceipt_isProfitDay() {
        let invested = AppUsage(id: UUID(), bundleID: "com.example.notes", displayName: "Notes", minutes: 60, category: .invested)
        let spent = AppUsage(id: UUID(), bundleID: "com.example.instagram", displayName: "Instagram", minutes: 30, category: .spent)
        let receipt = DailyReceipt(id: UUID(), date: .now, apps: [invested, spent], hourlyRate: 20.0, mode: .standard(hourlyRate: 20.0))
        XCTAssertTrue(receipt.isProfitDay)
    }

    func testDailyReceipt_isNotProfitDay() {
        let spent = AppUsage(id: UUID(), bundleID: "com.example.instagram", displayName: "Instagram", minutes: 60, category: .spent)
        let receipt = DailyReceipt(id: UUID(), date: .now, apps: [spent], hourlyRate: 20.0, mode: .standard(hourlyRate: 20.0))
        XCTAssertFalse(receipt.isProfitDay)
    }

    func testStreakRecord_consecutiveDays() {
        var streak = StreakRecord.empty
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        _ = streak.recordProfitDay(date: yesterday)
        let milestones = streak.recordProfitDay(date: today)
        XCTAssertEqual(streak.currentStreak, 2)
        XCTAssertTrue(milestones.isEmpty)
    }

    func testStreakRecord_brokenStreak() {
        var streak = StreakRecord.empty
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        _ = streak.recordProfitDay(date: threeDaysAgo)
        _ = streak.recordProfitDay(date: Date())
        XCTAssertEqual(streak.currentStreak, 1, "Non-consecutive days should reset streak to 1")
    }

    func testCategoryClassifier_defaults() {
        let classifier = CategoryClassifier()
        XCTAssertEqual(classifier.classify(bundleID: "com.facebook.Instagram", appleCategory: "Social Networking"), .spent)
        XCTAssertEqual(classifier.classify(bundleID: "com.apple.Keynote", appleCategory: "Productivity"), .invested)
        XCTAssertEqual(classifier.classify(bundleID: "com.weather.app", appleCategory: "Weather"), .neutral)
    }

    func testCategoryClassifier_userOverride() {
        var classifier = CategoryClassifier()
        classifier.overrides["com.custom.app"] = .invested
        XCTAssertEqual(classifier.classify(bundleID: "com.custom.app", appleCategory: "Social Networking"), .invested)
    }

    func testHourlyRateDerivation() {
        let rate = CalculationEngine.deriveHourlyRate(wage: 160.0, hoursPerPeriod: 8.0)
        XCTAssertEqual(rate, 20.0, accuracy: 0.001)
    }
}
