//
//  SearchUITests.swift
//  cueUITests
//
//  Hermetic E2E coverage for the Search page. These tests prove the search sheet
//  is REACHABLE (Calendar tab → magnifyingglass nav button), INTERACTIVE (the
//  query field accepts input and the body swaps into a result / no-result / recent
//  state), and CRASH-SAFE (the app stays in `.runningForeground` after every
//  interaction). They deliberately avoid asserting exact localized content —
//  snapshot tests own fidelity; this file owns reachability + liveness.
//

import XCTest

@MainActor
final class SearchUITests: XCTestCase {
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

    /// Navigates from the booted Today tab to the Calendar tab and opens the
    /// global search sheet via the magnifyingglass nav-bar button. Returns the
    /// search query field once it exists, asserting the sheet's stable anchor.
    @discardableResult
    private func openSearch(_ app: XCUIApplication) -> XCUIElement {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "should boot into the tabbed app")

        let calendarTab = app.tabBars.buttons["Calendar"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 10), "Calendar tab should exist")
        calendarTab.tap()

        // The search affordance is a nav-bar button rendering the magnifyingglass
        // SF Symbol. Its accessibility label is a raw catalog key, so reach it via
        // the image-name first, falling back to a broad button scan.
        let searchButton = app.buttons["magnifyingglass"].firstMatch
        if searchButton.waitForExistence(timeout: 10) {
            searchButton.tap()
        } else {
            let labelled = app.buttons["calendar.chrome.search.accessibility"].firstMatch
            XCTAssertTrue(labelled.waitForExistence(timeout: 10), "calendar search button should exist")
            labelled.tap()
        }

        let field = searchField(app)
        XCTAssertTrue(field.waitForExistence(timeout: 10), "search query field should appear in the sheet")
        return field
    }

    /// Resolves the search query field resiliently: prefer the stable identifier
    /// added to `SearchView`, otherwise the first text/search field on screen.
    private func searchField(_ app: XCUIApplication) -> XCUIElement {
        let identified = app.textFields["search.field"]
        if identified.exists { return identified }
        let anyText = app.textFields.firstMatch
        if anyText.exists { return anyText }
        return app.searchFields.firstMatch
    }

    /// The sheet appears, exposes a query field, and the app stays alive.
    func testSearchSheetOpensAndIsAlive() {
        let app = launch()
        let field = openSearch(app)

        XCTAssertTrue(field.exists, "the search field is the sheet's interactive anchor")
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after opening search")
    }

    /// Typing a query drives the store into a result / no-result state without
    /// crashing; the app remains foregrounded throughout.
    func testTypingQueryKeepsAppAlive() {
        let app = launch()
        let field = openSearch(app)

        field.tap()
        field.typeText("task")

        // Either real results, a no-results empty state, or the recents/idle body
        // renders — we don't assert which (offline + seeded store is lenient). The
        // load-bearing check is simply that the app survived the keystrokes and the
        // field still holds focus/content.
        XCTAssertEqual(app.state, .runningForeground, "app must stay running while typing a query")
        XCTAssertTrue(field.exists, "the query field should remain present after typing")
    }

    /// Typing a deliberately unmatchable query exercises the no-results phase and
    /// confirms the app does not terminate.
    func testNoResultsQueryDoesNotCrash() {
        let app = launch()
        let field = openSearch(app)

        field.tap()
        field.typeText("zzqxnomatch")

        // Give the debounced store a beat to resolve into its terminal phase.
        XCTAssertTrue(app.staticTexts.firstMatch.waitForExistence(timeout: 10), "some body text should render")
        XCTAssertEqual(app.state, .runningForeground, "app must stay running on a no-match query")
    }

    /// Clearing the typed query (via the inline clear button, falling back to a
    /// manual delete) returns to the idle/recent state and the app stays alive.
    func testClearingQueryKeepsAppAlive() {
        let app = launch()
        let field = openSearch(app)

        field.tap()
        field.typeText("meeting")
        XCTAssertEqual(app.state, .runningForeground)

        // The inline clear control carries the "Clear search" accessibility label.
        let clearButton = app.buttons["Clear search"].firstMatch
        if clearButton.waitForExistence(timeout: 5) {
            clearButton.tap()
        } else {
            // Fallback: delete the typed characters from the field directly.
            field.tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))
        }

        XCTAssertEqual(app.state, .runningForeground, "app must stay running after clearing the query")
        XCTAssertTrue(searchField(app).waitForExistence(timeout: 5), "search field should persist after clearing")
    }

    /// Dismissing the search sheet (Cancel) returns to the Calendar tab and the
    /// app remains foregrounded.
    func testDismissSearchReturnsToAppAlive() {
        let app = launch()
        openSearch(app)

        let cancelButton = app.buttons["Cancel"].firstMatch
        if cancelButton.waitForExistence(timeout: 5) {
            cancelButton.tap()
        } else {
            // Fallback: swipe the sheet down to dismiss.
            app.swipeDown()
        }

        XCTAssertEqual(app.state, .runningForeground, "app must stay running after dismissing search")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "tab bar should be back after dismiss")
    }
}
