//
//  OccurrenceVM.swift
//  cue
//

import Foundation

/// Lightweight, `Sendable` value model for a single calendar occurrence,
/// consumed by the UIKit calendar scopes and their diffable data sources.
///
/// It is the UIKit-side analogue of ``ScheduleEvent`` — same fields and the same
/// `startAt`/`endAt` derivation (see ``TaskItem/asOccurrenceVM()``) — but carries
/// the value into diffable snapshots, so `id` is the composite `occurrenceKey`
/// and the struct is `Hashable` for snapshot identity/diffing.
///
/// **Occurrence identity**: `id == occurrenceKey` (`"\(seriesId)#\(isoStart)"`).
/// When toggling completion or skipping, address the backend by `seriesId` (URL
/// path) and **`originalStart`** (the stable exception key) — NOT
/// `occurrenceStart`, which is the effective, possibly time-overridden start
/// used only for display and sort.
struct OccurrenceVM: Identifiable, Hashable, Sendable {
    /// Composite occurrence key (`= occurrenceKey`). The diffable snapshot id.
    let id: String
    /// Backend series/anchor id — same for all occurrences of a recurring task.
    let seriesId: String
    /// Effective start of this occurrence; nil for occurrence-less tasks
    /// (filtered out by the mapping). Display/sort only.
    let occurrenceStart: Date?
    /// Stable per-instance exception key (alongside `seriesId`). Sent to the
    /// completion and skip endpoints; differs from `occurrenceStart` once an
    /// occurrence has been time-overridden, so the two must not be conflated.
    let originalStart: Date?
    let title: String
    let notes: String?
    /// Resolved placement start — guaranteed non-nil so the occurrence can sit
    /// on a timeline.
    let startAt: Date
    /// Resolved placement end. Falls back to `startAt + 1h` when the row has no
    /// `occurrenceEnd`, mirroring ``ScheduleEvent``.
    let endAt: Date
    /// True when the occurrence spans the whole day and has no meaningful
    /// intra-day placement. Drives the "all-day" label (instead of a clock time)
    /// in the agenda/timeline rather than placing it at its midnight start.
    let isAllDay: Bool
    /// Whether this entry is a task (can be completed) vs a pure event.
    let requiresCompletion: Bool
    /// Timestamp at which the occurrence was completed, if ever.
    let completedAt: Date?
    /// True when this occurrence is part of a recurring series.
    let isRecurring: Bool
    /// The occurrence's group color token — a `TaskColor` preset name (e.g.
    /// `"BLUE"`) OR a `#RRGGBB` hex, straight off `OccurrenceDTO.groupColorHex`.
    /// Resolved to a render color via ``CalendarColor/rail(for:theme:)`` so the
    /// day timeline/agenda rails and month chips/dots paint by GROUP, falling
    /// back to the clay structural rail when the group has no color. `nil` when
    /// the occurrence belongs to no group (or the group is uncolored).
    let groupColorToken: String?

    /// Designated initializer mirroring ``ScheduleEvent``'s field set.
    init(
        id: String,
        seriesId: String,
        occurrenceStart: Date? = nil,
        originalStart: Date? = nil,
        title: String,
        notes: String? = nil,
        startAt: Date,
        endAt: Date,
        isAllDay: Bool = false,
        requiresCompletion: Bool = false,
        completedAt: Date? = nil,
        isRecurring: Bool = false,
        groupColorToken: String? = nil
    ) {
        self.id = id
        self.seriesId = seriesId
        self.occurrenceStart = occurrenceStart
        self.originalStart = originalStart
        self.title = title
        self.notes = notes
        self.startAt = startAt
        self.endAt = endAt
        self.isAllDay = isAllDay
        self.requiresCompletion = requiresCompletion
        self.completedAt = completedAt
        self.isRecurring = isRecurring
        self.groupColorToken = groupColorToken
    }

    /// Convenience: true when `completedAt` is set.
    var isCompleted: Bool { completedAt != nil }

    /// Returns a copy carrying `token` as the group color. Used by
    /// ``CalendarDataAdapter`` to fold the group color onto the base value the
    /// shared `TaskItem.asOccurrenceVM()` mapping produces (which omits it).
    func withGroupColorToken(_ token: String?) -> OccurrenceVM {
        OccurrenceVM(
            id: id,
            seriesId: seriesId,
            occurrenceStart: occurrenceStart,
            originalStart: originalStart,
            title: title,
            notes: notes,
            startAt: startAt,
            endAt: endAt,
            isAllDay: isAllDay,
            requiresCompletion: requiresCompletion,
            completedAt: completedAt,
            isRecurring: isRecurring,
            groupColorToken: token
        )
    }
}
