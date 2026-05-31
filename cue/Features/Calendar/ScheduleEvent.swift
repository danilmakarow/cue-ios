//
//  ScheduleEvent.swift
//  cue
//

import Foundation

/// Lightweight event/task model consumed by the calendar page views.
/// Mapped from `TaskDTO` at the networking edge; will be replaced by a
/// SwiftData `@Model` once the on-device data layer lands.
struct ScheduleEvent: Identifiable, Hashable, Sendable {
    /// Backend task id (UUID string). Used for PATCH calls.
    let id: String
    let title: String
    let notes: String?
    let startAt: Date
    let endAt: Date
    /// Whether this entry is a task (can be completed) vs a pure event.
    let requiresCompletion: Bool
    /// Timestamp at which the task was completed, if ever.
    let completedAt: Date?

    init(
        id: String,
        title: String,
        notes: String? = nil,
        startAt: Date,
        endAt: Date,
        requiresCompletion: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.startAt = startAt
        self.endAt = endAt
        self.requiresCompletion = requiresCompletion
        self.completedAt = completedAt
    }

    /// Convenience: true when `completedAt` is set.
    var isCompleted: Bool { completedAt != nil }

    /// Returns a copy with a new `completedAt`.
    func withCompletion(_ completedAt: Date?) -> ScheduleEvent {
        ScheduleEvent(
            id: id,
            title: title,
            notes: notes,
            startAt: startAt,
            endAt: endAt,
            requiresCompletion: requiresCompletion,
            completedAt: completedAt
        )
    }
}
