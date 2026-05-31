//
//  TaskItemMappingTests.swift
//  cueTests
//

import Foundation
import SwiftData
import Testing
@testable import cue

@MainActor
struct TaskItemMappingTests {
    @Test func asScheduleEventIsNilWhenUnscheduled() {
        let task = TaskItem(id: "t1", title: "No date")
        #expect(task.asScheduleEvent() == nil)
    }

    @Test func asScheduleEventDefaultsEndToOneHourAfterStart() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let task = TaskItem(id: "t2", title: "Has start", startAt: start)

        let event = task.asScheduleEvent()
        #expect(event?.startAt == start)
        #expect(event?.endAt == start.addingTimeInterval(3600))
        #expect(event?.title == "Has start")
    }

    @Test func upsertInsertsThenUpdatesInPlace() throws {
        let container = try ModelContainer(
            for: EventCalendar.self, TaskItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        TaskItem.upsert(from: makeTaskDTO(id: "task-1", title: "First"), in: context)
        try context.save()

        let afterInsert = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(afterInsert.count == 1)
        #expect(afterInsert.first?.title == "First")

        // Same id, new title → updates the existing row rather than duplicating.
        TaskItem.upsert(from: makeTaskDTO(id: "task-1", title: "Second"), in: context)
        try context.save()

        let afterUpdate = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(afterUpdate.count == 1)
        #expect(afterUpdate.first?.title == "Second")
    }

    private func makeTaskDTO(id: String, title: String) -> TaskDTO {
        TaskDTO(
            id: id,
            calendarId: "cal-1",
            title: title,
            notes: nil,
            startAt: Date(timeIntervalSince1970: 1_700_000_000),
            endAt: nil,
            isAllDay: false,
            timezone: TimeZone.current.identifier,
            requiresCompletion: false,
            completedAt: nil,
            recurrenceRuleId: nil,
            notificationStrategyId: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }
}
