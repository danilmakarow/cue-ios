//
//  NotificationsReportUITests.swift
//  cueUITests
//
//  Reachability + interaction + crash-safety for the "Notifications & Report"
//  screen (cue/Features/Reports/NotificationsReportView.swift).
//
//  These are hermetic XCUITests over the --uitest launch mode: the app boots
//  straight into the authenticated, seeded, OFFLINE session. Because network
//  sync is disabled in that mode, the screen's cold load may land in any of its
//  phases (loading spinner, the "Couldn't load settings" error/retry state, or
//  the fully-loaded form). Every test is therefore written to be phase-agnostic:
//  it asserts the screen is REACHED via a stable anchor, exercises whatever
//  interactive control that phase exposes, and — the load-bearing assertion —
//  proves the app never terminates (app.state == .runningForeground).
//

import XCTest

@MainActor
final class NotificationsReportUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches the app in hermetic UI-test mode (authenticated + seeded, offline).
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitest"]
        app.launch()
        return app
    }

    /// Drives the tab bar + Settings list to the "Notifications & Report" screen
    /// and returns the app once a screen-level anchor exists. Resilient: taps the
    /// Settings tab, then the "Notifications & report" row, then waits for the
    /// screen's own accessibility identifier (present in every load phase).
    private func navigateToNotificationsReport(_ app: XCUIApplication) {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "app should boot into the tab bar")

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "Settings tab should exist")
        settingsTab.tap()

        // The integrations row that pushes the screen. Matched leniently by its
        // visible label so a copy tweak doesn't break navigation.
        let row = notificationsReportRow(app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the 'Notifications & report' row should be reachable in Settings")
        row.tap()

        let screen = app.otherElements["notificationsReport.screen"]
        XCTAssertTrue(
            screen.waitForExistence(timeout: 10) || notificationsReportTitle(app).waitForExistence(timeout: 5),
            "the Notifications & Report screen should appear"
        )
    }

    /// The Settings row that navigates to this screen, located by its label text.
    private func notificationsReportRow(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Notifications")).firstMatch
    }

    /// The screen's large navigation title — a stable anchor across all phases.
    private func notificationsReportTitle(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts["Notifications & Report"].firstMatch
    }

    // MARK: - Tests

    /// The screen is reachable from Settings and renders without crashing.
    func testScreenIsReachableFromSettings() {
        let app = launch()
        navigateToNotificationsReport(app)

        // Reached if either the screen container or the nav title exists.
        let screen = app.otherElements["notificationsReport.screen"]
        let title = notificationsReportTitle(app)
        XCTAssertTrue(screen.exists || title.exists, "a characteristic element of the screen should exist")

        XCTAssertEqual(app.state, .runningForeground, "app must stay running after reaching the screen")
    }

    /// Whatever load phase appears, the screen exposes an interactive control
    /// (a retry button in the error/loading-failed path, or a switch in the
    /// loaded form) and tapping it must not bring the app down.
    func testPrimaryInteractionDoesNotCrash() {
        let app = launch()
        navigateToNotificationsReport(app)

        // Error/offline path first: a "Retry" action re-runs the cold load.
        let retry = app.buttons["Retry"].firstMatch
        if retry.waitForExistence(timeout: 6) {
            retry.tap()
            XCTAssertEqual(app.state, .runningForeground, "app must stay running after tapping Retry")
        }

        // Loaded path (if reached): the master switch flips optimistically.
        let masterToggle = app.switches.firstMatch
        if masterToggle.waitForExistence(timeout: 6) {
            masterToggle.tap()
            XCTAssertEqual(app.state, .runningForeground, "app must stay running after toggling the daily report")
        }

        // Regardless of phase, the screen anchor must still be alive afterwards.
        let screen = app.otherElements["notificationsReport.screen"]
        XCTAssertTrue(
            screen.exists || notificationsReportTitle(app).exists,
            "the screen should remain present after the interaction"
        )
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// When the form has loaded, the channel segmented control (Push | Telegram)
    /// switches selection without crashing. If the form did not load (offline
    /// error state), the test still proves the screen is alive — the segmented
    /// control simply isn't present and the interaction is skipped.
    func testChannelSegmentedControlSwitchesWithoutCrash() {
        let app = launch()
        navigateToNotificationsReport(app)

        // The two delivery-channel segments are plain buttons labelled by channel.
        let pushSegment = app.buttons["Push"].firstMatch
        let telegramSegment = app.buttons["Telegram"].firstMatch

        if telegramSegment.waitForExistence(timeout: 6) {
            telegramSegment.tap()
            XCTAssertEqual(app.state, .runningForeground, "app must stay running after selecting the Telegram channel")

            if pushSegment.waitForExistence(timeout: 3) {
                pushSegment.tap()
                XCTAssertEqual(app.state, .runningForeground, "app must stay running after selecting the Push channel")
            }
        }

        XCTAssertTrue(
            app.otherElements["notificationsReport.screen"].exists || notificationsReportTitle(app).exists,
            "the screen should remain present after segment interaction"
        )
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Exercises a secondary switch (the brief/recap opt-ins) when the form is
    /// loaded. Any switch on the screen is a valid target; toggling it twice
    /// (on then off) must keep the app alive. Skipped gracefully when the form
    /// did not load offline.
    func testTogglingASwitchKeepsAppAlive() {
        let app = launch()
        navigateToNotificationsReport(app)

        let anySwitch = app.switches.firstMatch
        if anySwitch.waitForExistence(timeout: 6) {
            anySwitch.tap()
            XCTAssertEqual(app.state, .runningForeground, "app must stay running after the first switch tap")

            if anySwitch.isHittable {
                anySwitch.tap()
                XCTAssertEqual(app.state, .runningForeground, "app must stay running after toggling back")
            }
        }

        XCTAssertEqual(app.state, .runningForeground)
    }
}
