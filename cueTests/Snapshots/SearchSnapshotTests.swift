//
//  SearchSnapshotTests.swift
//  cueTests
//
//  Storybook-style snapshot suite for `SearchView`.
//
//  IMPORTANT — what we can and cannot render here:
//  `SearchView` owns its `SearchStore` as private `@State`, and the store's
//  `phase` is `private(set)` and only advances via a network request through
//  `APIClient.searchTasks`. There is no injection seam, so the loading / results
//  / no-results / failed phases are unreachable from a snapshot test (the view
//  always boots in `.idle`, and the backend is down in CI). Those phases require
//  an E2E / UI test — see `skipped` in the returned report.
//
//  The `.idle` phase IS fully snapshottable: it renders the recent-searches body
//  (or the empty state when there are no recents). We exercise it three ways by
//  seeding the device-local inputs the view reads synchronously:
//    • `search.recentQueries` in UserDefaults (the `@AppStorage` history), and
//    • `EventTaskGroup` rows in the SwiftData store (the `@Query` chip rail).
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import cue

@MainActor
struct SearchSnapshotTests {
    /// Overwrites the `@AppStorage("search.recentQueries")` JSON blob the view
    /// decodes for its recent-search history. Pass an empty array to clear it.
    private func setRecents(_ terms: [String]) {
        let data = try? JSONEncoder().encode(terms)
        let json = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        UserDefaults.standard.set(json, forKey: "search.recentQueries")
    }

    /// Renders `SearchView` inside a `NavigationStack` (the presenting site supplies
    /// one in the app) through the full app environment, and records the PNG.
    private func record(named name: String, container: ModelContainer) {
        let screen = NavigationStack { SearchView() }
        #expect(
            SnapshotHarness.record(
                ScreenHost.wrap(screen, container: container),
                named: name
            ) != nil
        )
    }

    /// Empty / initial: no recent history and no groups — the bare
    /// "Search your tasks" `EmptyStateView`, no chip rail.
    @Test
    func searchEmpty() {
        setRecents([])
        let container = MockData.container()
        record(named: "search-empty", container: container)
    }

    /// Idle with recent history: the `@AppStorage` recents render as a "Recent"
    /// section of tappable rows (still the `.idle` phase, blank query).
    @Test
    func searchRecents() {
        setRecents([
            "Design review",
            "Pepper 1:1",
            "Q3 report",
            "standup",
        ])
        let container = MockData.container()
        record(named: "search-recents", container: container)
    }

    /// Idle with recents AND group chips: seeding `EventTaskGroup` rows lights up
    /// the horizontal filter rail above the recents body (chrome + body together).
    @Test
    func searchRecentsWithFilters() {
        setRecents([
            "Design review",
            "Pepper 1:1",
            "Q3 report",
        ])
        let container = MockData.container()
        let context = container.mainContext
        MockData.group(id: "grp-work", name: "Work", color: "#3B82F6", in: context)
        MockData.group(id: "grp-home", name: "Home", color: "#466234", in: context)
        MockData.group(id: "grp-health", name: "Health", color: "#BE4A28", in: context)
        record(named: "search-recents-filters", container: container)
    }
}
