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

    /// How long data may sit untouched before a foreground return is allowed to
    /// refetch it. A short inactive→active blip within this window is ignored.
    static let staleThreshold: TimeInterval = 30

    /// Wall-clock time of the most recent *successful* month fetch.
    private(set) var lastSyncedAt: Date?

    private let user: UserDTO
    private var notifications: NotificationStore?
    private var calendarId: String?
    private var syncedMonths: Set<Date> = []
    private var refreshTask: Task<Void, Never>?

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

    /// Fetches the month's occurrences from the API and upserts them into SwiftData.
    /// Prunes stale occurrences for the synced window so edits/deletes/skips reflect.
    func ensureMonthSynced(_ monthAnchor: Date, context: ModelContext) async {
        let anchor = CalendarMath.startOfMonth(monthAnchor)
        guard !syncedMonths.contains(anchor) else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let calendarId = try await ensureDefaultCalendarId(context: context)
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
            pruneOccurrences(in: from...to, context: context)

            for dto in occurrences {
                TaskItem.upsert(from: dto, in: context)
            }
            // Re-apply any in-flight optimistic completion onto the just-upserted
            // server rows, so a concurrent toggle isn't clobbered by a server
            // row that doesn't yet reflect it (separate completion endpoint).
            reconcileInFlightCompletions(context: context)
            try? context.save()
            syncedMonths.insert(anchor)
            lastSyncedAt = .now
        } catch {
            notifications?.postError(error, title: String(localized: "calendar.error.loadTasks"))
        }
    }

    /// Removes `TaskItem` occurrences whose `occurrenceStart` falls within
    /// `range`, so stale data from edits/deletes/skips doesn't linger. Skips any
    /// occurrence with a completion toggle in flight (`inFlightCompletions`) so a
    /// concurrent optimistic update survives the prune.
    private func pruneOccurrences(in range: ClosedRange<Date>, context: ModelContext) {
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
                (task.occurrenceStart ?? sentinel) <= to
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

    /// Drops the sync cache for the currently-visible month and neighbors, then re-syncs.
    private func refresh(context: ModelContext) async {
        await invalidateAndResync(around: selectedDate, context: context)
    }

    /// Invalidates the month containing `date` plus its immediate neighbors and
    /// re-syncs them. The ±1-month fan-out matters because edits/deletes/skips
    /// near a month boundary can move or remove occurrences in an adjacent month,
    /// which a single-month resync would leave stale. Call after an edit, delete,
    /// skip, or foreground return.
    func invalidateAndResync(around date: Date, context: ModelContext) async {
        let center = CalendarMath.startOfMonth(date)
        let anchors = neighboringMonthAnchors(around: center)
        for anchor in anchors {
            syncedMonths.remove(CalendarMath.startOfMonth(anchor))
        }
        for anchor in anchors {
            await ensureMonthSynced(anchor, context: context)
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
    func toggleCompletion(occurrenceKey: String, context: ModelContext) async {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.occurrenceKey == occurrenceKey }
        )
        guard let task = (try? context.fetch(descriptor))?.first else { return }
        await toggleCompletion(task, context: context)
    }

    func toggleCompletion(_ task: TaskItem, context: ModelContext) async {
        let previous = task.completedAt
        let willComplete = previous == nil
        let optimistic: Date? = willComplete ? .now : nil
        let key = task.occurrenceKey

        task.completedAt = optimistic
        inFlightCompletions[key] = optimistic
        try? context.save()

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
            try? context.save()
        } catch {
            task.completedAt = previous
            inFlightCompletions[key] = nil
            try? context.save()
            notifications?.postError(error, title: String(localized: "calendar.error.updateTask"))
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
        try? context.save()
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
