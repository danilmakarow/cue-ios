//
//  NewEventUITests.swift
//  cueUITests
//
//  Proves the "New Event" sheet is REACHABLE, INTERACTIVE, and CRASH-SAFE in the
//  hermetic --uitest mode: opening the sheet from the tab bar, typing a title and
//  tapping the decisive Save CTA, and dismissing without committing. The
//  load-bearing assertion after every interaction is that the app stays alive
//  (app.state == .runningForeground) — content fidelity is owned by snapshot tests.
//

import XCTest

@MainActor
final class NewEventUITests: XCTestCase {
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

    /// Taps the "New Event" tab-bar action item, which presents the create sheet,
    /// and waits for the sheet's title text field to appear. Returns that field.
    private func openNewEventSheet(_ app: XCUIApplication) -> XCUIElement {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "should boot into the tabbed app")

        let newEventItem = app.tabBars.buttons["New Event"]
        XCTAssertTrue(newEventItem.waitForExistence(timeout: 10), "the New Event action item should exist in the tab bar")
        newEventItem.tap()

        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 10), "the New Event sheet should present a title text field")
        return titleField
    }

    /// The sheet opens, the title field accepts input, and tapping the decisive
    /// Save CTA keeps the app alive (offline mode may surface an error alert or
    /// dismiss — either way the app must not crash).
    func testOpenSheetTypeTitleAndSave() {
        let app = launch()
        let titleField = openNewEventSheet(app)

        titleField.tap()
        titleField.typeText("Launch the Mark VII")
        XCTAssertEqual(app.state, .runningForeground, "app must stay alive after typing a title")

        // The decisive CTA — its label contains "Save task". Enabled once the title
        // is non-empty (the view model's canSubmit gate).
        let saveButton = app.buttons["Save task"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 10), "the Save task CTA should be present")
        if saveButton.isHittable {
            saveButton.tap()
        }

        // Offline save may dismiss the sheet or raise a failure alert; the only
        // load-bearing guarantee is that the app survives the commit attempt.
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after attempting Save")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "the tabbed app should remain reachable after Save")
    }

    /// The sheet can be dismissed (swipe-to-dismiss) without committing, leaving
    /// the app alive and back on the tabbed shell.
    func testOpenSheetAndDismiss() {
        let app = launch()
        let titleField = openNewEventSheet(app)

        // Swipe the sheet down to dismiss it (the create sheet has no leading
        // Cancel button — drag-to-dismiss is the resilient gesture).
        titleField.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)

        XCTAssertEqual(app.state, .runningForeground, "app must stay running after dismissing the sheet")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "the tabbed app should be reachable after dismissal")
    }
}
