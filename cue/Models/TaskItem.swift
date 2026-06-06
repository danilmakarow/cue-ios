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

    /// Builds the composite occurrence key from a series id and optional
    /// occurrence-start date, in a consistent ISO-8601 format.
    static func makeKey(seriesId: String, occurrenceStart: Date?) -> String {
        guard let start = occurrenceStart else {
            return "\(seriesId)#"
        }
        return "\(seriesId)#\(ISO8601DateFormatter().string(from: start))"
    }
}
