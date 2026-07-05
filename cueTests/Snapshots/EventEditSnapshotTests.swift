//
//  EventEditSnapshotTests.swift
//  cueTests
//
//  Snapshot suite for the "event-edit" screen (`TaskEditScreen`). Renders the
//  edit form in its two meaningful variants:
//   - a one-off timed task (recurrence section reads "off"),
//   - a recurring task (recurrence section reflects the loaded weekly rule).
//
//  `TaskEditScreen` takes a `ScheduleEvent` (the occurrence context) plus the
//  authoritative `TaskDTO` series whose fields populate the form on `.onAppear`.
//  `TaskDTO` exposes only a custom `init(from:)`, so the fixtures are decoded
//  from inline JSON via a matching ISO-8601 `JSONDecoder` (mirroring `APIClient`).
//

import SwiftUI
import SwiftData
import Testing
@testable import cue

@MainActor
struct EventEditSnapshotTests {
    /// ISO-8601 decoder matching `APIClient`'s strategy, used to build the
    /// `TaskDTO` series fixtures (which have no memberwise initializer).
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Decodes a `TaskDTO` from a JSON literal, failing the test on malformed input.
    private static func taskDTO(from json: String) -> TaskDTO {
        // Force-try is acceptable in a test fixture: a decode failure is a test bug.
        try! makeDecoder().decode(TaskDTO.self, from: Data(json.utf8))
    }

    /// A `ScheduleEvent` occurrence context derived from the same series, used as
    /// the screen's `event` input (fallback start/end + series/occurrence ids).
    private func event(
        seriesId: String,
        title: String,
        start: Date,
        end: Date,
        isRecurring: Bool
    ) -> ScheduleEvent {
        ScheduleEvent(
            id: "\(seriesId)#occ",
            seriesId: seriesId,
            occurrenceStart: start,
            originalStart: start,
            title: title,
            startAt: start,
            endAt: end,
            isRecurring: isRecurring
        )
    }

    /// Wraps the edit screen in a `NavigationStack` (so the inline nav title +
    /// Cancel/Save toolbar render) and pushes it through the snapshot harness.
    private func record(
        named name: String,
        event: ScheduleEvent,
        series: TaskDTO
    ) -> Data? {
        let container = MockData.container()
        let screen = NavigationStack {
            TaskEditScreen(event: event, seriesDTO: series, onSaved: { _ in })
        }
        return SnapshotHarness.record(
            ScreenHost.wrap(screen, container: container),
            named: name
        )
    }

    /// Edit form for a one-off timed task — recurrence "off", no reminders.
    @Test func timedTask() {
        let series = Self.taskDTO(from: """
        {
            "id": "s-timed",
            "calendarId": "cal-1",
            "groupId": null,
            "title": "Design review",
            "notes": "Walk through the new calendar day layout.",
            "startAt": "2026-06-28T10:00:00Z",
            "endAt": "2026-06-28T11:30:00Z",
            "isAllDay": false,
            "timezone": "Europe/Berlin",
            "requiresCompletion": true,
            "color": "#3B82F6",
            "icon": "pencil",
            "completedAt": null,
            "recurrenceRuleId": null,
            "recurrence": null,
            "reminders": [],
            "notificationStrategyId": null,
            "createdAt": "2026-06-01T09:00:00Z",
            "updatedAt": "2026-06-20T12:00:00Z"
        }
        """)
        let occurrence = event(
            seriesId: "s-timed",
            title: "Design review",
            start: series.startAt ?? .now,
            end: series.endAt ?? .now,
            isRecurring: false
        )
        #expect(record(named: "event-edit-timed", event: occurrence, series: series) != nil)
    }

    /// Edit form for a recurring task — the recurrence section reflects a loaded
    /// weekly rule and the form carries a reminder + group context.
    @Test func recurringTask() {
        let series = Self.taskDTO(from: """
        {
            "id": "s-recurring",
            "calendarId": "cal-1",
            "groupId": null,
            "title": "Daily standup",
            "notes": "Platform team sync.",
            "startAt": "2026-06-28T09:30:00Z",
            "endAt": "2026-06-28T10:00:00Z",
            "isAllDay": false,
            "timezone": "Europe/Berlin",
            "requiresCompletion": true,
            "color": "#466234",
            "icon": "person.2",
            "completedAt": null,
            "recurrenceRuleId": "rr-1",
            "recurrence": {
                "id": "rr-1",
                "frequency": "WEEKLY",
                "interval": 1,
                "byWeekday": [0, 1, 2, 3, 4],
                "byMonthDay": null,
                "byMonth": null,
                "bySetPos": null,
                "monthlyAnchor": null,
                "endType": "NEVER",
                "endDate": null,
                "count": null
            },
            "reminders": [
                { "id": "rem-1", "offsetMinutes": -15, "channel": "PUSH" }
            ],
            "notificationStrategyId": null,
            "createdAt": "2026-06-01T09:00:00Z",
            "updatedAt": "2026-06-20T12:00:00Z"
        }
        """)
        let occurrence = event(
            seriesId: "s-recurring",
            title: "Daily standup",
            start: series.startAt ?? .now,
            end: series.endAt ?? .now,
            isRecurring: true
        )
        #expect(record(named: "event-edit-recurring", event: occurrence, series: series) != nil)
    }
}
