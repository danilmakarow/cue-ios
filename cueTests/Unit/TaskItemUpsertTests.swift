//
//  TaskItemUpsertTests.swift
//  cueTests
//
//  Covers `TaskItem.upsert(from: OccurrenceDTO)` and the `TaskDTO`-synthesized
//  `upsert(from: TaskDTO)` path. Complements `TaskItemMappingTests`, which only
//  exercises the `TaskDTO` insert/update and `asScheduleEvent` projection.
//

import Foundation
import SwiftData
import Testing
@testable import cue

@MainActor
struct TaskItemUpsertTests {
    // MARK: - Shared helpers

    /// Spins up a fresh in-memory SwiftData context holding the three models the
    /// upsert path touches (`EventCalendar`, `TaskItem`, `EventTaskGroup`).
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: EventCalendar.self, TaskItem.self, EventTaskGroup.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// Decodes an `OccurrenceDTO` from a JSON fixture through its wire decoder —
    /// the type is decoder-only, mirroring how the app actually builds it.
    private func decodeOccurrence(_ json: String) throws -> OccurrenceDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OccurrenceDTO.self, from: Data(json.utf8))
    }

    /// Decodes a `TaskDTO` from a JSON fixture through its wire decoder.
    private func decodeTask(_ json: String) throws -> TaskDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TaskDTO.self, from: Data(json.utf8))
    }

    /// A fully-populated `OccurrenceDTO` fixture for the happy-path field-mapping
    /// assertions. `occurrenceStart` is parameterized so recurring-expansion tests
    /// can vary just the instance time.
    private func occurrenceJSON(
        taskId: String = "task-occ",
        calendarId: String = "cal-1",
        occurrenceStart: String = "2026-06-10T09:00:00Z",
        title: String = "Standup"
    ) -> String {
        return """
        {
          "taskId": "\(taskId)",
          "calendarId": "\(calendarId)",
          "groupId": "grp-7",
          "groupColorHex": "#112233",
          "originalStart": "2026-06-10T08:30:00Z",
          "occurrenceStart": "\(occurrenceStart)",
          "occurrenceEnd": "2026-06-10T09:30:00Z",
          "title": "\(title)",
          "notes": "daily sync",
          "isAllDay": false,
          "timezone": "America/New_York",
          "requiresCompletion": true,
          "color": "BLUE",
          "icon": "bell.fill",
          "completedAt": null,
          "isRecurring": true,
          "isException": true
        }
        """
    }

    // MARK: - OccurrenceDTO field mapping

    @Test func occurrenceUpsertMapsEveryField() throws {
        let context = try makeContext()
        let dto = try decodeOccurrence(occurrenceJSON())

        let task = TaskItem.upsert(from: dto, in: context)

        let expectedStart = Date(timeIntervalSince1970: 1_781_082_000) // 2026-06-10T09:00:00Z
        let expectedEnd = Date(timeIntervalSince1970: 1_781_083_800)   // 2026-06-10T09:30:00Z
        let expectedOriginal = Date(timeIntervalSince1970: 1_781_080_200) // 2026-06-10T08:30:00Z

        #expect(task.seriesId == "task-occ")
        #expect(task.occurrenceStart == expectedStart)
        #expect(task.occurrenceEnd == expectedEnd)
        #expect(task.originalStart == expectedOriginal)
        #expect(task.title == "Standup")
        #expect(task.notes == "daily sync")
        #expect(task.isAllDay == false)
        #expect(task.timezoneIdentifier == "America/New_York")
        #expect(task.requiresCompletion == true)
        #expect(task.completedAt == nil)
        #expect(task.isRecurring == true)
        #expect(task.isException == true)
        #expect(task.groupId == "grp-7")
        // colorToken is the EFFECTIVE color (dto.color), groupColorToken is dto.groupColorHex.
        #expect(task.colorToken == "BLUE")
        #expect(task.groupColorToken == "#112233")
        #expect(task.icon == "bell.fill")
    }

    @Test func occurrenceUpsertBuildsCompositeKey() throws {
        let context = try makeContext()
        let dto = try decodeOccurrence(occurrenceJSON())

        let task = TaskItem.upsert(from: dto, in: context)
        let expectedKey = TaskItem.makeKey(
            seriesId: dto.taskId,
            occurrenceStart: dto.occurrenceStart
        )

        #expect(task.occurrenceKey == expectedKey)
    }

    // MARK: - Calendar linkage

    @Test func occurrenceUpsertLinksToPreInsertedCalendar() throws {
        let context = try makeContext()
        let calendar = EventCalendar(id: "cal-1", name: "Work")
        context.insert(calendar)
        try context.save()

        let task = TaskItem.upsert(from: try decodeOccurrence(occurrenceJSON()), in: context)

        #expect(task.calendar != nil)
        #expect(task.calendar?.id == "cal-1")
    }

    @Test func occurrenceUpsertLeavesCalendarNilWhenAbsentLocally() throws {
        let context = try makeContext()
        // No EventCalendar inserted for "cal-1".

        let task = TaskItem.upsert(from: try decodeOccurrence(occurrenceJSON()), in: context)

        #expect(task.calendar == nil)
    }

    @Test func occurrenceUpsertLinksOnlyMatchingCalendarId() throws {
        let context = try makeContext()
        context.insert(EventCalendar(id: "cal-other", name: "Personal"))
        try context.save()

        let task = TaskItem.upsert(from: try decodeOccurrence(occurrenceJSON()), in: context)

        // Calendar exists but with a different id → still no link.
        #expect(task.calendar == nil)
    }

    // MARK: - Upsert identity / recurring expansion

    @Test func sameKeyUpsertUpdatesInPlace() throws {
        let context = try makeContext()

        _ = TaskItem.upsert(from: try decodeOccurrence(occurrenceJSON(title: "First")), in: context)
        try context.save()

        var rows = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(rows.count == 1)
        #expect(rows.first?.title == "First")

        // Same taskId + same occurrenceStart → same composite key → in-place update.
        _ = TaskItem.upsert(from: try decodeOccurrence(occurrenceJSON(title: "Second")), in: context)
        try context.save()

        rows = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(rows.count == 1)
        #expect(rows.first?.title == "Second")
    }

    @Test func differentOccurrenceStartInsertsSecondRow() throws {
        let context = try makeContext()

        _ = TaskItem.upsert(
            from: try decodeOccurrence(occurrenceJSON(occurrenceStart: "2026-06-10T09:00:00Z")),
            in: context
        )
        // Same series, a DIFFERENT instance time → recurring expansion → new row.
        _ = TaskItem.upsert(
            from: try decodeOccurrence(occurrenceJSON(occurrenceStart: "2026-06-11T09:00:00Z")),
            in: context
        )
        try context.save()

        let rows = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(rows.count == 2)
        // Both rows share the series id.
        #expect(rows.allSatisfy { $0.seriesId == "task-occ" })
        let starts = Set(rows.compactMap { $0.occurrenceStart })
        #expect(starts.count == 2)
    }

    // MARK: - OccurrenceDTO leaves reminders untouched

    @Test func occurrenceUpsertDoesNotTouchReminders() throws {
        let context = try makeContext()

        // Seed a row via the TaskDTO path so it carries a reminder.
        let taskJSON = """
        {
          "id": "task-occ",
          "calendarId": "cal-1",
          "title": "Standup",
          "startAt": "2026-06-10T09:00:00Z",
          "endAt": null,
          "isAllDay": false,
          "timezone": "America/New_York",
          "requiresCompletion": false,
          "reminders": [
            { "id": "rem-1", "offsetMinutes": -15, "channel": "PUSH" }
          ],
          "createdAt": "2026-06-10T09:00:00Z",
          "updatedAt": "2026-06-10T09:00:00Z"
        }
        """
        _ = TaskItem.upsert(from: try decodeTask(taskJSON), in: context)
        try context.save()

        // Now re-upsert the SAME occurrence via the OccurrenceDTO calendar-read path.
        let task = TaskItem.upsert(from: try decodeOccurrence(occurrenceJSON()), in: context)

        // The OccurrenceDTO shape carries no reminders, so the seeded set survives.
        #expect(task.reminders.count == 1)
        #expect(task.reminders.first?.id == "rem-1")
        #expect(task.reminders.first?.offsetMinutes == -15)
        #expect(task.reminders.first?.channel == .push)
    }

    // MARK: - TaskDTO path: reminders + isRecurring derivation

    @Test func taskUpsertMapsReminders() throws {
        let context = try makeContext()
        let taskJSON = """
        {
          "id": "task-1",
          "calendarId": "cal-1",
          "title": "With reminders",
          "startAt": "2026-06-10T09:00:00Z",
          "endAt": null,
          "isAllDay": false,
          "timezone": "America/New_York",
          "requiresCompletion": false,
          "reminders": [
            { "id": "rem-a", "offsetMinutes": -30, "channel": "PUSH" },
            { "id": "rem-b", "offsetMinutes": 5, "channel": "TELEGRAM" }
          ],
          "createdAt": "2026-06-10T09:00:00Z",
          "updatedAt": "2026-06-10T09:00:00Z"
        }
        """

        let task = TaskItem.upsert(from: try decodeTask(taskJSON), in: context)

        #expect(task.reminders.count == 2)
        #expect(task.reminders.map { $0.id } == ["rem-a", "rem-b"])
        #expect(task.reminders.map { $0.offsetMinutes } == [-30, 5])
        #expect(task.reminders.map { $0.channel } == [.push, .telegram])
    }

    @Test func taskUpsertNonRecurringDerivesIsRecurringFalse() throws {
        let context = try makeContext()
        let taskJSON = """
        {
          "id": "task-plain",
          "calendarId": "cal-1",
          "title": "One-off",
          "startAt": "2026-06-10T09:00:00Z",
          "endAt": null,
          "isAllDay": false,
          "timezone": "America/New_York",
          "requiresCompletion": false,
          "reminders": [],
          "createdAt": "2026-06-10T09:00:00Z",
          "updatedAt": "2026-06-10T09:00:00Z"
        }
        """

        let task = TaskItem.upsert(from: try decodeTask(taskJSON), in: context)

        // No recurrence and no recurrenceRuleId → not recurring.
        #expect(task.isRecurring == false)
    }

    @Test func taskUpsertDerivesIsRecurringFromRuleId() throws {
        let context = try makeContext()
        let taskJSON = """
        {
          "id": "task-rid",
          "calendarId": "cal-1",
          "title": "Has rule id only",
          "startAt": "2026-06-10T09:00:00Z",
          "endAt": null,
          "isAllDay": false,
          "timezone": "America/New_York",
          "requiresCompletion": false,
          "recurrenceRuleId": "rule-xyz",
          "reminders": [],
          "createdAt": "2026-06-10T09:00:00Z",
          "updatedAt": "2026-06-10T09:00:00Z"
        }
        """

        let task = TaskItem.upsert(from: try decodeTask(taskJSON), in: context)

        // recurrenceRuleId != nil → isRecurring derived true even without an embedded rule.
        #expect(task.isRecurring == true)
    }

    @Test func taskUpsertDerivesIsRecurringFromEmbeddedRule() throws {
        let context = try makeContext()
        let taskJSON = """
        {
          "id": "task-rule",
          "calendarId": "cal-1",
          "title": "Has embedded rule",
          "startAt": "2026-06-10T09:00:00Z",
          "endAt": null,
          "isAllDay": false,
          "timezone": "America/New_York",
          "requiresCompletion": false,
          "recurrence": {
            "id": "rule-1",
            "frequency": "DAILY",
            "interval": 1,
            "byWeekday": null,
            "byMonthDay": null,
            "byMonth": null,
            "bySetPos": null,
            "monthlyAnchor": null,
            "endType": "NEVER",
            "endDate": null,
            "count": null
          },
          "reminders": [],
          "createdAt": "2026-06-10T09:00:00Z",
          "updatedAt": "2026-06-10T09:00:00Z"
        }
        """

        let task = TaskItem.upsert(from: try decodeTask(taskJSON), in: context)

        // recurrence != nil → isRecurring derived true.
        #expect(task.isRecurring == true)
    }
}
