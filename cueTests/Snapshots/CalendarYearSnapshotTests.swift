//
//  CalendarYearSnapshotTests.swift
//  cueTests
//
//  Storybook-style snapshot tests for the Calendar "year" scope — the most
//  zoomed-out level of the UIKit calendar (a vertically-scrolling grid of years,
//  each a large Fraunces year title above a three-column grid of twelve
//  mini-months).
//
//  Reachability note: the year scope is NOT statically reachable through
//  `CalendarHostView`. That host bridges in `CalendarContainerViewController`,
//  which *rests on the day scope at launch* and only reaches month/year via an
//  interactive pinch-zoom or a unit tap (see CalendarContainerViewController's
//  "day scope is the resting/launch scope" containment doc). A snapshot harness
//  can't drive a pinch gesture, so to capture the year grid we host the
//  `YearScopeViewController` directly via a tiny inline `UIViewControllerRepresentable`
//  — constructed with the exact same dependencies the container injects
//  (`store`, `CalendarDataAdapter`, `modelContext`, `CalendarTheme`,
//  `PrefetchCoordinator`). The year scope renders no per-day event density (it
//  paints only the month grids + today highlight), so the seeded store state
//  doesn't change the grid; we still seed a representative month so the read
//  pipeline is exercised, and wrap in a `NavigationStack` so the nav chrome
//  renders as in the app.
//

import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import cue

@MainActor
struct CalendarYearSnapshotTests {

    /// Hosts the UIKit `YearScopeViewController` directly so its year grid can be
    /// captured without the interactive pinch-zoom the SwiftUI host requires to
    /// reach the year scope. Built with the same dependency set the
    /// `CalendarContainerViewController` injects.
    private struct YearScopeHost: UIViewControllerRepresentable {
        let store: CalendarStore
        let modelContext: ModelContext

        func makeUIViewController(context: Context) -> YearScopeViewController {
            let theme = CalendarTheme(
                colors: AppPalette.kraftInk.colors,
                traits: UITraitCollection.current
            )
            let adapter = CalendarDataAdapter(context: modelContext, store: store)
            return YearScopeViewController(
                store: store,
                adapter: adapter,
                modelContext: modelContext,
                theme: theme,
                prefetchCoordinator: PrefetchCoordinator()
            )
        }

        func updateUIViewController(_ controller: YearScopeViewController, context: Context) {}
    }

    /// Builds the year-scope screen over a freshly-seeded container, pinned to a
    /// deterministic selected date so the grid centers on a stable year. Wrapped in
    /// a `NavigationStack` (inline-title nav chrome) like the real Calendar tab.
    private func makeScreen(seeding state: MockData.DayState) -> (some View, ModelContainer) {
        let container = MockData.container()
        let modelContext = container.mainContext
        // Pin the store's selection so the centered year is deterministic across runs.
        let store = CalendarStore(user: MockData.user)
        store.selectedDate = Calendar.current.startOfDay(for: .now)
        MockData.seed(state, on: store.selectedDate, into: modelContext)
        try? modelContext.save()

        let screen = NavigationStack {
            YearScopeHost(store: store, modelContext: modelContext)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(Text(verbatim: "2026"))
                .navigationBarTitleDisplayMode(.inline)
        }
        return (screen, container)
    }

    /// The default year grid — the only statically meaningful year-scope state, per
    /// the design reference (`Calendar Year.dc.html`): a year title over a grid of
    /// twelve mini-months with the current month/day highlighted. The year scope
    /// renders no event density, so a single representative seed suffices.
    @Test
    func defaultYearGrid() {
        let (screen, container) = makeScreen(seeding: .single)
        let view = ScreenHost.wrap(screen, container: container)
        #expect(SnapshotHarness.record(view, named: "calendar-year-default") != nil)
    }
}
