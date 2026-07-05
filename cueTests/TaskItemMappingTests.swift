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
        let task = TaskItem(occurrenceKey: "t1#", seriesId: "t1", title: "No date")
        #expect(task.asScheduleEvent() == nil)
    }

    @Test func asScheduleEventDefaultsEndToOneHourAfterStart() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let task = TaskItem(
            occurrenceKey: TaskItem.makeKey(seriesId: "t2", occurrenceStart: start),
            seriesId: "t2",
            occurrenceStart: start,
            title: "Has start"
        )

        let event = task.asScheduleEvent()
        #expect(event?.startAt == start)
        #expect(event?.endAt == start.addingTimeInterval(3600))
        #expect(event?.title == "Has start")
    }

    @Test func upsertInsertsThenUpdatesInPlace() throws {
        let container = try ModelContainer(
            for: EventCalendar.self, TaskItem.self, EventTaskGroup.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        _ = TaskItem.upsert(from: try makeTaskDTO(id: "task-1", title: "First"), in: context)
        try context.save()

        let afterInsert = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(afterInsert.count == 1)
        #expect(afterInsert.first?.title == "First")

        // Same id + start → same occurrence key → updates the existing row.
        _ = TaskItem.upsert(from: try makeTaskDTO(id: "task-1", title: "Second"), in: context)
        try context.save()

        let afterUpdate = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(afterUpdate.count == 1)
        #expect(afterUpdate.first?.title == "Second")
    }

    /// Builds a `TaskDTO` through its wire decoder — the type is decoder-only
    /// (no memberwise init), mirroring how the app actually constructs it.
    private func makeTaskDTO(id: String, title: String) throws -> TaskDTO {
        let json = """
        {
          "id": "\(id)",
          "calendarId": "cal-1",
          "title": "\(title)",
          "startAt": "2023-11-14T22:13:20Z",
          "endAt": null,
          "isAllDay": false,
          "timezone": "\(TimeZone.current.identifier)",
          "requiresCompletion": false,
          "reminders": [],
          "createdAt": "2023-11-14T22:13:20Z",
          "updatedAt": "2023-11-14T22:13:20Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TaskDTO.self, from: Data(json.utf8))
    }
}
