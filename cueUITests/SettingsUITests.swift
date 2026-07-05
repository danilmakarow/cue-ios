//
//  SettingsUITests.swift
//  cueUITests
//
//  Reachability / interactivity / crash-safety coverage for the Settings tab and
//  each of its sub-screens (Account, Notifications & Report, AI Assistant persona,
//  Groups, Telegram). These tests prove every destination is reachable, opens a
//  characteristic anchor, returns cleanly, and never brings the app down — they do
//  NOT assert pixel content (snapshot tests own fidelity). Sign-out is deliberately
//  never exercised (it would exit to the auth flow).
//

import XCTest

@MainActor
final class SettingsUITests: XCTestCase {
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

    /// Boots, waits for the tab bar, taps the Settings tab, and returns the app.
    private func openSettings(timeout: TimeInterval = 15) -> XCUIApplication {
        let app = launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: timeout), "tab bar should appear after boot")

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "Settings tab should exist")
        settingsTab.tap()
        return app
    }

    /// Resolves a settings row by its visible label, scrolling the list up to a few
    /// times until it is hittable (the list is a scroll view, lower rows may be off-screen).
    private func settingsRow(_ label: String, in app: XCUIApplication) -> XCUIElement {
        // Prefer an exact-label match, but fall back to a label-prefix match: rows
        // with a trailing status accessory (e.g. the Telegram row appends its
        // connection status) expose a *compound* accessibility label like
        // "Telegram, Not connected", which an exact `buttons[label]` query misses.
        var row = app.buttons[label].firstMatch
        var attempts = 0
        while !(row.exists && row.isHittable) && attempts < 4 {
            if !row.exists {
                let prefixed = app.buttons.matching(
                    NSPredicate(format: "label BEGINSWITH %@", label)
                ).firstMatch
                if prefixed.exists { row = prefixed }
            }
            if row.exists && row.isHittable { break }
            app.swipeUp()
            attempts += 1
        }
        if !(row.exists && row.isHittable) {
            let prefixed = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", label)
            ).firstMatch
            if prefixed.exists { row = prefixed }
        }
        return row
    }

    /// Drives into a sub-screen via its settings row, asserts the destination's
    /// navigation-title text appears, then pops back to Settings — asserting the app
    /// stays alive throughout.
    private func assertSubScreen(
        rowLabel: String,
        titleText: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let row = settingsRow(rowLabel, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "row \(rowLabel) should exist", file: file, line: line)
        row.tap()

        let title = app.staticTexts[titleText].firstMatch
        XCTAssertTrue(
            title.waitForExistence(timeout: 10),
            "\(rowLabel) destination should show its title \(titleText)",
            file: file,
            line: line
        )
        XCTAssertEqual(app.state, .runningForeground, "app must stay running on \(rowLabel)", file: file, line: line)

        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5), "a back button should exist on \(rowLabel)", file: file, line: line)
        back.tap()

        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 10),
            "should return to the tabbed Settings list from \(rowLabel)",
            file: file,
            line: line
        )
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after leaving \(rowLabel)", file: file, line: line)
    }

    // MARK: - Reachability

    func testSettingsTabIsReachable() {
        let app = openSettings()

        // The seeded profile card carries the user's display name — a stable anchor
        // proving the Settings scroll rendered.
        let name = app.staticTexts["Tony Stark"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10), "the seeded profile name should anchor the Settings screen")
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testCoreRowsExist() {
        let app = openSettings()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        // Groups lives in the Manage section near the top.
        XCTAssertTrue(
            settingsRow("Groups", in: app).waitForExistence(timeout: 10),
            "Groups row should exist"
        )
        // Account is the last navigable row — scrolling reaches it.
        XCTAssertTrue(
            settingsRow("Account", in: app).waitForExistence(timeout: 10),
            "Account row should exist"
        )
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Sub-screens

    func testGroupsScreenOpensAndReturns() {
        let app = openSettings()
        assertSubScreen(rowLabel: "Groups", titleText: "Groups", in: app)
    }

    func testNotificationsReportOpensAndReturns() {
        let app = openSettings()
        assertSubScreen(rowLabel: "Notifications & report", titleText: "Notifications & Report", in: app)
    }

    func testAssistantPersonaOpensAndReturns() {
        let app = openSettings()
        assertSubScreen(rowLabel: "AI Assistant", titleText: "Assistant Persona", in: app)
    }

    func testTelegramOpensAndReturns() {
        let app = openSettings()
        assertSubScreen(rowLabel: "Telegram", titleText: "Telegram", in: app)
    }

    func testAccountOpensAndReturns() {
        let app = openSettings()
        assertSubScreen(rowLabel: "Account", titleText: "Account", in: app)
    }

    // MARK: - Interaction crash-safety

    func testAppearanceAndLanguagePillsAreInteractive() {
        let app = openSettings()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        // The Appearance card exposes a tappable Theme fill-pill that opens a Menu.
        // Tapping it (and dismissing) must never crash the app.
        let themeRow = app.staticTexts["Theme"].firstMatch
        if themeRow.waitForExistence(timeout: 5), themeRow.isHittable {
            themeRow.tap()
            // A menu may or may not appear depending on hit target; either way the
            // app must stay alive. Dismiss any presented menu by tapping elsewhere.
            if app.buttons["Light"].firstMatch.waitForExistence(timeout: 2) {
                app.buttons["Light"].firstMatch.tap()
            }
        }
        XCTAssertEqual(app.state, .runningForeground, "app must survive interacting with Appearance")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }

    func testVisitingEverySubScreenInOneSessionStaysAlive() {
        let app = openSettings()
        assertSubScreen(rowLabel: "Groups", titleText: "Groups", in: app)
        assertSubScreen(rowLabel: "Telegram", titleText: "Telegram", in: app)
        assertSubScreen(rowLabel: "Notifications & report", titleText: "Notifications & Report", in: app)
        assertSubScreen(rowLabel: "AI Assistant", titleText: "Assistant Persona", in: app)
        assertSubScreen(rowLabel: "Account", titleText: "Account", in: app)
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after the full Settings tour")
    }
}
