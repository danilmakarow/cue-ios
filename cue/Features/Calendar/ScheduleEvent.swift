//
//  ScheduleEvent.swift
//  cue
//

import Foundation

/// Lightweight event/task model consumed by the calendar page views.
/// Mapped from `TaskItem` (occurrence row) at the data-layer edge.
///
/// **Occurrence identity**: `id` is the composite `occurrenceKey`
/// (`"\(seriesId)#\(isoOccurrenceStart)"`). When sending completion or skip
/// requests, use `seriesId` for the URL path and **`originalStart`** (the stable
/// exception key) in the body — NOT `occurrenceStart`, which is the effective
/// (possibly time-overridden) start used only for display and sort.
struct ScheduleEvent: Identifiable, Hashable, Sendable {
    /// Composite occurrence key. Used as the SwiftUI list id and for local lookups.
    let id: String
    /// Backend series/anchor id — same for all occurrences of a recurring task.
    let seriesId: String
    /// Effective start of this occurrence; nil for occurrence-less tasks (shouldn't
    /// reach the day views, but kept optional for safety). Display/sort only.
    let occurrenceStart: Date?
    /// Stable per-instance exception key (alongside `seriesId`). Sent to the
    /// completion and skip endpoints. Differs from `occurrenceStart` once an
    /// occurrence has been time-overridden, so the two must not be conflated.
    let originalStart: Date?
    let title: String
    let notes: String?
    let startAt: Date
    let endAt: Date
    /// Whether this entry is a task (can be completed) vs a pure event.
    let requiresCompletion: Bool
    /// Timestamp at which the occurrence was completed, if ever.
    let completedAt: Date?
    /// True when this event is part of a recurring series.
    let isRecurring: Bool

    init(
        id: String,
        seriesId: String,
        occurrenceStart: Date? = nil,
        originalStart: Date? = nil,
        title: String,
        notes: String? = nil,
        startAt: Date,
        endAt: Date,
        requiresCompletion: Bool = false,
        completedAt: Date? = nil,
        isRecurring: Bool = false
    ) {
        self.id = id
        self.seriesId = seriesId
        self.occurrenceStart = occurrenceStart
        self.originalStart = originalStart
        self.title = title
        self.notes = notes
        self.startAt = startAt
        self.endAt = endAt
        self.requiresCompletion = requiresCompletion
        self.completedAt = completedAt
        self.isRecurring = isRecurring
    }

    /// Convenience: true when `completedAt` is set.
    var isCompleted: Bool { completedAt != nil }

    /// Returns a copy with a new `completedAt`.
    func withCompletion(_ completedAt: Date?) -> ScheduleEvent {
        ScheduleEvent(
            id: id,
            seriesId: seriesId,
            occurrenceStart: occurrenceStart,
            originalStart: originalStart,
            title: title,
            notes: notes,
            startAt: startAt,
            endAt: endAt,
            requiresCompletion: requiresCompletion,
            completedAt: completedAt,
            isRecurring: isRecurring
        )
    }
}
