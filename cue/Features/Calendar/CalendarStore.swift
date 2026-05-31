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
/// It owns the user's *selection* (`selectedDate`, `viewMode`) and the
/// API → SwiftData *sync coordination*. It deliberately does NOT hold the
/// events themselves — those live in SwiftData and are read reactively by
/// the scope views through `@Query`. Sync methods take the `ModelContext`
/// from the calling view (which always has it via `@Environment`), so the
/// store never needs to capture or outlive a context.
@Observable
@MainActor
final class CalendarStore {
    var selectedDate: Date
    var viewMode: CalendarViewMode
    private(set) var isLoading: Bool = false

    private let user: UserDTO
    /// Global notification queue used to surface request failures as banners.
    /// Optional + wired post-init via `bind(notifications:)` because the owning
    /// view can only read it from `@Environment` in `body`, not in `init`.
    private var notifications: NotificationStore?
    /// Memoized default-calendar id, resolved on first sync.
    private var calendarId: String?
    /// `startOfMonth` keys already synced this session — guards re-fetch.
    private var syncedMonths: Set<Date> = []

    private static let iso8601: ISO8601DateFormatter = {
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

    /// Wires the global notification queue read from the owning view's
    /// environment. Idempotent — only binds the first time, so re-renders of
    /// the host view don't replace an already-attached store.
    func bind(notifications: NotificationStore) {
        guard self.notifications == nil else { return }
        self.notifications = notifications
    }

    // MARK: - Sync

    /// Ensures the month containing `day` is synced. A day is always covered
    /// by its month-range fetch, so day and month scopes share one cache and
    /// drilling into a day after viewing its month is a cache hit.
    func ensureDaySynced(_ day: Date, context: ModelContext) async {
        await ensureMonthSynced(CalendarMath.startOfMonth(day), context: context)
    }

    /// Fetches the month's tasks from the API and upserts them into SwiftData.
    /// No-ops when the month was already synced this session.
    func ensureMonthSynced(_ monthAnchor: Date, context: ModelContext) async {
        let anchor = CalendarMath.startOfMonth(monthAnchor)
        guard !syncedMonths.contains(anchor) else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let calendarId = try await ensureDefaultCalendarId(context: context)
            let (from, to) = CalendarMath.monthBounds(anchor)
            let dtos: [TaskDTO] = try await APIClient.shared.get(
                "/tasks",
                queryItems: [
                    URLQueryItem(name: "calendarId", value: calendarId),
                    URLQueryItem(name: "from", value: Self.iso8601.string(from: from)),
                    URLQueryItem(name: "to", value: Self.iso8601.string(from: to)),
                ]
            )
            for dto in dtos {
                TaskItem.upsert(from: dto, in: context)
            }
            try? context.save()
            syncedMonths.insert(anchor)
        } catch {
            notifications?.postError(error, title: "Couldn't load your tasks")
        }
    }

    // MARK: - Mutations

    /// Optimistically toggles the task's completion, then PATCHes the backend.
    /// Reverts the local change if the request fails.
    func toggleCompletion(_ task: TaskItem, context: ModelContext) async {
        let previous = task.completedAt
        let willComplete = previous == nil
        task.completedAt = willComplete ? .now : nil
        try? context.save()

        do {
            let updated: TaskDTO = try await APIClient.shared.patch(
                "/tasks/\(task.id)",
                body: UpdateTaskCompletionRequest(isCompleted: willComplete)
            )
            task.completedAt = updated.completedAt
            try? context.save()
        } catch {
            task.completedAt = previous
            try? context.save()
            notifications?.postError(error, title: "Couldn't update task")
        }
    }

    // MARK: - Calendar resolution

    /// Returns the first calendar's id, creating a "Default" calendar when the
    /// account has none. Memoized for the store's lifetime; also upserts the
    /// fetched calendars into SwiftData so tasks can link to them.
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
}
