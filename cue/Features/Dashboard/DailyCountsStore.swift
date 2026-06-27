//
//  DailyCountsStore.swift
//  cue
//

import Foundation
import Observation

/// Fetches the scheduled-occurrence totals per day for the dashboard's
/// completion-rate framing via `GET /tasks/daily-counts`.
///
/// The dashboard's *completions* come from the already-synced `TaskItem` rows
/// (read with `@Query`); this store supplies the *denominator* — how many
/// occurrences were scheduled in the same window — so the report can show "X of Y
/// finished" rather than a bare count. Kept separate from `CalendarStore` (whose
/// per-week counts cache is private and week-keyed) so the dashboard owns a simple
/// arbitrary-range fetch without reaching into calendar internals.
///
/// `@Observable @MainActor`, the shared `APIClient`, and a `bind(notifications:)`
/// for surfacing failures — the same shape as the other feature stores.
@Observable
@MainActor
final class DailyCountsStore {
    /// Cold-load lifecycle. The denominator is non-essential, so a failure
    /// degrades to "no rate" rather than failing the whole screen.
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    // MARK: Private

    private let api: APIClient
    private var notifications: NotificationStore?

    // MARK: Public

    /// Load phase for the denominator fetch.
    private(set) var phase: Phase = .idle

    /// Total scheduled occurrences across the requested window (sum of per-day
    /// counts). Zero until loaded; stays zero on failure.
    private(set) var scheduledTotal: Int = 0

    // MARK: Init

    init(api: APIClient = .shared, notifications: NotificationStore? = nil) {
        self.api = api
        self.notifications = notifications
    }

    /// Wires the global notification queue. Idempotent.
    func bind(notifications: NotificationStore) {
        guard self.notifications == nil else { return }
        self.notifications = notifications
    }

    // MARK: - Read

    /// Loads the scheduled-occurrence total for `[from, to)` and the given
    /// calendar via `GET /tasks/daily-counts`. `calendarId` is the default
    /// calendar's id (read from the synced `EventCalendar` rows). A nil id (no
    /// calendar synced yet) or a failure leaves the total at zero — the rate tile
    /// simply hides.
    func load(calendarId: String?, from: Date, to: Date) async {
        guard let calendarId else {
            phase = .loaded
            scheduledTotal = 0
            return
        }
        if case .loaded = phase {} else {
            phase = .loading
        }

        do {
            let response: DailyCountsResponse = try await api.get(
                "/tasks/daily-counts",
                queryItems: [
                    URLQueryItem(name: "calendarId", value: calendarId),
                    URLQueryItem(name: "from", value: Self.iso.string(from: from)),
                    URLQueryItem(name: "to", value: Self.iso.string(from: to)),
                ]
            )
            scheduledTotal = response.counts.values.reduce(0, +)
            phase = .loaded
        } catch {
            phase = .failed
            scheduledTotal = 0
        }
    }

    // MARK: - Helpers

    /// ISO-8601 formatter matching `CalendarStore.isoFractional`'s wire shape for
    /// the `from`/`to` window bounds.
    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
