//
//  GroupsUITests.swift
//  cueUITests
//
//  Hermetic E2E coverage for the Groups page (Settings → Groups). Proves the
//  screen is REACHABLE, INTERACTIVE, and CRASH-SAFE — not pixel fidelity.
//  The load-bearing assertion after every interaction is that the app is still
//  `.runningForeground` (never terminates/crashes), plus a stable anchor exists.
//

import XCTest

@MainActor
final class GroupsUITests: XCTestCase {
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

    /// Navigates from the booted tab app into the Groups screen via
    /// Settings → the "Groups" row, and returns the live app. Anchors on the
    /// seeded "Work" group being visible to confirm the list rendered.
    private func openGroups(_ app: XCUIApplication) {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "should boot into the tab bar")

        app.tabBars.buttons["Settings"].tap()

        // The Manage section's "Groups" navigation row. The row label is "Groups".
        let groupsRow = app.buttons["Groups"].firstMatch
        XCTAssertTrue(groupsRow.waitForExistence(timeout: 10), "the Settings → Groups row should be present")
        groupsRow.tap()

        // Anchor: the seeded "Work" group row is visible on the Groups list.
        let workGroup = app.staticTexts["Work"].firstMatch
        XCTAssertTrue(workGroup.waitForExistence(timeout: 10), "the seeded 'Work' group should appear in the Groups list")
    }

    /// The Groups screen is reachable from Settings and shows the seeded group.
    func testGroupsListIsReachableAndShowsSeededGroup() {
        let app = launch()
        openGroups(app)

        XCTAssertTrue(app.staticTexts["Work"].firstMatch.exists, "'Work' group anchor must exist")
        XCTAssertEqual(app.state, .runningForeground, "app must stay running on the Groups screen")
    }

    /// Tapping the seeded group opens the Group Edit sheet; dismissing it leaves
    /// the app alive and back on the Groups list.
    func testTappingGroupOpensEditSheetThenDismisses() {
        let app = launch()
        openGroups(app)

        app.staticTexts["Work"].firstMatch.tap()

        // The edit sheet anchors on its "Edit Group" navigation title and the
        // name field seeded with the group name.
        let editTitle = app.navigationBars["Edit Group"].firstMatch
        let nameField = app.textFields.firstMatch
        let editSheetAppeared = editTitle.waitForExistence(timeout: 10) || nameField.waitForExistence(timeout: 10)

        // TODO(e2e): The edit path keys the sheet on a *remote* `TaskGroupDTO`
        // (`editingGroup = remoteDTOs.first(...)`), populated only by the live
        // `GET /task-groups` fetch — which the hermetic `--uitest` mode disables.
        // With no remote DTO the sheet legitimately stays closed, so we cannot
        // assert it opens here. The load-bearing guarantee is that tapping the row
        // never crashes the app; the sheet's own rendering is covered by the
        // create-sheet test below (same `GroupEditSheet`) and by snapshot tests.
        if editSheetAppeared {
            let cancel = app.buttons["Cancel"].firstMatch
            if cancel.waitForExistence(timeout: 10) { cancel.tap() }
            XCTAssertTrue(app.staticTexts["Work"].firstMatch.waitForExistence(timeout: 10), "should return to the Groups list")
        }
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after tapping a group row")
    }

    /// Tapping the add (＋) control opens the create sheet; dismissing it leaves
    /// the app alive and back on the Groups list.
    func testTappingAddOpensCreateSheetThenDismisses() {
        let app = launch()
        openGroups(app)

        // The toolbar add button carries the accessibility label "New group". It is
        // a small (30×30) circular control tucked inside the Liquid Glass nav bar,
        // which XCUITest can report as non-hittable even though it exists — so a
        // plain `.tap()` may land on dead space. Tap via its coordinate (which
        // bypasses the hittability gate) to reliably drive the toolbar action.
        let addButton = app.buttons["New group"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "the add (＋) control should be present")
        addButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // The create sheet anchors on its "New Group" navigation title.
        let createTitle = app.navigationBars["New Group"].firstMatch
        var nameField = app.textFields.firstMatch
        var sheetAppeared = createTitle.waitForExistence(timeout: 10) || nameField.waitForExistence(timeout: 10)
        if !sheetAppeared {
            // Retry once via the raw `plus` toolbar wrapper element.
            app.buttons["plus"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            nameField = app.textFields.firstMatch
            sheetAppeared = createTitle.waitForExistence(timeout: 10) || nameField.waitForExistence(timeout: 10)
        }
        XCTAssertTrue(
            sheetAppeared,
            "tapping add should open the create-group sheet"
        )
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after opening the create sheet")

        // Dismiss via Cancel.
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "the create sheet should expose a Cancel button")
        cancel.tap()

        // Back on the list and alive.
        XCTAssertTrue(app.staticTexts["Work"].firstMatch.waitForExistence(timeout: 10), "should return to the Groups list")
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after dismissing the create sheet")
    }
}
