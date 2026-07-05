//
//  CalendarDaySnapshotTests.swift
//  cueTests
//
//  Storybook-style snapshot suite for the Calendar tab's day scope
//  (`CalendarHostView`, day view mode). The visible timeline is UIKit-backed
//  (`CalendarUIKitView` → `CalendarContainerViewController`), so these captures
//  are best-effort: they record whatever the hosted UIKit surface rasterizes in
//  the offline window, including at minimum the SwiftUI nav-bar chrome (serif/
//  sans date title, search + view-mode switcher) the host reproduces. The
//  seeded store is read synchronously; the screen's network `.task` is fire-and-
//  forget and does not block the capture.
//

import SwiftData
import SwiftUI
import Testing
@testable import cue

@MainActor
struct CalendarDaySnapshotTests {
    /// Builds a fresh in-memory container seeded for *today* in the given day
    /// state. The store defaults `selectedDate` to `startOfDay(.now)` and
    /// `viewMode` to `.timeline` (the day/timeline default), so seeding on
    /// `Date.now` lines the occurrences up with the scope the host renders.
    private func seededContainer(_ state: MockData.DayState) -> ModelContainer {
        let container = MockData.container()
        MockData.seed(state, on: .now, into: container.mainContext)
        try? container.mainContext.save()
        return container
    }

    /// Records the day scope for `state` under the name `calendar-day-<state>`.
    /// `CalendarStore` defaults to today + timeline mode, so the host renders the
    /// day timeline over the seeded occurrences with no extra setup.
    private func record(_ state: MockData.DayState, named name: String) {
        let container = seededContainer(state)
        let screen = ScreenHost.wrap(
            CalendarHostView(user: MockData.user),
            container: container
        )
        #expect(SnapshotHarness.record(screen, named: name) != nil)
    }

    @Test
    func empty() {
        record(.empty, named: "calendar-day-empty")
    }

    @Test
    func overlapping() {
        record(.overlapping, named: "calendar-day-overlapping")
    }

    @Test
    func heavy() {
        record(.heavy, named: "calendar-day-heavy")
    }
}
