//
//  CalendarUITests.swift
//  cueUITests
//
//  Hermetic E2E coverage for the Calendar tab. These tests prove the page is
//  REACHABLE, INTERACTIVE, and CRASH-SAFE — not pixel fidelity. The load-bearing
//  assertion after every interaction is that the app is still
//  `.runningForeground` (it must never terminate/crash), plus that a stable
//  anchor for the screen exists.
//
//  Anchors are drawn from the live Calendar source:
//  - `CalendarHostView` hosts a UIKit day surface and contributes the nav-bar
//    chrome: a magnifyingglass Search button (given the stable identifier
//    "calendar.chrome.search"), and a `ViewModeSwitcher` whose segments carry the
//    accessibility labels "Timeline" and "List" (`calendar.viewMode.*`).
//  - Seeded day events (`UITestSupport.seed`) render as tappable cards whose body
//    tap-target exposes `accessibilityLabel = event.title` with the `.button`
//    trait — e.g. "Design review". Tapping one pushes `TaskDetailScreen`.
//  - The Search button drives `AppNavigation.isPresentingSearch`, presenting
//    `SearchView` as a sheet (a "Search tasks" field + a "Cancel" button).
//

import XCTest

@MainActor
final class CalendarUITests: XCTestCase {
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

    /// Navigates to the Calendar tab and waits for the tab bar to settle.
    /// Returns the launched app so callers can chain interactions.
    @discardableResult
    private func openCalendar() -> XCUIApplication {
        let app = launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "should boot into the tabbed app")

        let calendarTab = app.tabBars.buttons["Calendar"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 10), "Calendar tab should exist")
        calendarTab.tap()
        XCTAssertEqual(app.state, .runningForeground)
        return app
    }

    /// A seeded, incomplete, completion-requiring day event always present in the
    /// hermetic store. Its card body exposes its title as a `.button` element.
    private func seededEvent(in app: XCUIApplication) -> XCUIElement {
        app.buttons["Design review"].firstMatch
    }

    // MARK: - (1) Day scope renders

    func testCalendarDayScopeRendersAndStaysAlive() {
        let app = openCalendar()

        // The day surface is "reached" when a characteristic element exists: a
        // seeded event card (a `.button` labeled by its title) on the day timeline.
        let event = seededEvent(in: app)
        XCTAssertTrue(event.waitForExistence(timeout: 10), "a seeded day event should render on the calendar")

        // The nav-bar view-mode switcher is the other stable day-scope anchor.
        let timelineSegment = app.buttons["Timeline"].firstMatch
        XCTAssertTrue(timelineSegment.waitForExistence(timeout: 10), "the view-mode switcher should be present")

        XCTAssertEqual(app.state, .runningForeground, "Calendar day scope must stay running")
    }

    // MARK: - (2) Search sheet

    func testSearchButtonPresentsAndDismissesSearchSheet() {
        let app = openCalendar()

        // The nav-bar magnifyingglass Search button (stable identifier added in the
        // Calendar host source). Fall back to the raw accessibility-label key the
        // host attaches, in case the identifier query is unavailable.
        var searchButton = app.buttons["calendar.chrome.search"].firstMatch
        if !searchButton.waitForExistence(timeout: 10) {
            searchButton = app.buttons["calendar.chrome.search.accessibility"].firstMatch
        }
        XCTAssertTrue(searchButton.waitForExistence(timeout: 10), "the calendar Search button should be present")
        searchButton.tap()

        // The Search sheet shows a query field ("Search tasks") and a Cancel button.
        let searchField = app.textFields["Search tasks"].firstMatch
        let cancelButton = app.buttons["Cancel"].firstMatch
        let sheetAppeared = searchField.waitForExistence(timeout: 10) || cancelButton.waitForExistence(timeout: 10)
        XCTAssertTrue(sheetAppeared, "tapping Search should present the Search sheet")
        XCTAssertEqual(app.state, .runningForeground)

        // Dismiss via Cancel if present, else swipe the sheet down.
        if cancelButton.exists {
            cancelButton.tap()
        } else {
            app.swipeDown()
        }

        // Back on the Calendar tab, the day surface anchor still exists.
        let event = seededEvent(in: app)
        XCTAssertTrue(event.waitForExistence(timeout: 10), "should return to the calendar after dismissing search")
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after the search round-trip")
    }

    // MARK: - (3) View-mode switcher

    func testViewModeSwitcherTogglesWithoutCrash() {
        let app = openCalendar()

        let listSegment = app.buttons["List"].firstMatch
        let timelineSegment = app.buttons["Timeline"].firstMatch
        XCTAssertTrue(listSegment.waitForExistence(timeout: 10), "List view-mode segment should exist")
        XCTAssertTrue(timelineSegment.waitForExistence(timeout: 10), "Timeline view-mode segment should exist")

        // Toggle to List, then back to Timeline — neither flip may crash the app.
        listSegment.tap()
        XCTAssertEqual(app.state, .runningForeground, "switching to List must not crash")

        // After switching to list mode the seeded event is still reachable as a card.
        let event = seededEvent(in: app)
        XCTAssertTrue(event.waitForExistence(timeout: 10), "the seeded event should remain visible in List mode")

        timelineSegment.tap()
        XCTAssertEqual(app.state, .runningForeground, "switching back to Timeline must not crash")
        XCTAssertTrue(event.waitForExistence(timeout: 10), "the seeded event should remain visible in Timeline mode")
    }

    // MARK: - (4) Event tap → task detail → back

    func testTappingEventOpensDetailThenNavigatesBack() {
        let app = openCalendar()

        let event = seededEvent(in: app)
        XCTAssertTrue(event.waitForExistence(timeout: 10), "a seeded day event should be tappable")
        event.tap()
        XCTAssertEqual(app.state, .runningForeground, "opening task detail must not crash")

        // The detail surface is "reached" when a characteristic element exists. The
        // event title persists on the pushed `TaskDetailScreen` header; the nav bar
        // also gains a Back button. Either is a sufficient leniency anchor.
        let detailTitle = app.staticTexts["Design review"].firstMatch
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        let detailReached = detailTitle.waitForExistence(timeout: 10) || backButton.waitForExistence(timeout: 10)
        XCTAssertTrue(detailReached, "tapping an event should present a task detail surface")

        // Navigate back: use the nav-bar back button if present, else swipe back.
        if backButton.exists {
            backButton.tap()
        } else {
            app.swipeRight()
        }

        XCTAssertTrue(seededEvent(in: app).waitForExistence(timeout: 10), "should return to the day scope after back")
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after the detail round-trip")
    }

    // MARK: - (Best-effort) Pinch-to-zoom scope change

    func testPinchToZoomDoesNotCrash() {
        let app = openCalendar()
        XCTAssertTrue(seededEvent(in: app).waitForExistence(timeout: 10), "day scope should render before pinching")

        // Best-effort: a pinch over the calendar surface to drive the continuous
        // zoom between scopes. We do NOT assert the scope actually changed — the
        // UIKit zoom controller may swallow or rate-limit a synthetic pinch — only
        // that the gesture never brings the app down. (Note: pinch is applied to the
        // window since the UIKit day surface has no addressable element identifier.)
        let target = app.windows.firstMatch
        if target.exists {
            target.pinch(withScale: 0.5, velocity: -1)
        }

        XCTAssertEqual(app.state, .runningForeground, "pinch-to-zoom must never crash the app")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "the tabbed app should remain present after a pinch")
    }
}
