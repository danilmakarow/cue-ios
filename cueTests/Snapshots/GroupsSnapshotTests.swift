//
//  GroupsSnapshotTests.swift
//  cueTests
//
//  Storybook-style snapshot tests for `GroupsScreen` — the task-group management
//  list reachable from Settings. Renders the seeded SwiftData store (the screen's
//  `.task` network fetch is best-effort and does not block the synchronous
//  capture). Two states per the design reference (Groups.dc.html):
//    • empty     — no groups → EmptyStateView ("No Groups" + create CTA)
//    • populated — several groups with distinct icons/colors, one recurring
//

import SwiftData
import SwiftUI
import Testing
@testable import cue

@MainActor
struct GroupsSnapshotTests {
    /// Empty state: no groups seeded → `GroupsScreen` shows the `EmptyStateView`
    /// with the folder glyph, "No Groups" copy, and the create-first-group CTA.
    @Test func empty() {
        let container = MockData.container()

        let screen = NavigationStack {
            GroupsScreen()
        }

        #expect(
            SnapshotHarness.record(
                ScreenHost.wrap(screen, container: container),
                named: "groups-empty"
            ) != nil
        )
    }

    /// Populated state: several groups with distinct SF Symbol icons and colors
    /// (one carrying a default recurrence rule, so its row shows the "Recurring"
    /// label) — mirrors the design's briefcase / cart / dumbbell / book / heart row.
    @Test func populated() {
        let container = MockData.container()
        let context = container.mainContext

        let specs: [(id: String, name: String, color: String, icon: String, recurring: Bool)] = [
            ("grp-work", "Work", "#3B82F6", "briefcase", false),
            ("grp-shopping", "Shopping", "#BE4A28", "cart", false),
            ("grp-fitness", "Fitness", "#466234", "dumbbell", true),
            ("grp-reading", "Reading", "#8B5CF6", "book", false),
            ("grp-health", "Health & Wellbeing", "#E11D48", "heart", false),
        ]

        for (index, spec) in specs.enumerated() {
            let group = MockData.group(
                id: spec.id,
                name: spec.name,
                color: spec.color,
                in: context
            )
            group.icon = spec.icon
            group.sortOrder = index
            if spec.recurring {
                group.defaultRecurrenceRuleId = "rule-\(spec.id)"
            }
        }
        // Deliberately NOT calling `context.save()`. The screen's `@Query` reads
        // the `mainContext` including these pending inserts, so the populated
        // rows render without a save. Saving here posts a process-wide SwiftData
        // change notification that any `@Query` left alive by a prior snapshot
        // capture (bound to *that* test's now-released container) observes and
        // re-fetches against a foreign context, tripping an intermittent trap
        // inside SwiftData. Skipping the save removes that cross-test wakeup.

        let screen = NavigationStack {
            GroupsScreen()
        }

        #expect(
            SnapshotHarness.record(
                ScreenHost.wrap(screen, container: container),
                named: "groups-populated"
            ) != nil
        )
    }
}
