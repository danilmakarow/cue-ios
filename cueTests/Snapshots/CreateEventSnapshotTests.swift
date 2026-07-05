//
//  CreateEventSnapshotTests.swift
//  cueTests
//
//  Storybook-style snapshot tests for the create-event screen (`NewEventScreen`).
//  The screen owns its form state in a private `@State NewEventViewModel` with no
//  init parameters, so a static snapshot can only capture the initial empty form
//  as it mounts — the all-day and filled variants require driving the live UI
//  (toggling, typing) and belong in an E2E/interaction test. We render the
//  initial state through the full app environment over a seeded container, wrapped
//  in a `NavigationStack` so the inline nav title renders.
//

import SwiftUI
import Testing
@testable import cue

@MainActor
struct CreateEventSnapshotTests {
    /// The initial empty create-event form: details (title/notes/icon), time
    /// section with duration chips + start picker, completion toggle, recurrence,
    /// reminders, group row, and the rationed clay Save CTA in the bottom inset.
    @Test func initialEmptyForm() {
        let container = MockData.container()

        let screen = NavigationStack {
            NewEventScreen()
        }

        #expect(
            SnapshotHarness.record(
                ScreenHost.wrap(screen, container: container),
                named: "create-event-initial"
            ) != nil
        )
    }
}
