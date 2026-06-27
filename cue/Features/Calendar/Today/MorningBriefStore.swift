//
//  MorningBriefStore.swift
//  cue
//

import Foundation
import Observation

/// Loads and caches the AI-generated *morning brief* the Today screen renders via
/// `GET /users/me/daily-brief` (``APIClient/dailyBrief(date:)``).
///
/// The brief is a *non-essential* ritual card: a load failure (or an empty brief)
/// degrades gracefully to a quiet placeholder rather than failing the whole Today
/// screen — the same "the denominator can fail" posture as ``DailyCountsStore``.
/// Once a brief lands for a given local date it is cached for the session, so
/// re-entering the Today tab doesn't re-hit the network for the same day.
///
/// `@Observable @MainActor`, the shared `APIClient`, and a `bind(notifications:)`
/// for surfacing failures — the same shape as the other feature stores.
@Observable
@MainActor
final class MorningBriefStore {
    /// Cold-load lifecycle of the brief fetch.
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    // MARK: Private

    private let api: APIClient
    private var notifications: NotificationStore?

    /// The local date (`YYYY-MM-DD`) the cached `brief` covers, so a day rollover
    /// invalidates the cache and re-fetches.
    private var cachedDate: String?

    // MARK: Public

    /// Load phase for the brief fetch.
    private(set) var phase: Phase = .idle

    /// The generated brief text, or nil when the day yielded nothing usable (an
    /// empty brief is a valid `.loaded` state, rendered as the calm placeholder).
    private(set) var brief: String?

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

    /// Loads (or serves from cache) the brief for `date`'s local day. Pass the
    /// screen's reference day; the wire key is its `YYYY-MM-DD` in the current
    /// locale, matching the backend's per-day cache. Re-entry for an already-loaded
    /// day short-circuits. A failure leaves any prior brief in place and flips to
    /// `.failed` so the card can offer a quiet retry.
    func load(for date: Date = .now, force: Bool = false) async {
        let key = Self.dayKey(for: date)
        if !force, cachedDate == key, phase == .loaded { return }

        phase = .loading
        do {
            let response = try await api.dailyBrief(date: key)
            brief = response.brief
            cachedDate = response.localDate
            phase = .loaded
        } catch {
            phase = .failed
            // Non-fatal: the card degrades, but surface it so it isn't silent.
            notifications?.postError(error, title: "Couldn't load your brief")
        }
    }

    // MARK: - Helpers

    /// The `YYYY-MM-DD` local-day key (current calendar/locale) the brief is keyed
    /// by, matching ``APIClient/dailyBrief(date:)``'s expected shape.
    private static func dayKey(for date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
