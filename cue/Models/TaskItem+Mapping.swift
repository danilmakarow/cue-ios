//
//  TaskItem+Mapping.swift
//  cue
//

import Foundation
import SwiftData

extension TaskItem {
    /// Inserts (or updates in place) the task matching `dto.id`, linking it
    /// to the already-synced `EventCalendar` when one exists locally.
    @discardableResult
    static func upsert(from dto: TaskDTO, in context: ModelContext) -> TaskItem {
        let id = dto.id
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })

        let task: TaskItem
        if let existing = (try? context.fetch(descriptor))?.first {
            task = existing
        } else {
            task = TaskItem(id: dto.id)
            context.insert(task)
        }

        task.title = dto.title
        task.notes = dto.notes
        task.startAt = dto.startAt
        task.endAt = dto.endAt
        task.isAllDay = dto.isAllDay
        task.timezoneIdentifier = dto.timezone
        task.requiresCompletion = dto.requiresCompletion
        task.completedAt = dto.completedAt
        task.createdAt = dto.createdAt
        task.updatedAt = dto.updatedAt

        let calendarId = dto.calendarId
        let calendarDescriptor = FetchDescriptor<EventCalendar>(
            predicate: #Predicate { $0.id == calendarId }
        )
        task.calendar = (try? context.fetch(calendarDescriptor))?.first

        return task
    }

    /// Projects this task into the lightweight `ScheduleEvent` consumed by
    /// the day views. Returns nil for unscheduled tasks (no `startAt`) since
    /// they can't be placed on a timeline or list.
    func asScheduleEvent() -> ScheduleEvent? {
        guard let startAt else { return nil }
        let resolvedEnd = endAt ?? startAt.addingTimeInterval(3600)
        return ScheduleEvent(
            id: id,
            title: title,
            notes: notes,
            startAt: startAt,
            endAt: resolvedEnd,
            requiresCompletion: requiresCompletion,
            completedAt: completedAt
        )
    }
}
