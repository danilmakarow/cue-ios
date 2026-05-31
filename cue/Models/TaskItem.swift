//
//  TaskItem.swift
//  cue
//

import Foundation
import SwiftData

/// On-device task/event. Mirrors `TaskDTO` (the BE `Task` entity); named
/// `TaskItem` to avoid colliding with Swift Concurrency's `Task`.
///
/// A task with no `startAt` is unscheduled — it isn't placeable on the
/// timeline and shows no month dot (see `asScheduleEvent()`).
@Model
final class TaskItem {
    @Attribute(.unique) var id: String
    var title: String
    var notes: String?
    var startAt: Date?
    var endAt: Date?
    var isAllDay: Bool
    var timezoneIdentifier: String
    var requiresCompletion: Bool
    /// Timestamp the task was completed, or nil while incomplete.
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    @Relationship var calendar: EventCalendar?

    init(
        id: String,
        title: String = "",
        notes: String? = nil,
        startAt: Date? = nil,
        endAt: Date? = nil,
        isAllDay: Bool = false,
        timezoneIdentifier: String = TimeZone.current.identifier,
        requiresCompletion: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.startAt = startAt
        self.endAt = endAt
        self.isAllDay = isAllDay
        self.timezoneIdentifier = timezoneIdentifier
        self.requiresCompletion = requiresCompletion
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// True when the task has been completed.
    var isCompleted: Bool { completedAt != nil }
}
