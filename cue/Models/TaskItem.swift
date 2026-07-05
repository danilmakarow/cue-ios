//
//  TaskItem.swift
//  cue
//

import Foundation
import SwiftData

/// A per-task reminder persisted INLINE on a ``TaskItem`` — the on-device mirror
/// of the wire ``ReminderDTO``. Stored as an embedded `Codable` value (SwiftData
/// serializes the array as a blob on the row), NOT a separate `@Model`, because
/// reminders have no independent identity or query needs: they're a small fixed
/// set the client re-syncs wholesale with the parent task, exactly like the rest
/// of the re-syncable cache. `offsetMinutes` is relative to the task start
/// (negative fires before, positive after).
struct TaskReminder: Codable, Sendable, Hashable {
    /// Backend `NotificationRule` id, kept so the client can correlate on re-sync.
    var id: String
    var offsetMinutes: Int
    var channel: NotificationChannel

    /// Builds an inline reminder from its wire shape.
    init(from dto: ReminderDTO) {
        self.id = dto.id
        self.offsetMinutes = dto.offsetMinutes
        self.channel = dto.channel
    }
}

/// On-device calendar occurrence. The persisted unit is the **occurrence**, not
/// the series, because a recurring task expands to many calendar cells that each
/// need independent completion state.
///
/// **Occurrence identity**: `occurrenceKey = "\(seriesId)#\(occurrenceStart ISO)"`.
/// For non-recurring tasks `occurrenceStart` is nil and the key is just
/// `"\(seriesId)#"` — still unique because a non-recurring task has exactly one
/// occurrence.
///
/// `seriesId` is the backend `Task.id` (the anchor). Completion, skip, and series
/// edits all address the server by `(seriesId, occurrenceStart)`.
@Model
final class TaskItem {
    /// Index on the occurrence start — the column the day-scope `@Query` orders by
    /// (`sort: \.occurrenceStart`) and the month prune scans. It primarily serves
    /// the `ORDER BY` (SQLite walks the index instead of doing a filesort); the
    /// windowed predicates coalesce the optional start (`?? .distantPast`) to stay
    /// a single expression, and a plain index can't seek a `COALESCE`-wrapped
    /// range — so the *ordering* is the concrete win here, not the range filter.
    /// The schema bump needs no migration plan — the store is a re-syncable cache
    /// with a destroy-and-recreate fallback in `cueApp`.
    #Index<TaskItem>([\.occurrenceStart])

    /// Composite unique key: `"\(seriesId)#\(isoOccurrenceStart)"`.
    /// This is what SwiftData indexes; use `upsert(from:in:)` to maintain it.
    @Attribute(.unique) var occurrenceKey: String
    /// Backend series/anchor id — same for all occurrences of one recurring task.
    var seriesId: String
    /// Effective start of this particular occurrence. Nil for non-recurring tasks.
    var occurrenceStart: Date?
    /// Effective end of this particular occurrence.
    var occurrenceEnd: Date?
    /// Original start (stable instance key alongside `seriesId`).
    var originalStart: Date?

    var title: String
    var notes: String?
    var isAllDay: Bool
    var timezoneIdentifier: String
    var requiresCompletion: Bool
    /// Timestamp the occurrence was completed, or nil while incomplete.
    var completedAt: Date?

    /// Whether this occurrence is part of a recurring series.
    var isRecurring: Bool
    /// True for overridden occurrences (start/end changed by an exception).
    var isException: Bool
    /// When non-nil, this occurrence is a materialized OVERRIDE child of the
    /// recurring parent named here (its `seriesId` is the child's own task id).
    /// Lets the UI badge it and route edits/deletes to the child directly.
    var parentSeriesId: String?
    /// True when this override child's parent rule no longer generates its
    /// original slot (rendered "detached from series").
    var isDetached: Bool
    /// Optional group membership id.
    var groupId: String?

    /// EFFECTIVE color for this occurrence (task ?? group ?? nil): a `TaskColor`
    /// preset name (e.g. "BLUE") or a `#RRGGBB` hex. Resolve via
    /// `TaskColorResolver` — NOT always a hex.
    var colorToken: String?
    /// The owning group's color (preset name or `#RRGGBB` hex); nil when ungrouped
    /// or unloaded. Carried so day rails / month dots render the real group color
    /// even when the task has its own `colorToken` override.
    var groupColorToken: String?
    /// Per-task icon (SF Symbol name); nil when iconless.
    var icon: String?
    /// Per-task reminders, persisted inline (see ``TaskReminder``). Empty when the
    /// task has none. Only populated from the series `TaskDTO` upsert path — the
    /// `OccurrenceDTO` calendar-read shape does not carry reminders, so that path
    /// leaves the stored set untouched.
    var reminders: [TaskReminder]

    var createdAt: Date
    var updatedAt: Date

    @Relationship var calendar: EventCalendar?

    init(
        occurrenceKey: String,
        seriesId: String,
        occurrenceStart: Date? = nil,
        occurrenceEnd: Date? = nil,
        originalStart: Date? = nil,
        title: String = "",
        notes: String? = nil,
        isAllDay: Bool = false,
        timezoneIdentifier: String = TimeZone.current.identifier,
        requiresCompletion: Bool = false,
        completedAt: Date? = nil,
        isRecurring: Bool = false,
        isException: Bool = false,
        parentSeriesId: String? = nil,
        isDetached: Bool = false,
        groupId: String? = nil,
        colorToken: String? = nil,
        groupColorToken: String? = nil,
        icon: String? = nil,
        reminders: [TaskReminder] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.occurrenceKey = occurrenceKey
        self.seriesId = seriesId
        self.occurrenceStart = occurrenceStart
        self.occurrenceEnd = occurrenceEnd
        self.originalStart = originalStart
        self.title = title
        self.notes = notes
        self.isAllDay = isAllDay
        self.timezoneIdentifier = timezoneIdentifier
        self.requiresCompletion = requiresCompletion
        self.completedAt = completedAt
        self.isRecurring = isRecurring
        self.isException = isException
        self.parentSeriesId = parentSeriesId
        self.isDetached = isDetached
        self.groupId = groupId
        self.colorToken = colorToken
        self.groupColorToken = groupColorToken
        self.icon = icon
        self.reminders = reminders
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// True when the occurrence has been completed.
    var isCompleted: Bool { completedAt != nil }

    /// Shared formatter for the local occurrence key. Cached because a month sync
    /// builds one key per occurrence — allocating a fresh `ISO8601DateFormatter`
    /// each time added up on the open-time sync. Default options (no fractional
    /// seconds), so the produced key — and the `.unique` constraint — is unchanged.
    private static let keyFormatter = ISO8601DateFormatter()

    /// Builds the composite occurrence key from a series id and optional
    /// occurrence-start date, in a consistent ISO-8601 format.
    static func makeKey(seriesId: String, occurrenceStart: Date?) -> String {
        guard let start = occurrenceStart else {
            return "\(seriesId)#"
        }
        return "\(seriesId)#\(keyFormatter.string(from: start))"
    }
}
