//
//  WindowSyncMeta.swift
//  cue
//

import Foundation
import SwiftData

/// The scope a ``WindowSyncMeta`` row memoizes. Its `rawValue` is stored on the
/// row so the composite `windowKey` and any scope-filtered query stay typo-proof
/// — always build keys and predicates from these cases, never a bare string.
enum WindowScope: String {
    case month = "month"
    case countsWeek = "countsWeek"
    case yearMonth = "yearMonth"
}

/// Durable per-(calendar, scope, anchor) sync memo. This row IS the
/// stale-while-revalidate memo that replaces the old in-memory `syncedMonths` /
/// `syncedCountWindows` sets: it survives relaunch (so a revisited window renders
/// instantly from persisted `TaskItem` rows) and it is time-aware via
/// `lastFetchedAt` (so a stale window revalidates quietly behind already-rendered
/// data).
///
/// The store reads `lastFetchedAt` against a per-window TTL to decide whether to
/// hit the network; on a successful fetch it upserts the row in the *same commit*
/// as the pruned/upserted occurrences, so the memo and the data it vouches for
/// never drift. `serverCursor` is reserved for Phase 3 (opaque pagination/sync
/// token) and stays nil here.
///
/// The schema bump needs no migration plan — the store is a re-syncable cache
/// with a destroy-and-recreate fallback in `cueApp`.
@Model
final class WindowSyncMeta {
    /// Composite index matching the store's lookup shape (calendar + anchor),
    /// so a `(calendarId, anchor)`-narrowed fetch walks the index rather than the
    /// whole table.
    #Index<WindowSyncMeta>([\.calendarId, \.anchor])

    /// Composite unique key `"\(calendarId)#\(scope)#\(isoAnchor)"`.
    /// This is what SwiftData indexes for uniqueness; build it via
    /// ``makeWindowKey(calendarId:scope:anchor:)`` so the format never diverges.
    @Attribute(.unique) var windowKey: String
    /// Backend calendar id this window belongs to.
    var calendarId: String
    /// `WindowScope` raw value: `"month" | "countsWeek" | "yearMonth"`.
    var scope: String
    /// Window anchor — `startOfMonth` for month/yearMonth scopes, `startOfWeek`
    /// for the counts scope.
    var anchor: Date
    /// Wall-clock time of the most recent successful fetch for this window.
    /// Read against the per-window TTL to gate revalidation.
    var lastFetchedAt: Date
    /// Opaque server sync cursor — reserved for Phase 3, nil until then.
    var serverCursor: String?

    init(
        windowKey: String,
        calendarId: String,
        scope: String,
        anchor: Date,
        lastFetchedAt: Date,
        serverCursor: String? = nil
    ) {
        self.windowKey = windowKey
        self.calendarId = calendarId
        self.scope = scope
        self.anchor = anchor
        self.lastFetchedAt = lastFetchedAt
        self.serverCursor = serverCursor
    }

    /// Stable ISO-8601 formatter for the anchor component of `windowKey`. Default
    /// options (no fractional seconds); anchors are day/month/week starts so
    /// second precision is ample, and a shared instance avoids per-window churn.
    private static let anchorFormatter = ISO8601DateFormatter()

    /// Builds the composite `windowKey` from a calendar id, typed scope, and
    /// anchor date — the single source of the key format, keyed off the enum so a
    /// scope string can never be mistyped.
    static func makeWindowKey(calendarId: String, scope: WindowScope, anchor: Date) -> String {
        "\(calendarId)#\(scope.rawValue)#\(anchorFormatter.string(from: anchor))"
    }
}
