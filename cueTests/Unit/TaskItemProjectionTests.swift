//
//  TaskItemProjectionTests.swift
//  cueTests
//
//  Parity coverage for the two timeline projections off a `TaskItem` occurrence
//  row: `asScheduleEvent()` (SwiftUI day views) and `asOccurrenceVM()` (UIKit
//  calendar scopes). The pair must agree on identity, the threaded-through
//  fields, and the `endAt` fallback; they intentionally DIVERGE only in the
//  color tokens (`asScheduleEvent` carries them directly; `asOccurrenceVM`
//  leaves them for the adapter to fold in). `groupId` is carried by both.
//

import Foundation
import SwiftData
import Testing
@testable import cue

@MainActor
struct TaskItemProjectionTests {
    /// Builds a fully-populated, scheduled occurrence row through the model's
    /// designated init. The projection methods read only stored properties, so a
    /// direct `TaskItem` is sufficient and deterministic — no ModelContext needed.
    private func makeScheduledTask(
        seriesId: String = "series-1",
        occurrenceStart: Date?,
        occurrenceEnd: Date? = nil
    ) -> TaskItem {
        let key = TaskItem.makeKey(seriesId: seriesId, occurrenceStart: occurrenceStart)
        return TaskItem(
            occurrenceKey: key,
            seriesId: seriesId,
            occurrenceStart: occurrenceStart,
            occurrenceEnd: occurrenceEnd,
            originalStart: occurrenceStart,
            title: "Standup",
            notes: "daily",
            isAllDay: false,
            requiresCompletion: true,
            completedAt: Date(timeIntervalSince1970: 1_700_003_600),
            isRecurring: true,
            groupId: "group-7",
            groupColorToken: "BLUE"
        )
    }

    // MARK: - nil-start guard (both projections)

    @Test func asScheduleEventReturnsNilWhenOccurrenceStartIsNil() {
        let task = makeScheduledTask(occurrenceStart: nil)
        #expect(task.asScheduleEvent() == nil)
    }

    @Test func asOccurrenceVMReturnsNilWhenOccurrenceStartIsNil() {
        let task = makeScheduledTask(occurrenceStart: nil)
        #expect(task.asOccurrenceVM() == nil)
    }

    // MARK: - endAt fallback (each projection)

    @Test func asScheduleEventDefaultsEndToStartPlusOneHourWhenEndIsNil() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let task = makeScheduledTask(occurrenceStart: start, occurrenceEnd: nil)

        let event = try #require(task.asScheduleEvent())
        #expect(event.startAt == start)
        #expect(event.endAt == start.addingTimeInterval(3600))
    }

    @Test func asOccurrenceVMDefaultsEndToStartPlusOneHourWhenEndIsNil() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let task = makeScheduledTask(occurrenceStart: start, occurrenceEnd: nil)

        let viewModel = try #require(task.asOccurrenceVM())
        #expect(viewModel.startAt == start)
        #expect(viewModel.endAt == start.addingTimeInterval(3600))
    }

    @Test func bothProjectionsHonorAnExplicitEndWithoutFallback() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(7200)
        let task = makeScheduledTask(occurrenceStart: start, occurrenceEnd: end)

        let event = try #require(task.asScheduleEvent())
        let viewModel = try #require(task.asOccurrenceVM())
        #expect(event.endAt == end)
        #expect(viewModel.endAt == end)
    }

    // MARK: - end-fallback parity (the key assertion)

    @Test func endFallbackIsIdenticalAcrossBothProjections() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let task = makeScheduledTask(occurrenceStart: start, occurrenceEnd: nil)

        let event = try #require(task.asScheduleEvent())
        let viewModel = try #require(task.asOccurrenceVM())

        // Same row → same resolved placement window in both projections.
        #expect(event.startAt == viewModel.startAt)
        #expect(event.endAt == viewModel.endAt)
    }

    // MARK: - threaded-through field parity

    @Test func sharedFieldsAreThreadedThroughIdenticallyInBothProjections() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(1800)
        let task = makeScheduledTask(occurrenceStart: start, occurrenceEnd: end)
        let expectedKey = TaskItem.makeKey(seriesId: "series-1", occurrenceStart: start)

        let event = try #require(task.asScheduleEvent())
        let viewModel = try #require(task.asOccurrenceVM())

        // id == occurrenceKey in both.
        #expect(event.id == expectedKey)
        #expect(viewModel.id == expectedKey)
        #expect(event.id == viewModel.id)

        // seriesId / title / originalStart / isRecurring / completedAt parity.
        #expect(event.seriesId == viewModel.seriesId)
        #expect(event.seriesId == "series-1")

        #expect(event.title == viewModel.title)
        #expect(event.title == "Standup")

        #expect(event.originalStart == viewModel.originalStart)
        #expect(event.originalStart == start)

        #expect(event.isRecurring == viewModel.isRecurring)
        #expect(event.isRecurring == true)

        #expect(event.completedAt == viewModel.completedAt)
        #expect(event.completedAt == Date(timeIntervalSince1970: 1_700_003_600))

        // occurrenceStart, notes, isAllDay, requiresCompletion also carried alike.
        #expect(event.occurrenceStart == viewModel.occurrenceStart)
        #expect(event.occurrenceStart == start)
        #expect(event.notes == viewModel.notes)
        #expect(event.isAllDay == viewModel.isAllDay)
        #expect(event.requiresCompletion == viewModel.requiresCompletion)
    }

    // MARK: - intentional divergence (group fields)

    @Test func asScheduleEventCarriesGroupIdAndGroupColorToken() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let task = makeScheduledTask(occurrenceStart: start)

        let event = try #require(task.asScheduleEvent())
        #expect(event.groupId == "group-7")
        #expect(event.groupColorToken == "BLUE")
    }

    @Test func asOccurrenceVMDropsGroupColorTokenSoTheAdapterCanFoldItBackIn() throws {
        // The shared mapping intentionally leaves the COLOR tokens nil —
        // CalendarDataAdapter folds the real group color back in via
        // `withColorTokens(...)`. Assert the base mapping omits the color even
        // though the source row HAS one; `groupId` (not a color token) IS carried
        // directly so the detail sheet can resolve the group name.
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let task = makeScheduledTask(occurrenceStart: start)

        let viewModel = try #require(task.asOccurrenceVM())
        #expect(task.groupColorToken == "BLUE")
        #expect(viewModel.groupColorToken == nil)
        #expect(viewModel.groupId == "group-7")
    }

    // MARK: - end-to-end via the upsert path (DTO decoder + in-memory store)

    /// Decodes an `OccurrenceDTO` from JSON (the type is decoder-only on the
    /// read path) and runs it through `upsert` into an in-memory store, then
    /// asserts both projections agree on the fallback window. Guards against a
    /// regression where the upsert path stores a divergent end.
    @Test func projectionsAgreeAfterUpsertingADecodedOccurrence() throws {
        let container = try ModelContainer(
            for: EventCalendar.self, TaskItem.self, EventTaskGroup.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let json = """
        {
          "taskId": "series-9",
          "calendarId": "cal-1",
          "groupId": "group-3",
          "groupColorHex": "#FF8800",
          "originalStart": "2023-11-14T22:13:20Z",
          "occurrenceStart": "2023-11-14T22:13:20Z",
          "occurrenceEnd": null,
          "title": "Decoded occurrence",
          "notes": null,
          "isAllDay": false,
          "timezone": "\(TimeZone.current.identifier)",
          "requiresCompletion": true,
          "color": "GREEN",
          "icon": null,
          "completedAt": null,
          "isRecurring": true,
          "isException": false
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(OccurrenceDTO.self, from: Data(json.utf8))

        let task = TaskItem.upsert(from: dto, in: context)
        try context.save()

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let event = try #require(task.asScheduleEvent())
        let viewModel = try #require(task.asOccurrenceVM())

        #expect(event.startAt == start)
        #expect(event.startAt == viewModel.startAt)
        #expect(event.endAt == start.addingTimeInterval(3600))
        #expect(event.endAt == viewModel.endAt)

        // asScheduleEvent surfaces the group fields; asOccurrenceVM omits the token.
        #expect(event.groupId == "group-3")
        #expect(event.groupColorToken == "#FF8800")
        #expect(viewModel.groupColorToken == nil)
    }
}
