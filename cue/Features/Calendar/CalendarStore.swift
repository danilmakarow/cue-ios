//
//  CalendarStore.swift
//  cue
//

import Foundation
import Observation
import SwiftData

/// Single source of truth for the Calendar tab, shared across the year,
/// month and day scopes via `@Environment`.
///
/// Owns the user's *selection* (`selectedDate`, `viewMode`) and the
/// API → SwiftData *sync coordination*. Events live in SwiftData and are
/// read reactively by scope views through `@Query`. Sync methods take the
/// `ModelContext` from the calling view.
@Observable
@MainActor
final class CalendarStore {
    var selectedDate: Date
    var viewMode: CalendarViewMode
    private(set) var isLoading: Bool = false

    /// Monotonically-increasing data-change counter. Bumped after every
    /// occurrence-mutating `context.save()` (sync, completion toggle, delete).
    /// The UIKit calendar scopes observe this with `withObservationTracking`
    /// instead of a SwiftUI `@Query`, re-running their windowed fetch and
    /// re-applying a diffable snapshot whenever it changes. It is the single
    /// reactivity edge between SwiftData mutations and the UIKit surface.
    private(set) var revision: Int = 0

    /// How long data may sit untouched before a foreground return is allowed to
    /// refetch it. A short inactive→active blip within this window is ignored.
    /// This is the "should I even probe" gate (see `refreshIfStale`).
    static let staleThreshold: TimeInterval = 30

    /// Per-window stale-while-revalidate TTL. A window whose `WindowSyncMeta`
    /// `lastFetchedAt` is younger than this is considered fresh, so its
    /// `ensure*Synced` revalidate short-circuits without touching the network.
    /// Independent of `staleThreshold`: the foreground-return gate decides
    /// *whether* to probe at all; this decides, per window, *whether the probe
    /// fetches*. A cold launch has no meta row, so every window reads as stale and
    /// revalidates once — then the durable row keeps the next launch quiet.
    static let windowTTL: TimeInterval = 5 * 60

    /// Wall-clock time of the most recent *successful* month fetch.
    private(set) var lastSyncedAt: Date?

    private let user: UserDTO
    private var notifications: NotificationStore?
    private var calendarId: String?
    private var refreshTask: Task<Void, Never>?

    /// Per-day task-occurrence counts keyed by `startOfDay`, populated by
    /// ``ensureCountsSynced(weekRange:context:)`` and read by the day-view week
    /// strip to draw per-tile badges. Cleared on every occurrence mutation so the
    /// next strip refresh reflects the change.
    private(set) var dayCountsCache: [Date: Int] = [:]

    /// Date-only key parser for the daily-counts response (`YYYY-MM-DD` in the
    /// calendar's locale), mapped back to a `startOfDay` cache key.
    private static let countsDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Occurrence keys with a completion toggle in flight, mapped to the pending
    /// optimistic `completedAt` value. While a key is present here, a concurrent
    /// `ensureMonthSynced` must NOT prune its row and must reconcile the
    /// optimistic value back onto the freshly-upserted row — otherwise the
    /// prune-then-reinsert would replace the optimistic row with a server row
    /// that doesn't yet reflect the toggle (completion is a separate endpoint),
    /// flipping the checkmark back. See `toggleCompletion` and `ensureMonthSynced`.
    private var inFlightCompletions: [String: Date?] = [:]

    /// Lossless ISO-8601 formatter with fractional seconds. Used both for query
    /// bounds and — critically — for the completion/skip occurrence key, which
    /// must preserve millisecond precision to match the backend exception key
    /// (the shared `APIClient` `.iso8601` encoder truncates milliseconds).
    static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(
        user: UserDTO,
        notifications: NotificationStore? = nil,
        today: Date = Calendar.current.startOfDay(for: .now)
    ) {
        self.user = user
        self.notifications = notifications
        self.selectedDate = today
        self.viewMode = .timeline
    }

    /// Wires the global notification queue. Idempotent — only binds the first time.
    func bind(notifications: NotificationStore) {
        guard self.notifications == nil else { return }
        self.notifications = notifications
    }

    // MARK: - Sync

    /// Ensures the month containing `day` is synced.
    func ensureDaySynced(_ day: Date, context: ModelContext) async {
        await ensureMonthSynced(CalendarMath.startOfMonth(day), context: context)
    }

    /// Revalidates the month containing `monthAnchor` under stale-while-revalidate.
    ///
    /// The scope views already SERVE persisted occurrences instantly from their
    /// own windowed SwiftData reads, so this method is purely the revalidate side:
    /// it DECIDEs via the durable ``WindowSyncMeta`` memo (skip when the window was
    /// fetched within ``windowTTL``), then REVALIDATEs by fetching, pruning,
    /// upserting, reconciling in-flight completions, and upserting the meta row —
    /// all in one atomic commit. Cold launch / a far-scrolled revisit has no fresh
    /// meta row, so it revalidates once; a within-TTL repeat short-circuits.
    /// External signature is unchanged so Phase 1's `PrefetchCoordinator` routing
    /// is unaffected.
    func ensureMonthSynced(_ monthAnchor: Date, context: ModelContext) async {
        let anchor = CalendarMath.startOfMonth(monthAnchor)

        isLoading = true
        defer { isLoading = false }

        do {
            let calendarId = try await ensureDefaultCalendarId(context: context)
            // DECIDE: the durable meta row is the memo. Skip the network while fresh.
            let windowKey = WindowSyncMeta.makeWindowKey(
                calendarId: calendarId, scope: .month, anchor: anchor
            )
            guard !isFresh(windowKey: windowKey, in: context) else { return }

            let (from, to) = CalendarMath.monthBounds(anchor)
            let occurrences: [OccurrenceDTO] = try await APIClient.shared.get(
                "/tasks",
                queryItems: [
                    URLQueryItem(name: "calendarId", value: calendarId),
                    URLQueryItem(name: "from", value: Self.isoFractional.string(from: from)),
                    URLQueryItem(name: "to", value: Self.isoFractional.string(from: to)),
                ]
            )

            // Prune stale occurrences in the fetched window before upserting fresh ones.
            // This ensures skipped/deleted/edited occurrences disappear from the local DB.
            // In-flight optimistic completions are preserved (not pruned).
            pruneOccurrences(in: from..<to, context: context)

            for dto in occurrences {
                TaskItem.upsert(from: dto, in: context)
            }
            // Re-apply any in-flight optimistic completion onto the just-upserted
            // server rows, so a concurrent toggle isn't clobbered by a server
            // row that doesn't yet reflect it (separate completion endpoint).
            reconcileInFlightCompletions(context: context)
            // Stamp the durable memo in the SAME commit as the pruned/upserted rows
            // so meta and the data it vouches for never drift.
            upsertWindowSyncMeta(
                windowKey: windowKey, calendarId: calendarId, scope: .month, anchor: anchor, context: context
            )
            commit(context)
            lastSyncedAt = .now
        } catch {
            notifications?.postError(error, title: String(localized: "calendar.error.loadTasks"))
        }
    }

    // MARK: - WindowSyncMeta (durable SWR memo)

    /// True when a fresh ``WindowSyncMeta`` row exists for `windowKey` — i.e. its
    /// `lastFetchedAt` is within ``windowTTL``. Absent row (cold launch / evicted)
    /// reads as stale, so the caller revalidates. The lookup is keyed off the
    /// `.unique` `windowKey`, so it resolves via the unique index.
    private func isFresh(windowKey: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<WindowSyncMeta>(
            predicate: #Predicate { $0.windowKey == windowKey }
        )
        guard let meta = (try? context.fetch(descriptor))?.first else { return false }
        return Date.now.timeIntervalSince(meta.lastFetchedAt) < Self.windowTTL
    }

    /// Inserts or refreshes the durable memo row for a window, stamping
    /// `lastFetchedAt = now`. Does NOT save — the caller folds it into the same
    /// `commit(context)` as the occurrence prune/upsert so the row and the data it
    /// vouches for land atomically. `serverCursor` stays nil until Phase 3.
    private func upsertWindowSyncMeta(
        windowKey: String,
        calendarId: String,
        scope: WindowScope,
        anchor: Date,
        context: ModelContext
    ) {
        let descriptor = FetchDescriptor<WindowSyncMeta>(
            predicate: #Predicate { $0.windowKey == windowKey }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.lastFetchedAt = .now
            return
        }
        context.insert(
            WindowSyncMeta(
                windowKey: windowKey,
                calendarId: calendarId,
                scope: scope.rawValue,
                anchor: anchor,
                lastFetchedAt: .now
            )
        )
    }

    /// Removes `TaskItem` occurrences whose `occurrenceStart` falls within
    /// `range`, so stale data from edits/deletes/skips doesn't linger. Skips any
    /// occurrence with a completion toggle in flight (`inFlightCompletions`) so a
    /// concurrent optimistic update survives the prune.
    private func pruneOccurrences(in range: Range<Date>, context: ModelContext) {
        let from = range.lowerBound
        let to = range.upperBound
        // Bounded fetch: a predicate-filtered query of just the window's rows
        // rather than materializing the whole table and filtering in Swift. The
        // optional start is coalesced to `.distantPast` to keep the predicate a
        // single expression (the macro's requirement); occurrence-less rows land
        // below any real range and are excluded, which is correct.
        let sentinel = Date.distantPast
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { task in
                (task.occurrenceStart ?? sentinel) >= from &&
                (task.occurrenceStart ?? sentinel) < to
            }
        )
        let windowed = (try? context.fetch(descriptor)) ?? []
        for item in windowed {
            // Use key membership (not subscript == nil) — the value type is `Date?`,
            // so an in-flight "mark incomplete" entry is stored as `.some(nil)` and
            // must still count as in-flight.
            guard !inFlightCompletions.keys.contains(item.occurrenceKey) else { continue }
            context.delete(item)
        }
    }

    /// Re-applies pending optimistic completion values onto whatever rows are
    /// currently present for the in-flight occurrence keys, so a resync that ran
    /// mid-toggle doesn't leave the server's (stale) completion state on screen.
    private func reconcileInFlightCompletions(context: ModelContext) {
        guard !inFlightCompletions.isEmpty else { return }
        for (key, optimisticCompletedAt) in inFlightCompletions {
            let descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.occurrenceKey == key }
            )
            if let row = (try? context.fetch(descriptor))?.first {
                row.completedAt = optimisticCompletedAt
            }
        }
    }

    /// Persists pending occurrence changes and bumps `revision` so the UIKit
    /// scopes observing it re-fetch. Use for every occurrence-mutating save
    /// (sync, completion toggle, delete); calendar-resolution saves stay bare
    /// `context.save()` since they don't change visible occurrences.
    private func commit(_ context: ModelContext) {
        // Occurrences changed: drop cached per-day counts AND their durable
        // countsWeek memos so the next strip refresh (driven off `revision`)
        // re-fetches the visible week's totals. Folded into THIS save so the
        // memo deletes commit atomically with the occurrence change.
        invalidateDayCounts(context: context)
        try? context.save()
        revision &+= 1
    }

    // MARK: - Daily counts

    /// Drops the in-memory per-day counts cache and deletes every durable
    /// `countsWeek` ``WindowSyncMeta`` memo, so any occurrence mutation forces a
    /// fresh count fetch. Called from `commit`; does NOT save — the caller folds
    /// the meta deletes into its own commit so cache and memo clear together.
    private func invalidateDayCounts(context: ModelContext) {
        dayCountsCache.removeAll()
        deleteCountsWeekMetas(in: context)
    }

    /// Deletes all `countsWeek`-scoped ``WindowSyncMeta`` rows. Does NOT save — the
    /// caller commits. Shared by `invalidateDayCounts` and the per-week count
    /// eviction.
    private func deleteCountsWeekMetas(in context: ModelContext) {
        let scope = WindowScope.countsWeek.rawValue
        let descriptor = FetchDescriptor<WindowSyncMeta>(
            predicate: #Predicate { $0.scope == scope }
        )
        let metas = (try? context.fetch(descriptor)) ?? []
        for meta in metas {
            context.delete(meta)
        }
    }

    /// Fetches per-day occurrence counts for the locale week `weekRange` (plus a
    /// ±1-week load-ahead margin) and merges them into `dayCountsCache`, keyed by
    /// `startOfDay`. Memoized per week-start in the durable `countsWeek`
    /// ``WindowSyncMeta`` rows (TTL-gated by ``windowTTL``), so repeated calls for
    /// an already-fetched (visible/adjacent) week skip the network — and a relaunch
    /// stays quiet until the week goes stale. Failures are surfaced as a non-fatal
    /// notification; the cache simply stays sparse (tiles hide their badge), and a
    /// later call retries.
    ///
    /// Note: the in-memory `dayCountsCache` and the durable memo are coupled —
    /// `invalidateDayCounts` clears both, and `evictStaleDayCounts` drops both per
    /// evicted week — so a "fresh" meta can never vouch for a cache hole.
    func ensureCountsSynced(weekRange: ClosedRange<Date>, context: ModelContext) async {
        let calendar = Calendar.current
        let centerStart = CalendarMath.startOfDay(weekRange.lowerBound)
        // Visible week + one week either side (load-ahead).
        let weekStarts: [Date] = (-1...1).compactMap { offset in
            calendar.date(byAdding: .day, value: offset * 7, to: centerStart)
        }

        do {
            let calendarId = try await ensureDefaultCalendarId(context: context)
            // DECIDE per week: only fetch weeks whose durable memo is stale/absent.
            let pending = weekStarts.filter { start in
                let key = WindowSyncMeta.makeWindowKey(
                    calendarId: calendarId, scope: .countsWeek, anchor: start
                )
                return !isFresh(windowKey: key, in: context)
            }
            guard !pending.isEmpty, let from = pending.first else { return }
            let lastStart = pending.last ?? from
            guard let to = calendar.date(byAdding: .day, value: 7, to: lastStart) else { return }

            let response: DailyCountsResponse = try await APIClient.shared.get(
                "/tasks/daily-counts",
                queryItems: [
                    URLQueryItem(name: "calendarId", value: calendarId),
                    URLQueryItem(name: "from", value: Self.isoFractional.string(from: from)),
                    URLQueryItem(name: "to", value: Self.isoFractional.string(from: to)),
                ]
            )
            mergeCounts(
                response.counts,
                weekStarts: pending,
                range: from..<to,
                calendarId: calendarId,
                context: context
            )
        } catch {
            notifications?.postError(error, title: String(localized: "calendar.error.loadTasks"))
        }
    }

    /// Merges a `YYYY-MM-DD → count` response into `dayCountsCache`. Every day in
    /// the fetched window is written (defaulting to 0 for omitted zero-count days)
    /// so stale non-zero values don't linger, and each fetched week is memoized by
    /// upserting its durable `countsWeek` ``WindowSyncMeta`` row.
    private func mergeCounts(
        _ counts: [String: Int],
        weekStarts: [Date],
        range: Range<Date>,
        calendarId: String,
        context: ModelContext
    ) {
        let calendar = Calendar.current
        var cursor = range.lowerBound
        while cursor < range.upperBound {
            dayCountsCache[CalendarMath.startOfDay(cursor)] = 0
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        for (key, count) in counts {
            guard let date = Self.countsDateFormatter.date(from: key) else { continue }
            dayCountsCache[CalendarMath.startOfDay(date)] = count
        }
        for start in weekStarts {
            let windowKey = WindowSyncMeta.makeWindowKey(
                calendarId: calendarId, scope: .countsWeek, anchor: start
            )
            upsertWindowSyncMeta(
                windowKey: windowKey, calendarId: calendarId, scope: .countsWeek, anchor: start, context: context
            )
        }
        // Persist the memo upserts. This is NOT an occurrence mutation, so it does
        // not go through `commit` (no revision bump, no count invalidation).
        try? context.save()
        evictStaleDayCounts(context: context)
    }

    /// Caps `dayCountsCache` at ~12 week-windows (180 days) by dropping the
    /// oldest-keyed entries when it grows past the limit. The ±2-week prefetch in
    /// the day strip grows this faster than the old visible-only fetch, so an LRU
    /// (here, oldest-date-first) bound keeps memory steady across a long scroll.
    /// The cap (180) is far larger than any one strip view (7 days) plus its ±2-week
    /// prefetch buffer (35 days), so eviction never touches an in-flight week. When
    /// a week is evicted its durable `countsWeek` ``WindowSyncMeta`` memo is deleted
    /// too — in the same `context.save()` already performed by `mergeCounts` — so a
    /// later scroll back re-fetches rather than trusting an evicted hole.
    private func evictStaleDayCounts(context: ModelContext) {
        let limit = 180
        guard dayCountsCache.count > limit else { return }
        let sortedKeys = dayCountsCache.keys.sorted()
        let removeCount = dayCountsCache.count - limit
        let calendar = Calendar.current
        var didDeleteMeta = false
        for key in sortedKeys.prefix(removeCount) {
            dayCountsCache.removeValue(forKey: key)
            // Drop the durable memo for the week this day belonged to so a scroll
            // back re-fetches rather than trusting an evicted hole.
            let weekday = calendar.component(.weekday, from: key)
            let delta = (weekday - calendar.firstWeekday + 7) % 7
            guard let weekStart = calendar.date(byAdding: .day, value: -delta, to: key) else { continue }
            let anchor = CalendarMath.startOfDay(weekStart)
            let scope = WindowScope.countsWeek.rawValue
            let descriptor = FetchDescriptor<WindowSyncMeta>(
                predicate: #Predicate { $0.scope == scope && $0.anchor == anchor }
            )
            for meta in (try? context.fetch(descriptor)) ?? [] {
                context.delete(meta)
                didDeleteMeta = true
            }
        }
        if didDeleteMeta {
            try? context.save()
        }
    }

    // MARK: - Foreground refresh

    /// Refetches visible data when the app returns to the foreground.
    func refreshIfStale(context: ModelContext, wasBackgrounded: Bool) {
        guard refreshTask == nil else { return }
        guard wasBackgrounded || isStale else { return }

        refreshTask = Task { [weak self] in
            await self?.refresh(context: context)
            self?.refreshTask = nil
        }
    }

    private var isStale: Bool {
        guard let lastSyncedAt else { return true }
        return Date.now.timeIntervalSince(lastSyncedAt) >= Self.staleThreshold
    }

    /// Foreground-return refresh. Tries the precise `/tasks/changes` delta first;
    /// on the very first run (no durable cursor) it skips the delta and just stores
    /// the server cursor (normal per-window SWR already covers the cold launch); on
    /// any failure (network error or a rejected/invalid cursor) it clears the cursor
    /// and falls back to the blunt ±1-month `invalidateAndResync`.
    ///
    /// This replaces the old "invalidate ALL synced months on every foreground
    /// return" with a targeted delta — only the windows touched by changed series,
    /// deletions, or exceptions get re-pulled.
    private func refresh(context: ModelContext) async {
        do {
            let calendarId = try await ensureDefaultCalendarId(context: context)

            // First run: no durable cursor yet. Skip the delta entirely — the
            // PrefetchCoordinator / per-window SWR is already pulling the visible
            // windows — and just seed the cursor so the NEXT return runs a delta.
            guard let cursorState = fetchSyncCursorState(calendarId: calendarId, in: context) else {
                let response = try await fetchChanges(calendarId: calendarId, since: nil)
                upsertSyncCursorState(calendarId: calendarId, cursor: response.serverTime, context: context)
                // Persist the seeded cursor durably with a BARE save — it is metadata,
                // so (unlike the delta path's `commit`) it must NOT bump `revision` or
                // trigger a UI reload. Mirrors how `ensureDefaultCalendarId` persists.
                // Without this, an app kill before the next foreground commit loses the
                // cursor and the app keeps cold-reinitializing.
                try? context.save()
                return
            }

            // Subsequent return: ask the server what changed since the stored cursor.
            let response = try await fetchChanges(calendarId: calendarId, since: cursorState.cursor)
            applyDelta(response, calendarId: calendarId, context: context)
        } catch {
            // Cursor invalid / rejected or the request failed: clear the cursor so
            // the next return re-initializes from scratch, then fall back to the
            // existing full re-pull around the visible month.
            if let calendarId = try? await ensureDefaultCalendarId(context: context) {
                deleteSyncCursorState(calendarId: calendarId, in: context)
            }
            await invalidateAndResync(around: selectedDate, context: context)
        }
    }

    // MARK: - Delta sync (Phase 3)

    /// Fetches the `/tasks/changes` delta for `calendarId`. Omits `since` on the
    /// first run (no cursor) so the server returns just its `serverTime` baseline;
    /// otherwise echoes the stored opaque cursor.
    private func fetchChanges(calendarId: String, since: String?) async throws -> ChangesResponse {
        var queryItems = [URLQueryItem(name: "calendarId", value: calendarId)]
        if let since {
            queryItems.append(URLQueryItem(name: "since", value: since))
        }
        return try await APIClient.shared.get("/tasks/changes", queryItems: queryItems)
    }

    /// Applies a `/tasks/changes` delta precisely, in a single atomic commit:
    ///
    /// - **(a) deleted** seriesIds → delete ALL local `TaskItem` rows for that
    ///   series (in-flight-completion rows are spared, same guard as `pruneOccurrences`).
    /// - **(b) changed series** → delete the `month`-scope ``WindowSyncMeta`` rows
    ///   whose `[startOfMonth, startOfNextMonth)` overlaps the series' active span
    ///   `[createdAt, updatedAt]`, so the next per-window SWR re-pulls and
    ///   re-expands that window from `GET /tasks` (the client never expands RRULE
    ///   itself). The `TaskDTO` row itself is NOT upserted — occurrence-level SWR
    ///   waits for the window to re-sync.
    /// - **(c) changed exceptions** → invalidate the single month window containing
    ///   each exception's `originalStartAt`.
    /// - **(d)** reconcile in-flight completions so a delta mid-toggle never flips a
    ///   checkmark, then **(e)** `commit` once (revision bump + day-count invalidation
    ///   + cursor store).
    ///
    /// The new cursor (`serverTime`) and `lastDeltaAt` are stored in the SAME commit
    /// as the deletes/invalidations so the cursor never advances past data the
    /// client failed to invalidate.
    private func applyDelta(_ response: ChangesResponse, calendarId: String, context: ModelContext) {
        // No-op delta (the common foreground case): nothing changed server-side, so
        // there's no occurrence work to do. Advance + persist the cursor with a BARE
        // save (mirroring the first-run cursor seeding) and DO NOT bump `revision` —
        // a revision bump here would cascade into reload() → loadVisibleCounts() →
        // strip count work for a change that didn't happen, the foreground "revision
        // storm". Only a non-empty delta takes the full apply + commit() path below.
        if response.tasks.isEmpty, response.deleted.isEmpty, response.exceptions.isEmpty {
            upsertSyncCursorState(calendarId: calendarId, cursor: response.serverTime, context: context)
            try? context.save()
            return
        }

        // (a) Tombstones: delete every local occurrence of each deleted series,
        // sparing rows with a completion toggle in flight (the in-flight guard wins
        // until the PATCH resolves, then reconciles).
        for seriesId in response.deleted {
            let targetId = seriesId
            let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.seriesId == targetId })
            for item in (try? context.fetch(descriptor)) ?? [] {
                guard !inFlightCompletions.keys.contains(item.occurrenceKey) else { continue }
                context.delete(item)
            }
        }

        // (b) Changed series: invalidate every month window overlapping the series'
        // active span so the next SWR re-pulls + re-expands only those windows.
        for task in response.tasks {
            invalidateMonthWindows(
                overlapping: task.createdAt..<seriesSpanEnd(for: task),
                calendarId: calendarId,
                context: context
            )
        }

        // (c) Changed exceptions: invalidate the single month window containing the
        // exception's original start (simplest correct path — forces re-fetch).
        for exception in response.exceptions {
            guard let originalStart = Self.isoFractional.date(from: exception.originalStartAt) else { continue }
            invalidateMonthWindow(containing: originalStart, calendarId: calendarId, context: context)
        }

        // (d) A delta may have run mid-toggle: re-apply any pending optimistic
        // completion so the checkmark survives until its PATCH resolves.
        reconcileInFlightCompletions(context: context)

        // (e) Advance the cursor in the SAME commit, then one revision bump.
        upsertSyncCursorState(calendarId: calendarId, cursor: response.serverTime, context: context)
        commit(context)
    }

    /// The exclusive upper bound of a changed series' active span. `updatedAt` is
    /// always present on the backend; nudge it forward one second so the
    /// half-open overlap test (`monthStart < spanEnd`) still includes the month that
    /// contains `updatedAt` itself.
    private func seriesSpanEnd(for task: TaskDTO) -> Date {
        task.updatedAt.addingTimeInterval(1)
    }

    /// Deletes the `month`-scope ``WindowSyncMeta`` rows whose
    /// `[startOfMonth, startOfNextMonth)` overlaps `span`, walking month by month
    /// across the span. A non-recurring or short series touches a single month; a
    /// long-running recurring series fans out across every month it spans. Does NOT
    /// save — the caller folds it into `applyDelta`'s single commit.
    private func invalidateMonthWindows(overlapping span: Range<Date>, calendarId: String, context: ModelContext) {
        let calendar = Calendar.current
        // Clamp the lower bound to a sane floor: a malformed span (createdAt after
        // updatedAt, or absurdly old) must not loop unboundedly.
        guard span.lowerBound < span.upperBound else {
            invalidateMonthWindow(containing: span.lowerBound, calendarId: calendarId, context: context)
            return
        }
        var cursor = CalendarMath.startOfMonth(span.lowerBound)
        let lastMonth = CalendarMath.startOfMonth(span.upperBound)
        while cursor <= lastMonth {
            invalidateMonthWindow(containing: cursor, calendarId: calendarId, context: context)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
    }

    /// Deletes the single `month`-scope ``WindowSyncMeta`` row for the month
    /// containing `date`, so the next per-window SWR reads it as stale and re-pulls.
    /// Does NOT save — the caller commits.
    private func invalidateMonthWindow(containing date: Date, calendarId: String, context: ModelContext) {
        let anchor = CalendarMath.startOfMonth(date)
        let windowKey = WindowSyncMeta.makeWindowKey(calendarId: calendarId, scope: .month, anchor: anchor)
        deleteWindowSyncMeta(windowKey: windowKey, in: context)
    }

    // MARK: - SyncCursorState (durable delta cursor)

    /// Fetches the durable delta cursor row for `calendarId`, or nil on the first
    /// run before one exists. Keyed off the `.unique` `calendarId`, so it resolves
    /// via the unique index.
    private func fetchSyncCursorState(calendarId: String, in context: ModelContext) -> SyncCursorState? {
        let target = calendarId
        let descriptor = FetchDescriptor<SyncCursorState>(
            predicate: #Predicate { $0.calendarId == target }
        )
        return (try? context.fetch(descriptor))?.first
    }

    /// Inserts or refreshes the durable delta cursor for `calendarId`, stamping the
    /// new opaque `cursor` and `lastDeltaAt = now`. Does NOT save — the caller folds
    /// it into the same commit as the delta's deletes/invalidations so the cursor
    /// never advances past data the client failed to apply.
    private func upsertSyncCursorState(calendarId: String, cursor: String, context: ModelContext) {
        if let existing = fetchSyncCursorState(calendarId: calendarId, in: context) {
            existing.cursor = cursor
            existing.lastDeltaAt = .now
            return
        }
        context.insert(SyncCursorState(calendarId: calendarId, cursor: cursor, lastDeltaAt: .now))
    }

    /// Deletes the durable delta cursor row for `calendarId` if present, so the next
    /// foreground return re-initializes from scratch. Saves immediately — it is used
    /// on the fallback path where there is no subsequent delta commit to fold into.
    private func deleteSyncCursorState(calendarId: String, in context: ModelContext) {
        guard let existing = fetchSyncCursorState(calendarId: calendarId, in: context) else { return }
        context.delete(existing)
        try? context.save()
    }

    /// Invalidates the month containing `date` plus its immediate neighbors and
    /// re-syncs them. The ±1-month fan-out matters because edits/deletes/skips
    /// near a month boundary can move or remove occurrences in an adjacent month,
    /// which a single-month resync would leave stale. Call after an edit, delete,
    /// skip, or foreground return.
    func invalidateAndResync(around date: Date, context: ModelContext) async {
        guard let calendarId = try? await ensureDefaultCalendarId(context: context) else { return }
        let center = CalendarMath.startOfMonth(date)
        let anchors = neighboringMonthAnchors(around: center).map(CalendarMath.startOfMonth)
        // Delete the month memos first (atomically) so the subsequent
        // `ensureMonthSynced` reads them as stale and revalidates from the network.
        for anchor in anchors {
            let windowKey = WindowSyncMeta.makeWindowKey(
                calendarId: calendarId, scope: .month, anchor: anchor
            )
            deleteWindowSyncMeta(windowKey: windowKey, in: context)
        }
        try? context.save()
        for anchor in anchors {
            await ensureMonthSynced(anchor, context: context)
        }
    }

    /// Clears the entire synced-month memoization so the next per-section /
    /// per-unit sync re-fetches every month. Use for a full invalidation (e.g.
    /// a foreground return that should re-cover all on-screen scopes), where the
    /// targeted ±1 `invalidateAndResync` fan-out isn't broad enough. Deletes every
    /// `month`-scope ``WindowSyncMeta`` row atomically.
    func invalidateAllSyncedMonths(context: ModelContext) {
        let scope = WindowScope.month.rawValue
        let descriptor = FetchDescriptor<WindowSyncMeta>(
            predicate: #Predicate { $0.scope == scope }
        )
        let metas = (try? context.fetch(descriptor)) ?? []
        guard !metas.isEmpty else { return }
        for meta in metas {
            context.delete(meta)
        }
        try? context.save()
    }

    // MARK: - Eviction

    /// Atomically evicts trimmed months: for each anchor, deletes its `month`-scope
    /// ``WindowSyncMeta`` row AND the persisted `TaskItem` occurrences in that
    /// month's `[startOfMonth, startOfNextMonth)` range, committing both in one
    /// `context.save()` so the memo and the rows it vouches for never drift. Called
    /// from the Month/Year scopes' scroll-settle trim. Skips occurrences with a
    /// completion toggle in flight (same guard as `pruneOccurrences`) so eviction
    /// can't drop an optimistic row mid-toggle.
    ///
    /// Does NOT bump `revision`: trimmed months are off-window by construction (the
    /// in-memory section window already dropped them), so no on-screen fetch needs
    /// to re-run. `invalidateDayCounts` is likewise skipped — counts are a separate
    /// scope, untouched by month eviction.
    func evictMonthWindows(_ anchors: [Date], context: ModelContext) {
        guard !anchors.isEmpty else { return }
        guard let calendarId = calendarId else { return }
        var didDelete = false
        for rawAnchor in anchors {
            let anchor = CalendarMath.startOfMonth(rawAnchor)
            let windowKey = WindowSyncMeta.makeWindowKey(
                calendarId: calendarId, scope: .month, anchor: anchor
            )
            deleteWindowSyncMeta(windowKey: windowKey, in: context)

            let (from, to) = CalendarMath.monthBounds(anchor)
            let sentinel = Date.distantPast
            let descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { task in
                    (task.occurrenceStart ?? sentinel) >= from &&
                    (task.occurrenceStart ?? sentinel) < to
                }
            )
            for item in (try? context.fetch(descriptor)) ?? [] {
                guard !inFlightCompletions.keys.contains(item.occurrenceKey) else { continue }
                context.delete(item)
            }
            didDelete = true
        }
        if didDelete {
            try? context.save()
        }
    }

    /// Deletes the single ``WindowSyncMeta`` row for `windowKey` if present. Does
    /// NOT save — the caller commits.
    private func deleteWindowSyncMeta(windowKey: String, in context: ModelContext) {
        let descriptor = FetchDescriptor<WindowSyncMeta>(
            predicate: #Predicate { $0.windowKey == windowKey }
        )
        for meta in (try? context.fetch(descriptor)) ?? [] {
            context.delete(meta)
        }
    }

    /// The month anchor for `center` and its ±1-month neighbors.
    private func neighboringMonthAnchors(around center: Date) -> [Date] {
        let calendar = Calendar.current
        return (-1...1).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: center)
        }
    }

    // MARK: - Mutations

    /// Optimistically toggles an occurrence's completion, then PATCHes the backend.
    /// Reverts the local change if the request fails.
    ///
    /// For a recurring instance the body carries the **`originalStart`** (the
    /// stable exception key, not the effective `occurrenceStart`) as a
    /// fractional-seconds ISO string, so the backend keys the per-instance state
    /// correctly even for sub-second anchors. For a one-off task no key is sent,
    /// routing the backend to its whole-task completion path.
    ///
    /// While in flight, the occurrence key is registered in `inFlightCompletions`
    /// so a concurrent `ensureMonthSynced` neither prunes the optimistic row nor
    /// clobbers it with a not-yet-updated server row.
    /// Toggles completion for the occurrence identified by `occurrenceKey`,
    /// resolving the row via its `@Attribute(.unique)` (indexed) key. The day
    /// pages no longer own a `@Query`, so they pass the key rather than a
    /// pre-fetched `TaskItem`.
    /// - Returns: `true` when the backend confirmed the toggle, `false` when the
    ///   row was missing or the request failed (and the optimistic change was
    ///   rolled back). Callers mirroring completion locally (e.g. the detail
    ///   screen) restore their own mirror on `false`.
    @discardableResult
    func toggleCompletion(occurrenceKey: String, context: ModelContext) async -> Bool {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.occurrenceKey == occurrenceKey }
        )
        guard let task = (try? context.fetch(descriptor))?.first else { return false }
        return await toggleCompletion(task, context: context)
    }

    @discardableResult
    func toggleCompletion(_ task: TaskItem, context: ModelContext) async -> Bool {
        let previous = task.completedAt
        let willComplete = previous == nil
        let optimistic: Date? = willComplete ? .now : nil
        let key = task.occurrenceKey

        task.completedAt = optimistic
        inFlightCompletions[key] = optimistic
        commit(context)

        // For recurring instances, the per-occurrence exception key is the stable
        // originalStart (fall back to occurrenceStart only if it's unexpectedly nil).
        let occurrenceKeyDate: Date? = task.isRecurring ? (task.originalStart ?? task.occurrenceStart) : nil
        let occurrenceStartString = occurrenceKeyDate.map { Self.isoFractional.string(from: $0) }

        do {
            let body = SetCompletionRequest(
                isCompleted: willComplete,
                occurrenceStart: occurrenceStartString
            )
            let result: CompletionResultDTO = try await APIClient.shared.patch(
                "/tasks/\(task.seriesId)/completion",
                body: body
            )
            // Trust the server's authoritative completedAt (handles clock skew).
            // Update the in-flight value to the authoritative one BEFORE clearing,
            // so a resync interleaved at this exact point reconciles the correct
            // value rather than the now-stale optimistic guess.
            inFlightCompletions[key] = result.completedAt
            task.completedAt = result.completedAt
            inFlightCompletions[key] = nil
            commit(context)
            return true
        } catch {
            task.completedAt = previous
            inFlightCompletions[key] = nil
            commit(context)
            notifications?.postError(error, title: String(localized: "calendar.error.updateTask"))
            return false
        }
    }

    /// Deletes a task series from the backend, then removes all matching local
    /// occurrences and invalidates affected months.
    func deleteTask(seriesId: String, around date: Date, context: ModelContext) async throws {
        let _: DeletedIDResponse = try await APIClient.shared.delete("/tasks/\(seriesId)")
        // Remove all local occurrences belonging to this series.
        // Capture seriesId in a local let so #Predicate can close over it.
        let targetId = seriesId
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.seriesId == targetId })
        let localItems = (try? context.fetch(descriptor)) ?? []
        for item in localItems {
            context.delete(item)
        }
        commit(context)
        await invalidateAndResync(around: date, context: context)
    }

    /// Skips a specific occurrence on the backend, then re-syncs the affected
    /// month(s). `originalStart` is the stable exception key (NOT the effective
    /// `occurrenceStart`), sent with lossless fractional-seconds precision so it
    /// matches the backend's generated key. `displayStart` is the effective start
    /// used only to pick which months to invalidate.
    func skipOccurrence(
        seriesId: String,
        originalStart: Date,
        displayStart: Date,
        context: ModelContext
    ) async throws {
        let _: SkipResponse = try await APIClient.shared.post(
            "/tasks/\(seriesId)/skip",
            body: ["occurrenceStart": Self.isoFractional.string(from: originalStart)]
        )
        await invalidateAndResync(around: displayStart, context: context)
    }

    // MARK: - Calendar resolution

    /// Returns the first calendar's id, creating a "Default" calendar when the
    /// account has none. Memoized for the store's lifetime.
    private func ensureDefaultCalendarId(context: ModelContext) async throws -> String {
        if let calendarId {
            return calendarId
        }

        let calendars: [CalendarDTO] = try await APIClient.shared.get("/calendars")
        for dto in calendars {
            EventCalendar.upsert(from: dto, in: context)
        }

        if let first = calendars.first {
            try? context.save()
            calendarId = first.id
            return first.id
        }

        let created: CalendarDTO = try await APIClient.shared.post(
            "/calendars",
            body: CreateCalendarRequest(name: "Default", color: nil, icon: nil)
        )
        EventCalendar.upsert(from: created, in: context)
        try? context.save()
        calendarId = created.id
        return created.id
    }

    /// The memoized default calendar id — exposed so task-create screens can
    /// read it without going through a full sync.
    func resolvedCalendarId(context: ModelContext) async throws -> String {
        try await ensureDefaultCalendarId(context: context)
    }
}
