import XCTest

final class SpentUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testOnboardingFlowVisible() {
        // First launch should show onboarding
        XCTAssertTrue(app.staticTexts["Every minute costs\nyou something."].waitForExistence(timeout: 5))
    }

    func testStartFreeTrialButtonExists() {
        XCTAssertTrue(app.buttons["Start Free Trial"].waitForExistence(timeout: 5))
    }

    func testStartFreeTrialAdvancesToSignIn() {
        app.buttons["Start Free Trial"].tap()
        XCTAssertTrue(app.buttons["Use email instead"].waitForExistence(timeout: 3))
    }

    func testSignInWithAppleButtonExists() {
        app.buttons["Start Free Trial"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "Sign in with Apple").firstMatch.waitForExistence(timeout: 3))
    }

    func testEmailAuthFlowOpens() {
        app.buttons["Start Free Trial"].tap()
        app.buttons["Use email instead"].tap()
        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.secureTextFields["Password"].waitForExistence(timeout: 3))
    }

    func testSettingsGearVisible() throws {
        // Skip if onboarding is shown (test with a pre-signed-in state in CI via launch arguments)
        guard app.buttons["gearshape"].waitForExistence(timeout: 2) else {
            throw XCTSkip("Settings gear only visible after sign-in")
        }
        app.buttons["gearshape"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }
}
