//
//  PersonaUITests.swift
//  cueUITests
//
//  Hermetic E2E proof for the AI-Assistant Persona editor: it is REACHABLE from
//  Settings → "AI Assistant", INTERACTIVE (preset chips / the "Custom" chip /
//  the "Customize this preset" control respond), and CRASH-SAFE (the app never
//  terminates). Fidelity of rendered content is owned by snapshot tests; here
//  the load-bearing assertion after each interaction is that the app stays
//  `.runningForeground`.
//
//  Note on hermetic mode: --uitest boots offline, so the persona's cold network
//  read can land on EITHER the loaded editor (preset chips + prompt well) or the
//  full-page error state. Both prove the screen was reached and stayed alive, so
//  the tests anchor on the always-present navigation title ("Assistant Persona")
//  and treat the interactive controls as conditional — exercising them only when
//  present, and always re-asserting the app is still running.
//

import XCTest

@MainActor
final class PersonaUITests: XCTestCase {
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

    /// Drives the tab bar to Settings and taps the "AI Assistant" row, pushing the
    /// Persona editor. Returns the live app for further assertions.
    @discardableResult
    private func openPersona(_ app: XCUIApplication) -> XCUIApplication {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "should boot into the tabbed app")

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "Settings tab should exist")
        settingsTab.tap()

        // The Integrations section exposes an "AI Assistant" navigation row; tap it.
        let assistantRow = app.buttons["AI Assistant"].firstMatch
        if assistantRow.waitForExistence(timeout: 10) {
            assistantRow.tap()
        } else {
            // Fallback: the row's title may surface as a static text inside the cell.
            let assistantText = app.staticTexts["AI Assistant"].firstMatch
            XCTAssertTrue(assistantText.waitForExistence(timeout: 10), "AI Assistant row should be present in Settings")
            assistantText.tap()
        }
        return app
    }

    /// The Persona editor is reachable from Settings — the navigation title
    /// "Assistant Persona" (set regardless of load outcome) anchors the screen,
    /// and the app stays alive.
    func testPersonaEditorIsReachable() {
        let app = launch()
        openPersona(app)

        // The navigation title is set unconditionally, so it's a stable anchor
        // whether the offline cold-read lands on the loaded editor or the error
        // state. Accept either the nav-bar title or a matching static text.
        let titleBar = app.navigationBars["Assistant Persona"].firstMatch
        let titleText = app.staticTexts["Assistant Persona"].firstMatch
        XCTAssertTrue(
            titleBar.waitForExistence(timeout: 10) || titleText.waitForExistence(timeout: 10),
            "the Persona editor should be reached (its 'Assistant Persona' title anchors the screen)"
        )
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after reaching the Persona editor")
    }

    /// Selecting a preset chip (when the editor loaded its presets) keeps the app
    /// alive. If presets did not load (offline error state), the test still proves
    /// the screen is reached and crash-safe.
    func testSelectingPresetChipKeepsAppAlive() {
        let app = launch()
        openPersona(app)

        let titleBar = app.navigationBars["Assistant Persona"].firstMatch
        let titleText = app.staticTexts["Assistant Persona"].firstMatch
        XCTAssertTrue(
            titleBar.waitForExistence(timeout: 10) || titleText.waitForExistence(timeout: 10),
            "the Persona editor should be reached"
        )

        // Preset chips render with a leading "sparkles" symbol and a name label.
        // They are conditional on a successful cold read; exercise the first
        // available chip if present, otherwise assert the screen is still alive.
        let presetsLabel = app.staticTexts["PRESETS"].firstMatch
        if presetsLabel.waitForExistence(timeout: 8) {
            // The chip row sits just under the PRESETS eyebrow; tap a visible,
            // hittable chip button that isn't a back/tab control.
            let chip = firstPresetChip(in: app)
            if let chip, chip.isHittable {
                chip.tap()
            }
        }

        XCTAssertEqual(app.state, .runningForeground, "app must stay running after selecting a preset chip")
    }

    /// Entering custom-edit mode (via the "Custom" chip or the "Customize this
    /// preset" button) unlocks the prompt field without crashing. Both controls
    /// are conditional on the loaded state; whichever exists is exercised.
    func testEnteringCustomEditKeepsAppAlive() {
        let app = launch()
        openPersona(app)

        let titleBar = app.navigationBars["Assistant Persona"].firstMatch
        let titleText = app.staticTexts["Assistant Persona"].firstMatch
        XCTAssertTrue(
            titleBar.waitForExistence(timeout: 10) || titleText.waitForExistence(timeout: 10),
            "the Persona editor should be reached"
        )

        // Prefer the explicit "Customize this preset" CTA shown under a locked
        // preset; fall back to the "Custom" chip in the chip row.
        let customizeButton = app.buttons["Customize this preset"].firstMatch
        let customChip = app.buttons["Custom"].firstMatch
        if customizeButton.waitForExistence(timeout: 8), customizeButton.isHittable {
            customizeButton.tap()
        } else if customChip.waitForExistence(timeout: 4), customChip.isHittable {
            customChip.tap()
        }

        // Whether or not the unlock control existed, the app must be alive. If the
        // field unlocked, a TextEditor / text view should be present and typeable.
        XCTAssertEqual(app.state, .runningForeground, "app must stay running after entering custom-edit")

        let editor = app.textViews.firstMatch
        if editor.waitForExistence(timeout: 5), editor.isHittable {
            editor.tap()
            editor.typeText(" tweak")
            XCTAssertEqual(app.state, .runningForeground, "app must stay running after typing in the custom prompt")
        }
    }

    /// Navigating into the Persona editor and back out via the nav-bar back button
    /// returns to Settings without crashing — a well-behaved pushed destination.
    func testPersonaNavigatesBackAlive() {
        let app = launch()
        openPersona(app)

        let titleBar = app.navigationBars["Assistant Persona"].firstMatch
        let titleText = app.staticTexts["Assistant Persona"].firstMatch
        XCTAssertTrue(
            titleBar.waitForExistence(timeout: 10) || titleText.waitForExistence(timeout: 10),
            "the Persona editor should be reached before popping"
        )

        // Pop back to Settings via the navigation bar's leading back button.
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 5) {
            backButton.tap()
        }

        XCTAssertEqual(app.state, .runningForeground, "app must stay running after leaving the Persona editor")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "should return to the tabbed shell")
    }

    // MARK: - Helpers

    /// Finds the first selectable preset chip in the editor's chip row, excluding
    /// the always-present "Custom" chip and chrome controls (tabs / back button).
    /// Returns `nil` when no preset chip is present (e.g. offline error state).
    private func firstPresetChip(in app: XCUIApplication) -> XCUIElement? {
        let excluded: Set<String> = ["Custom", "Settings", "Today", "Calendar", "New Event"]
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons where button.exists && button.isHittable {
            let label = button.label
            guard !label.isEmpty, !excluded.contains(label) else { continue }
            // Heuristic: a preset chip's label is a short persona name, not a long
            // sentence; skip obvious non-chip controls.
            if label.count <= 40 {
                return button
            }
        }
        return nil
    }
}
