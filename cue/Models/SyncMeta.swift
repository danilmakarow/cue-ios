//
//  SyncMeta.swift
//  cue
//

import Foundation
import SwiftData

/// Durable single-row store for the account-wide sync watermark: the last per-user
/// `revision` the client has fully applied (via a successful `/tasks/changes`
/// delta), plus the timestamp of the last full reconciliation.
///
/// Deliberately separate from ``SyncCursorState`` (whose row the delta-failure path
/// deletes, and whose `cursor` is non-optional): the revision watermark must
/// survive a cursor reset, and it is only advanced after a delta round-trip
/// actually succeeds — so a lost/failed delta leaves it unchanged and the next
/// heartbeat retries. `lastFullReconcileAt` lives here too so a network blip that
/// clears the cursor never resets or postpones the 24h reconcile clock.
///
/// One logical row; keyed by a fixed `id` so the lookup resolves via the unique
/// index and a second insert can never create a duplicate. The schema bump needs
/// no migration plan — the store is a re-syncable cache with a destroy-and-recreate
/// fallback in `cueApp`.
@Model
final class SyncMeta {
    /// Fixed identity for the singleton row.
    static let singletonId = "sync-meta"

    /// Always ``singletonId`` — unique so there is exactly one row.
    @Attribute(.unique) var id: String
    /// The last per-user revision the client fully applied, or nil before the
    /// first successful delta. Compared for EQUALITY against `GET /sync/state`.
    var lastSeenRevision: String?
    /// Wall-clock time of the last full reconciliation, or nil if never run.
    var lastFullReconcileAt: Date?

    init(
        id: String = SyncMeta.singletonId,
        lastSeenRevision: String? = nil,
        lastFullReconcileAt: Date? = nil
    ) {
        self.id = id
        self.lastSeenRevision = lastSeenRevision
        self.lastFullReconcileAt = lastFullReconcileAt
    }
}
