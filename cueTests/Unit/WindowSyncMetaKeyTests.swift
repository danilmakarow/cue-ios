//
//  WindowSyncMetaKeyTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// Exercises ``WindowSyncMeta/makeWindowKey(calendarId:scope:anchor:)`` — the single
/// source of the composite `windowKey` format that backs the `.unique` constraint
/// and the SWR memo lookups. The key shape is `"<calendarId>#<scope.rawValue>#<ISO8601 anchor>"`.
@MainActor
struct WindowSyncMetaKeyTests {
    private let calendar = Calendar.current

    @Test func keyHasExpectedCompositeShape() {
        let anchor = startOfMonth(year: 2026, month: 5)
        let key = WindowSyncMeta.makeWindowKey(calendarId: "cal-123", scope: .month, anchor: anchor)

        let components = key.split(separator: "#", omittingEmptySubsequences: false)
        #expect(components.count == 3)
        #expect(components[0] == "cal-123")
        #expect(components[1] == "month")

        let expectedAnchor = ISO8601DateFormatter().string(from: anchor)
        #expect(String(components[2]) == expectedAnchor)
        #expect(key == "cal-123#month#\(expectedAnchor)")
    }

    @Test func sameInputsProduceIdenticalKey() {
        let anchor = startOfMonth(year: 2026, month: 5)
        let first = WindowSyncMeta.makeWindowKey(calendarId: "cal-A", scope: .month, anchor: anchor)
        let second = WindowSyncMeta.makeWindowKey(calendarId: "cal-A", scope: .month, anchor: anchor)

        // Determinism is what drives the .unique constraint + SWR memo hit.
        #expect(first == second)
    }

    @Test func differentScopesForSameCalendarAndAnchorYieldDistinctKeys() {
        let anchor = startOfMonth(year: 2026, month: 5)
        let monthKey = WindowSyncMeta.makeWindowKey(calendarId: "cal-A", scope: .month, anchor: anchor)
        let countsKey = WindowSyncMeta.makeWindowKey(calendarId: "cal-A", scope: .countsWeek, anchor: anchor)
        let yearMonthKey = WindowSyncMeta.makeWindowKey(calendarId: "cal-A", scope: .yearMonth, anchor: anchor)

        let keys = Set([monthKey, countsKey, yearMonthKey])
        #expect(keys.count == 3)
    }

    @Test func differentCalendarsForSameScopeAndAnchorYieldDistinctKeys() {
        let anchor = startOfMonth(year: 2026, month: 5)
        let first = WindowSyncMeta.makeWindowKey(calendarId: "cal-A", scope: .month, anchor: anchor)
        let second = WindowSyncMeta.makeWindowKey(calendarId: "cal-B", scope: .month, anchor: anchor)

        #expect(first != second)
    }

    @Test func differentAnchorsForSameCalendarAndScopeYieldDistinctKeys() {
        let mayAnchor = startOfMonth(year: 2026, month: 5)
        let juneAnchor = startOfMonth(year: 2026, month: 6)
        let mayKey = WindowSyncMeta.makeWindowKey(calendarId: "cal-A", scope: .month, anchor: mayAnchor)
        let juneKey = WindowSyncMeta.makeWindowKey(calendarId: "cal-A", scope: .month, anchor: juneAnchor)

        #expect(mayKey != juneKey)
    }

    @Test func subSecondAnchorDifferencesCollapseToSameKey() {
        // The formatter uses whole-second precision (no fractional seconds), so two
        // anchors differing only sub-second produce the SAME key. Real anchors are
        // always day/month/week starts, so this never bites in practice — but it
        // guarantees the memo lookup is robust to float drift on the anchor.
        let base = startOfMonth(year: 2026, month: 5)
        let nudged = base.addingTimeInterval(0.4)

        let baseKey = WindowSyncMeta.makeWindowKey(calendarId: "cal-A", scope: .month, anchor: base)
        let nudgedKey = WindowSyncMeta.makeWindowKey(calendarId: "cal-A", scope: .month, anchor: nudged)

        #expect(baseKey == nudgedKey)
    }

    @Test func wholeSecondAnchorDifferencesProduceDistinctKeys() {
        // Conversely, a full-second difference IS reflected in the key.
        let base = startOfMonth(year: 2026, month: 5)
        let nextSecond = base.addingTimeInterval(1)

        let baseKey = WindowSyncMeta.makeWindowKey(calendarId: "cal-A", scope: .month, anchor: base)
        let nextSecondKey = WindowSyncMeta.makeWindowKey(calendarId: "cal-A", scope: .month, anchor: nextSecond)

        #expect(baseKey != nextSecondKey)
    }

    @Test func startOfMonthAnchorRoundTripsThroughKey() {
        let anchor = startOfMonth(year: 2026, month: 5)
        let key = WindowSyncMeta.makeWindowKey(calendarId: "cal-A", scope: .month, anchor: anchor)

        guard let isoComponent = key.split(separator: "#", omittingEmptySubsequences: false).last else {
            Issue.record("key had no anchor component")
            return
        }
        guard let parsed = ISO8601DateFormatter().date(from: String(isoComponent)) else {
            Issue.record("anchor component did not parse as ISO-8601")
            return
        }

        // Month-start anchors land on a whole second, so they survive the
        // string round-trip exactly.
        #expect(parsed == anchor)
    }

    @Test func startOfDayAnchorRoundTripsThroughKey() {
        let anchor = startOfDay(year: 2026, month: 5, day: 26)
        let key = WindowSyncMeta.makeWindowKey(calendarId: "cal-A", scope: .countsWeek, anchor: anchor)

        guard let isoComponent = key.split(separator: "#", omittingEmptySubsequences: false).last else {
            Issue.record("key had no anchor component")
            return
        }
        guard let parsed = ISO8601DateFormatter().date(from: String(isoComponent)) else {
            Issue.record("anchor component did not parse as ISO-8601")
            return
        }

        #expect(parsed == anchor)
    }

    @Test func keyMatchesPersistedRowWindowKey() throws {
        // The key the factory builds is exactly what the .unique-constrained
        // windowKey property carries on a row, so a memo lookup by the factory
        // output finds the persisted row.
        let anchor = startOfMonth(year: 2026, month: 5)
        let key = WindowSyncMeta.makeWindowKey(calendarId: "cal-A", scope: .yearMonth, anchor: anchor)
        let row = WindowSyncMeta(
            windowKey: key,
            calendarId: "cal-A",
            scope: WindowScope.yearMonth.rawValue,
            anchor: anchor,
            lastFetchedAt: .now
        )

        #expect(row.windowKey == key)
        #expect(row.calendarId == "cal-A")
        #expect(row.scope == "yearMonth")

        let rebuilt = WindowSyncMeta.makeWindowKey(calendarId: row.calendarId, scope: .yearMonth, anchor: row.anchor)
        #expect(rebuilt == row.windowKey)
    }

    /// Midnight-of-month-start anchor, the shape month/yearMonth scopes use.
    private func startOfMonth(year: Int, month: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return calendar.date(from: components) ?? .now
    }

    /// Midnight-of-day anchor, the shape the counts-week scope uses.
    private func startOfDay(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? .now
    }
}
