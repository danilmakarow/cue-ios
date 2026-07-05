//
//  SyncHeartbeat.swift
//  cue
//

import Foundation
import SwiftData

/// Drives the periodic foreground sync heartbeat. While started, it wakes roughly
/// every ``CalendarStore/heartbeatInterval`` seconds (±20% jitter to avoid a
/// synchronized fleet) and asks the shared ``CalendarStore`` to run one
/// `heartbeatTick` — the cheap `GET /sync/state` check that only escalates to a
/// full delta + visible-window re-pull when the server revision actually moved.
///
/// Kept out of `CalendarStore` so the ticker lifecycle (start on foreground, stop
/// on background) is owned by the view layer and the store stays a pure sync
/// engine. `start()`/`stop()` are idempotent.
@MainActor
final class SyncHeartbeat {
    private var loop: Task<Void, Never>?

    /// Starts the periodic heartbeat against `store`, using `context` for each
    /// tick's SwiftData reads/writes. No-op if already running.
    func start(store: CalendarStore, context: ModelContext) {
        guard loop == nil else { return }

        loop = Task { [weak store] in
            while !Task.isCancelled {
                let jitter = Double.random(in: 0.8...1.2)
                let delay = CalendarStore.heartbeatInterval * jitter

                try? await Task.sleep(for: .seconds(delay))
                if Task.isCancelled { break }

                guard let store else { break }
                await store.heartbeatTick(context: context)
            }
        }
    }

    /// Stops the heartbeat. Safe to call when not running.
    func stop() {
        loop?.cancel()
        loop = nil
    }
}
