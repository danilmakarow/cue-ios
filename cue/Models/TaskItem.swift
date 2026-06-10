//
//  TaskItem.swift
//  cue
//

import Foundation
import SwiftData

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
    /// Optional group membership id.
    var groupId: String?

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
        groupId: String? = nil,
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
        self.groupId = groupId
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
