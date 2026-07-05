//
//  TodaySnapshotTests.swift
//  cueTests
//
//  Design-fidelity snapshot suite for the Today screen (the SwiftUI render of
//  `Today.dc.html`). Each test seeds a fresh in-memory store with one content
//  state, wraps `TodayView` in the full app environment + a NavigationStack, and
//  rasterizes it to a PNG attached to the result bundle as `today-<state>.png`.
//  (The screen leads with the greeting block, not a large nav title.)
//
//  Note on the day window: `TodayView`'s `@Query` bounds occurrences to
//  `[startOfDay(.now), startOfNextDay)`, so fixtures MUST be seeded on the
//  *current* day for the seeded rows to land inside the predicate. We seed on
//  `Date.now`; the morning-brief network call fired by `.task` is best-effort
//  and does not block the synchronous capture of the seeded store.
//

import SwiftData
import SwiftUI
import Testing
@testable import cue

@MainActor
struct TodaySnapshotTests {
    /// Builds a fresh seeded container, hosts `TodayView` in the app environment
    /// inside a NavigationStack, records the PNG, and asserts the render succeeded.
    private func snapshot(_ state: MockData.DayState, named name: String) {
        let container = MockData.container()
        MockData.seed(state, on: .now, into: container.mainContext)

        let screen = NavigationStack {
            TodayView(user: MockData.user)
        }
        let hosted = ScreenHost.wrap(screen, container: container)

        #expect(SnapshotHarness.record(hosted, named: name) != nil)
    }

    /// Empty day — the greeting leads, then the "clear day" EmptyStateView stands in
    /// for the Up-next hero (no hero, no brief CTA).
    @Test func empty() {
        snapshot(.empty, named: "today-empty")
    }

    /// A single occurrence — the greeting + the Up-next hero Task Box for that one
    /// next thing + the Today's-brief card.
    @Test func single() {
        snapshot(.single, named: "today-single")
    }

    /// Three overlapping mid-morning occurrences — the Up-next hero picks the single
    /// next open occurrence from the cluster.
    @Test func overlapping() {
        snapshot(.overlapping, named: "today-overlapping")
    }

    /// A mix of completed and open occurrences — exercises the hero's next-open pick
    /// past the already-done rows (the effective task color + done styling).
    @Test func completedMix() {
        snapshot(.completedMix, named: "today-completedMix")
    }

    /// Ten occurrences spanning the day — the heaviest day still resolves to one
    /// Up-next hero (the earliest still-open occurrence), no long agenda list.
    @Test func heavy() {
        snapshot(.heavy, named: "today-heavy")
    }
}
