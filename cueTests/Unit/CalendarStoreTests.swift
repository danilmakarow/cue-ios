//
//  CalendarStoreTests.swift
//  cueTests
//

import Foundation
import SwiftData
import Testing
@testable import cue

/// Unit coverage for ``CalendarStore``'s in-memory, network-free behaviors:
/// the completion-toggle short-circuit, the `revision` change-counter contract,
/// and the durable stale-while-revalidate TTL constants that gate revalidation.
///
/// IMPORTANT — testability seam: `CalendarStore` calls `APIClient.shared`
/// directly (not an injected client), and its core reconciliation helpers
/// (`pruneOccurrences`, `reconcileInFlightCompletions`, `isFresh`, `isStale`,
/// `commit`) are `private`. That means the prune/reconcile/freshness/stale paths
/// described in the test plan CANNOT be exercised directly from this target
/// without either (a) injecting `APIClient` into the store and stubbing
/// `URLProtocol`, or (b) widening those helpers to `internal`. The tests below
/// cover everything reachable through the public surface today; the gaps are
/// enumerated in the suite doc and in the agent's returned notes.
///
/// What IS reachable & tested:
///   - `toggleCompletion(occurrenceKey:)` returns `false` for a key matching no row,
///     short-circuiting BEFORE any `await`/network — so `revision` does not move.
///   - The exposed SWR/stale constants (`windowTTL`, `staleThreshold`, `revision`).
///   - The `WindowSyncMeta` freshness predicate the (private) `isFresh` evaluates,
///     verified against a real persisted in-memory row using the SAME TTL constant
///     the store reads — documenting the absent-row(stale) / fresh / aged-out(stale)
///     truth table without reaching into the private method.
@MainActor
struct CalendarStoreTests {
    // MARK: - Fixtures

    /// Decoder mirroring the app's wire decoder (ISO-8601 dates) so DTO fixtures
    /// decode through the real decoder-only `init(from:)` paths.
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// A minimal `UserDTO` decoded from JSON (the store's init requires one).
    private static func makeUser() throws -> UserDTO {
        let json = """
        {
          "id": "user-1",
          "appleUserId": "apple-1",
          "email": "tony@stark.com",
          "displayName": "Tony",
          "avatarBase64": null,
          "timezone": "UTC",
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-01T00:00:00Z"
        }
        """
        return try makeDecoder().decode(UserDTO.self, from: Data(json.utf8))
    }

    /// An in-memory container holding every `@Model` the store touches.
    private static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: EventCalendar.self,
            TaskItem.self,
            EventTaskGroup.self,
            WindowSyncMeta.self,
            SyncCursorState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeStore() throws -> CalendarStore {
        CalendarStore(user: try Self.makeUser())
    }

    // MARK: - toggleCompletion(occurrenceKey:) short-circuit

    @Test func toggleCompletionReturnsFalseWhenKeyMatchesNoRow() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        let store = try makeStore()

        // Empty store: no TaskItem has this key, so the fetch's `.first` is nil and
        // the method returns false WITHOUT awaiting any network call.
        let result = await store.toggleCompletion(occurrenceKey: "nope#", context: context)
        #expect(result == false)
    }

    @Test func toggleCompletionMissingKeyDoesNotBumpRevision() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        let store = try makeStore()

        // Seed an unrelated row so the table is non-empty but the queried key still
        // misses — proves the miss is by key, not by emptiness.
        let other = TaskItem(
            occurrenceKey: TaskItem.makeKey(seriesId: "other", occurrenceStart: nil),
            seriesId: "other",
            title: "Unrelated"
        )
        context.insert(other)
        try context.save()

        let revisionBefore = store.revision
        let result = await store.toggleCompletion(occurrenceKey: "absent#key", context: context)

        #expect(result == false)
        // No row matched → no optimistic commit → the change-counter stays put, so
        // the UIKit scopes observing `revision` are not needlessly re-fetched.
        #expect(store.revision == revisionBefore)
    }

    @Test func toggleCompletionResolvesRowByExactUniqueKey() async throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)
        let store = try makeStore()

        // A row whose key differs only in the trailing occurrence-start segment must
        // NOT be matched by a bare-series key — the lookup is on the full composite
        // `.unique` occurrenceKey, not a prefix.
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let scheduled = TaskItem(
            occurrenceKey: TaskItem.makeKey(seriesId: "series-x", occurrenceStart: start),
            seriesId: "series-x",
            occurrenceStart: start,
            title: "Scheduled"
        )
        context.insert(scheduled)
        try context.save()

        let revisionBefore = store.revision
        // Query the *non-recurring* form of the same series id — a different key.
        let result = await store.toggleCompletion(
            occurrenceKey: TaskItem.makeKey(seriesId: "series-x", occurrenceStart: nil),
            context: context
        )
        #expect(result == false)
        #expect(store.revision == revisionBefore)
    }

    // MARK: - Exposed SWR / stale constants

    @Test func windowTTLIsFiveMinutes() {
        // The per-window stale-while-revalidate TTL that `isFresh` reads.
        #expect(CalendarStore.windowTTL == 5 * 60)
    }

    @Test func staleThresholdIsThirtySeconds() {
        // The foreground-return "should I even probe" gate that `isStale` reads.
        #expect(CalendarStore.staleThreshold == 30)
    }

    @Test func freshAndStaleThresholdsAreIndependent() {
        // Documented invariant: the foreground gate and the per-window TTL are
        // distinct knobs (30s vs 5min), so a change to one must not collapse onto
        // the other.
        #expect(CalendarStore.windowTTL != CalendarStore.staleThreshold)
        #expect(CalendarStore.windowTTL > CalendarStore.staleThreshold)
    }

    @Test func revisionStartsAtZero() {
        // A freshly constructed store has performed no occurrence-mutating commit.
        let store = try? makeStore()
        #expect(store?.revision == 0)
    }

    // MARK: - WindowSyncMeta freshness truth table (mirrors private `isFresh`)

    // These reconstruct, against a REAL persisted in-memory `WindowSyncMeta` row,
    // the exact comparison `isFresh` performs — `Date.now - lastFetchedAt < windowTTL`
    // — using the store's own `windowTTL` constant. They document the absent /
    // fresh / aged-out truth table. NOTE: they exercise the freshness *math + schema*
    // through the public constant, NOT the private `isFresh(windowKey:in:)` method
    // itself, which is unreachable from this target without a refactor.

    /// Reimplements the freshness predicate `isFresh` applies, keyed off the same
    /// `.unique` `windowKey` and the store's own `windowTTL`. Returns the store's
    /// definition of "fresh" for the given key, or false when no row exists.
    private func windowReadsFresh(windowKey: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<WindowSyncMeta>(
            predicate: #Predicate { $0.windowKey == windowKey }
        )
        guard let meta = (try? context.fetch(descriptor))?.first else { return false }
        return Date.now.timeIntervalSince(meta.lastFetchedAt) < CalendarStore.windowTTL
    }

    @Test func absentWindowMetaReadsStale() throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)

        let key = WindowSyncMeta.makeWindowKey(
            calendarId: "cal-1", scope: .month, anchor: .now
        )
        // Cold launch / evicted: no row → stale → caller revalidates.
        #expect(windowReadsFresh(windowKey: key, in: context) == false)
    }

    @Test func windowMetaFetchedNowReadsFresh() throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)

        let anchor = Date(timeIntervalSince1970: 1_700_000_000)
        let key = WindowSyncMeta.makeWindowKey(calendarId: "cal-1", scope: .month, anchor: anchor)
        context.insert(
            WindowSyncMeta(
                windowKey: key,
                calendarId: "cal-1",
                scope: WindowScope.month.rawValue,
                anchor: anchor,
                lastFetchedAt: .now
            )
        )
        try context.save()

        // Just-fetched window is within TTL → fresh → revalidate short-circuits.
        #expect(windowReadsFresh(windowKey: key, in: context) == true)
    }

    @Test func windowMetaOlderThanTTLReadsStale() throws {
        let container = try Self.makeContainer()
        let context = ModelContext(container)

        let anchor = Date(timeIntervalSince1970: 1_700_000_000)
        let key = WindowSyncMeta.makeWindowKey(calendarId: "cal-1", scope: .month, anchor: anchor)
        // One second past the TTL boundary — must read stale.
        let aged = Date.now.addingTimeInterval(-(CalendarStore.windowTTL + 1))
        context.insert(
            WindowSyncMeta(
                windowKey: key,
                calendarId: "cal-1",
                scope: WindowScope.month.rawValue,
                anchor: anchor,
                lastFetchedAt: aged
            )
        )
        try context.save()

        #expect(windowReadsFresh(windowKey: key, in: context) == false)
    }
}
