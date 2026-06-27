//
//  SyncCursorState.swift
//  cue
//

import Foundation
import SwiftData

/// Durable per-calendar delta-sync cursor. One row per `calendarId`, holding the
/// opaque server cursor (the last `serverTime` the `/tasks/changes` endpoint
/// returned) that the client echoes as `since` on the next foreground-return
/// delta fetch.
///
/// This is the Phase 3 counterpart to ``WindowSyncMeta``: where `WindowSyncMeta`
/// memoizes *per-window* freshness for stale-while-revalidate, this row tracks the
/// *account-wide* change cursor so a foreground return can ask the server "what
/// changed since I last looked?" instead of bluntly invalidating every synced
/// month. It survives relaunch, so the second and later launches reuse the durable
/// cursor rather than re-initializing.
///
/// The cursor is opaque on purpose — today it is the server's ISO-8601 clock
/// timestamp, but the client never parses it, so a later swap to a monotonic
/// `syncVersion` is a server-internal change behind the same shape.
///
/// The schema bump needs no migration plan — the store is a re-syncable cache with
/// a destroy-and-recreate fallback in `cueApp`.
@Model
final class SyncCursorState {
    /// Backend calendar id this cursor belongs to. Unique so a `(calendarId)`
    /// lookup resolves via the unique index and there is exactly one cursor row
    /// per calendar.
    @Attribute(.unique) var calendarId: String
    /// Opaque server cursor — the last `serverTime` returned by `/tasks/changes`,
    /// stored verbatim and echoed back as `since`. Never parsed by the client.
    var cursor: String
    /// Wall-clock time of the most recent successful delta apply, for diagnostics
    /// and a future "how stale is my delta" gate.
    var lastDeltaAt: Date

    init(calendarId: String, cursor: String, lastDeltaAt: Date) {
        self.calendarId = calendarId
        self.cursor = cursor
        self.lastDeltaAt = lastDeltaAt
    }
}
