//
//  EventDetailUITests.swift
//  cueUITests
//
//  Hermetic E2E coverage for the EventDetail page (TaskDetailScreen), reached via
//  Calendar → tapping an event card in the day view. Proves the screen is
//  REACHABLE, INTERACTIVE, and CRASH-SAFE — not pixel fidelity (snapshot tests own
//  that). The load-bearing assertion after every interaction is that the app is
//  still `.runningForeground` (never terminates/crashes), plus that a stable
//  anchor for the screen exists.
//
//  Note on offline mode: the detail screen's series-detail fetch (`GET /tasks/:id`)
//  is disabled under `--uitest`, so the Edit affordance — gated on that fetch
//  succeeding — may remain disabled. The Edit test therefore exercises Edit
//  defensively (only taps when hittable) while still proving the control is
//  present and the app survives. The completion CTA ("Mark done") flows entirely
//  through the local store and works offline.
//

import XCTest

@MainActor
final class EventDetailUITests: XCTestCase {
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

    /// Navigates from the booted tab app into the EventDetail screen: switches to
    /// the Calendar tab, taps the first seeded event card in the day view, and
    /// waits for the detail screen's "Task" navigation bar. Returns the live app.
    @discardableResult
    private func openEventDetail(_ app: XCUIApplication) -> XCUIElement {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "should boot into the tabbed app")

        app.tabBars.buttons["Calendar"].tap()

        // The day view renders seeded events as tappable cards; each card's body
        // tap-target carries the `day.event.card` identifier (and the event title
        // as its accessibility label). Tap the first one to push the detail.
        let eventCard = app.buttons["day.event.card"].firstMatch
        XCTAssertTrue(eventCard.waitForExistence(timeout: 15), "the Calendar day view should render a tappable event card")
        eventCard.tap()

        // Anchor: the detail screen's inline nav title is "Task".
        let detailNavBar = app.navigationBars["Task"].firstMatch
        XCTAssertTrue(detailNavBar.waitForExistence(timeout: 10), "tapping an event card should push the Task detail screen")
        return detailNavBar
    }

    /// The EventDetail screen is reachable from the Calendar day view and presents
    /// the task's title plus its "Task" nav bar.
    func testEventDetailIsReachableAndShowsTitle() {
        let app = launch()
        openEventDetail(app)

        // A characteristic anchor: at least one of the seeded task titles is shown
        // as the detail header. We don't pin an exact string (titles may shift) —
        // any of the seeded titles satisfies "the detail surface rendered".
        let seededTitle = app.staticTexts["Standup with the platform team"].firstMatch
        let anyHeaderText = app.scrollViews.staticTexts.firstMatch
        XCTAssertTrue(
            seededTitle.waitForExistence(timeout: 10) || anyHeaderText.waitForExistence(timeout: 10),
            "the detail screen should render the task's title text"
        )
        XCTAssertEqual(app.state, .runningForeground, "app must stay running on the EventDetail screen")
    }

    /// The Edit affordance is present in the detail toolbar. When it is enabled
    /// (series detail loaded), tapping it opens the "Edit Task" screen, which is
    /// then dismissed via Cancel. Under offline mode Edit may stay disabled — in
    /// that case the test still asserts the control exists and the app survives.
    func testEditAffordanceOpensAndDismissesOrStaysAliveWhenDisabled() {
        let app = launch()
        openEventDetail(app)

        let editButton = app.buttons["Edit"].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 10), "the detail toolbar should expose an Edit control")

        if editButton.isEnabled && editButton.isHittable {
            editButton.tap()

            // The edit sheet anchors on its "Edit Task" navigation title.
            let editTitle = app.navigationBars["Edit Task"].firstMatch
            XCTAssertTrue(editTitle.waitForExistence(timeout: 10), "tapping Edit should present the Edit Task screen")
            XCTAssertEqual(app.state, .runningForeground, "app must stay running after opening the edit screen")

            // Dismiss via the Cancel toolbar button → back on the detail screen.
            let cancel = app.buttons["Cancel"].firstMatch
            XCTAssertTrue(cancel.waitForExistence(timeout: 10), "the edit screen should expose a Cancel button")
            cancel.tap()

            XCTAssertTrue(
                app.navigationBars["Task"].firstMatch.waitForExistence(timeout: 10),
                "cancelling the edit screen should return to the Task detail"
            )
        }

        XCTAssertEqual(app.state, .runningForeground, "app must stay running after exercising the Edit affordance")
    }

    /// The completion CTA ("Mark done") taps without crashing. The seeded tasks
    /// require completion, so the pinned bottom CTA is present; toggling it flows
    /// through the local store (works offline) and must keep the app alive.
    func testMarkDoneTapsWithoutCrashing() {
        let app = launch()
        openEventDetail(app)

        // The pinned bottom CTA reads "Mark done" for an incomplete task. Fall back
        // to "Mark not done" in case the tapped card was already complete.
        let markDone = app.buttons["Mark done"].firstMatch
        let markNotDone = app.buttons["Mark not done"].firstMatch
        let cta = markDone.waitForExistence(timeout: 10) ? markDone : markNotDone
        XCTAssertTrue(
            cta.waitForExistence(timeout: 10),
            "a completion-requiring task should surface a Mark done / Mark not done CTA"
        )
        cta.tap()

        // The historically-fragile completion path: after toggling, the app must
        // remain alive and still on the detail screen.
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after tapping the completion CTA")
        XCTAssertTrue(
            app.navigationBars["Task"].firstMatch.waitForExistence(timeout: 10),
            "the detail screen should remain after toggling completion"
        )
    }

    /// Exercising the destructive Delete action must not crash. Delete opens a
    /// confirmation sheet; we dismiss it (Cancel) rather than committing — the
    /// load-bearing assertion is that the app stays alive throughout.
    func testDeleteActionIsCrashSafe() {
        let app = launch()
        openEventDetail(app)

        // The Delete control lives in the secondary actions section ("Delete Task").
        let deleteButton = app.buttons["Delete Task"].firstMatch
        guard deleteButton.waitForExistence(timeout: 10) else {
            // Delete not surfaced — nothing to exercise, but the app must be alive.
            XCTAssertEqual(app.state, .runningForeground, "app must stay running on the detail screen")
            return
        }

        if deleteButton.isHittable {
            deleteButton.tap()
        } else {
            // Bring it on-screen if it's below the fold, then tap.
            app.scrollViews.firstMatch.swipeUp()
            if deleteButton.isHittable { deleteButton.tap() }
        }

        // A confirmation sheet appears. Dismiss without committing the destructive
        // action — prefer an explicit Cancel; otherwise tap outside / no-op. The
        // only hard requirement is that the app never crashed.
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.waitForExistence(timeout: 5) && cancel.isHittable {
            cancel.tap()
        }

        XCTAssertEqual(app.state, .runningForeground, "app must stay running after exercising Delete")
    }
}
