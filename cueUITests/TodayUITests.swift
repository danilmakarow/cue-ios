//
//  TodayUITests.swift
//  cueUITests
//
//  Hermetic E2E for the Today page. Proves the screen is REACHABLE (boots here),
//  INTERACTIVE (task toggle, scroll, pull-to-refresh), and CRASH-SAFE (the app
//  never leaves .runningForeground through any of it). Fidelity of the rendered
//  content is owned by snapshot tests — here we only anchor on stable, seeded
//  text and existing accessibility identifiers.
//

import XCTest

@MainActor
final class TodayUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches the app in hermetic UI-test mode (authenticated + seeded, offline),
    /// which boots straight onto the Today tab.
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitest"]
        app.launch()
        return app
    }

    // MARK: - Reachability

    /// Today is the default tab: the tab bar exists and a seeded agenda task title
    /// is visible on a cold launch, without any navigation.
    func testTodayIsReachableOnLaunchWithSeededTask() {
        let app = launch()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 15),
            "should boot past auth into the tab bar"
        )

        // A seeded incomplete task title is the screen's characteristic anchor.
        let seededTask = app.staticTexts["Standup with the platform team"].firstMatch
        XCTAssertTrue(
            seededTask.waitForExistence(timeout: 10),
            "a seeded agenda task title should be rendered on Today"
        )

        XCTAssertEqual(app.state, .runningForeground, "app must be alive after reaching Today")
    }

    // MARK: - Toggle interaction (crash repro)

    /// Tapping the seeded task done-toggle must not bring the app down; toggling a
    /// second time must keep it alive too.
    func testTogglingTaskTwiceKeepsAppAlive() {
        let app = launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))

        let toggle = app.buttons["task.toggle"].firstMatch
        XCTAssertTrue(
            toggle.waitForExistence(timeout: 10),
            "a seeded completion-requiring task should expose its done toggle"
        )

        toggle.tap()
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after the first toggle")

        // The historically-crashing path is the repeated optimistic toggle.
        let toggleAgain = app.buttons["task.toggle"].firstMatch
        XCTAssertTrue(toggleAgain.waitForExistence(timeout: 5), "the toggle should remain present")
        toggleAgain.tap()
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after the second toggle")

        // The tab bar (a stable Today anchor) must still be present.
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }

    // MARK: - Pull-to-refresh

    /// Swipe-down pull-to-refresh on the agenda scroll view re-syncs the day and the
    /// brief; it must not crash even though network sync is disabled offline.
    func testPullToRefreshDoesNotCrash() {
        let app = launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 10), "Today renders inside a scroll view")

        // A firm downward swipe triggers the refreshable control.
        scrollView.swipeDown(velocity: .fast)

        XCTAssertEqual(app.state, .runningForeground, "app must stay running through pull-to-refresh")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }

    // MARK: - Scrolling the agenda

    /// Scrolling the agenda surface (the morning brief / load card / sections) must
    /// not crash, and the screen stays anchored by its tab bar afterward.
    func testScrollingAgendaKeepsAppAlive() {
        let app = launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 10), "Today renders inside a scroll view")

        scrollView.swipeUp(velocity: .fast)
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after scrolling down")

        scrollView.swipeDown()
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after scrolling back up")

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }
}
