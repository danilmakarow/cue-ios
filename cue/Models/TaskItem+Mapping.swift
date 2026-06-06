//
//  TaskItem+Mapping.swift
//  cue
//

import Foundation
import SwiftData

private let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    return formatter
}()

extension TaskItem {
    /// Inserts (or updates in place) a task from a series `TaskDTO` (returned by
    /// `POST /tasks` or `PATCH /tasks/:id`). For a non-recurring task there is
    /// exactly one occurrence, so `occurrenceStart = startAt`. For a recurring task
    /// this creates/updates only the anchor row — the expanded occurrences will
    /// arrive on the next `ensureMonthSynced` call.
    @discardableResult
    static func upsert(from dto: TaskDTO, in context: ModelContext) -> TaskItem {
        let occurrence = OccurrenceDTO(
            taskId: dto.id,
            calendarId: dto.calendarId,
            groupId: dto.groupId,
            originalStart: dto.startAt,
            occurrenceStart: dto.startAt,
            occurrenceEnd: dto.endAt,
            title: dto.title,
            notes: dto.notes,
            isAllDay: dto.isAllDay,
            timezone: dto.timezone,
            requiresCompletion: dto.requiresCompletion,
            completedAt: dto.completedAt,
            isRecurring: dto.recurrenceRuleId != nil,
            isException: false
        )
        return upsert(from: occurrence, in: context)
    }

    /// Inserts (or updates in place) the occurrence matching the composite key
    /// `(dto.taskId, dto.occurrenceStart)`, linking it to the already-synced
    /// `EventCalendar` when one exists locally.
    @discardableResult
    static func upsert(from dto: OccurrenceDTO, in context: ModelContext) -> TaskItem {
        let key = TaskItem.makeKey(seriesId: dto.taskId, occurrenceStart: dto.occurrenceStart)
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.occurrenceKey == key })

        let task: TaskItem
        if let existing = (try? context.fetch(descriptor))?.first {
            task = existing
        } else {
            task = TaskItem(occurrenceKey: key, seriesId: dto.taskId)
            context.insert(task)
        }

        task.seriesId = dto.taskId
        task.occurrenceStart = dto.occurrenceStart
        task.occurrenceEnd = dto.occurrenceEnd
        task.originalStart = dto.originalStart
        task.title = dto.title
        task.notes = dto.notes
        task.isAllDay = dto.isAllDay
        task.timezoneIdentifier = dto.timezone
        task.requiresCompletion = dto.requiresCompletion
        task.completedAt = dto.completedAt
        task.isRecurring = dto.isRecurring
        task.isException = dto.isException
        task.groupId = dto.groupId
        // `createdAt`/`updatedAt` are not on OccurrenceDTO — leave what's already stored.

        let calendarId = dto.calendarId
        let calendarDescriptor = FetchDescriptor<EventCalendar>(
            predicate: #Predicate { $0.id == calendarId }
        )
        task.calendar = (try? context.fetch(calendarDescriptor))?.first

        return task
    }

    /// Projects this occurrence into the lightweight `ScheduleEvent` consumed by
    /// the day views. Returns nil when the occurrence has no effective start time
    /// since it cannot be placed on a timeline.
    func asScheduleEvent() -> ScheduleEvent? {
        guard let start = occurrenceStart else { return nil }
        let resolvedEnd = occurrenceEnd ?? start.addingTimeInterval(3600)
        return ScheduleEvent(
            id: occurrenceKey,
            seriesId: seriesId,
            occurrenceStart: occurrenceStart,
            originalStart: originalStart,
            title: title,
            notes: notes,
            startAt: start,
            endAt: resolvedEnd,
            requiresCompletion: requiresCompletion,
            completedAt: completedAt,
            isRecurring: isRecurring
        )
    }
}
