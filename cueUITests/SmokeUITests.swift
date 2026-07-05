//
//  SmokeUITests.swift
//  cueUITests
//
//  Foundation proof for the hermetic --uitest mode: the app boots straight into
//  an authenticated, seeded session, and the historically-crashing task toggle
//  is exercised without bringing the app down.
//

import XCTest

@MainActor
final class SmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches the app in hermetic UI-test mode (authenticated + seeded, offline).
    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitest"]
        app.launch()
        return app
    }

    func testBootsAuthenticatedIntoTabbedApp() {
        let app = launchedApp()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "should boot past auth into the tab bar")
    }

    func testTogglingATaskDoesNotCrash() {
        let app = launchedApp()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))

        let toggle = app.buttons["task.toggle"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "a seeded task's done toggle should be present on Today")
        toggle.tap()

        // The crash repro: after the toggle, the app must still be alive + responsive.
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after toggling a task")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }
}
