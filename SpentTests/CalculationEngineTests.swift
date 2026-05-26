import XCTest
@testable import Spent

final class CalculationEngineTests: XCTestCase {

    // Verify all the receipt formats are correct
    func testFormatCurrency() {
        XCTAssertEqual(CalculationEngine.formatCurrency(10.5), "$10.50")
        XCTAssertEqual(CalculationEngine.formatCurrency(0.0), "$0.00")
        XCTAssertEqual(CalculationEngine.formatCurrency(1234.56), "$1,234.56")
    }

    func testFormatDuration_minutesOnly() {
        XCTAssertEqual(CalculationEngine.formatDuration(minutes: 45), "45m")
    }

    func testFormatDuration_hoursAndMinutes() {
        XCTAssertEqual(CalculationEngine.formatDuration(minutes: 90), "1h 30m")
    }

    func testFormatDuration_exactHour() {
        XCTAssertEqual(CalculationEngine.formatDuration(minutes: 60), "1h 0m")
    }

    func testStudySessions() {
        XCTAssertEqual(CalculationEngine.studySessions(minutes: 135), 3) // 3 × 45 = 135
        XCTAssertEqual(CalculationEngine.studySessions(minutes: 0), 0)
        XCTAssertEqual(CalculationEngine.studySessions(minutes: 44), 0)
        XCTAssertEqual(CalculationEngine.studySessions(minutes: 45), 1)
    }

    func testComputeCost_zeroRate() {
        XCTAssertEqual(CalculationEngine.computeCost(minutes: 120, hourlyRate: 0), 0)
    }

    func testComputeCost_zeroMinutes() {
        XCTAssertEqual(CalculationEngine.computeCost(minutes: 0, hourlyRate: 50), 0)
    }

    func testDeriveHourlyRate_zeroHours() {
        XCTAssertEqual(CalculationEngine.deriveHourlyRate(wage: 1000, hoursPerPeriod: 0), 0)
    }

    func testGPAImpact_zeroUsage() {
        XCTAssertEqual(CalculationEngine.computeGPAImpact(spentMinutes: 0, investedMinutes: 0), 0)
    }

    func testGPAImpact_twoHours() {
        // 2h spent, peer-reviewed coefficient = 0.152
        let impact = CalculationEngine.computeGPAImpact(spentMinutes: 120, investedMinutes: 0)
        XCTAssertEqual(impact, 0.304, accuracy: 0.0001)
    }
}
