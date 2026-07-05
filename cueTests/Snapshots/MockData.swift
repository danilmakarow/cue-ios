//
//  MockData.swift
//  cueTests
//
//  Deterministic fixtures for snapshot tests: a sample user plus an in-memory
//  SwiftData store seeded into named "day states". No network — snapshot tests
//  render purely from this seeded data.
//

import Foundation
import SwiftData
@testable import cue

@MainActor
enum MockData {
    /// Stable sample user (fixed timestamps keep snapshots deterministic).
    static let user = UserDTO(
        id: "usr_mock",
        appleUserId: "apple_mock",
        email: "tony@stark.com",
        displayName: "Tony Stark",
        avatarBase64: nil,
        timezone: "Europe/Berlin",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    /// Fresh in-memory container holding the full app schema.
    static func container() -> ModelContainer {
        let schema = Schema([
            EventCalendar.self, TaskItem.self, EventTaskGroup.self,
            WindowSyncMeta.self, SyncCursorState.self,
        ])
        // Force-try is acceptable in test fixtures.
        return try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    // MARK: - Builders

    @discardableResult
    static func calendar(id: String = "cal-1", name: String = "Personal", in context: ModelContext) -> EventCalendar {
        let calendar = EventCalendar(id: id, name: name, colorHex: "#466234", sortOrder: 0)
        context.insert(calendar)
        return calendar
    }

    @discardableResult
    static func group(id: String = "grp-1", calendarId: String = "cal-1", name: String = "Work", color: String = "#3B82F6", in context: ModelContext) -> EventTaskGroup {
        let group = EventTaskGroup(id: id, calendarId: calendarId, name: name, colorHex: color, sortOrder: 0)
        context.insert(group)
        return group
    }

    /// Builds + inserts a single task occurrence. Colors are `#RRGGBB` hex so they
    /// resolve via `TaskColorResolver` without depending on preset-name spelling.
    @discardableResult
    static func task(
        seriesId: String,
        title: String,
        start: Date?,
        durationMinutes: Int = 60,
        isAllDay: Bool = false,
        requiresCompletion: Bool = true,
        completed: Bool = false,
        isRecurring: Bool = false,
        groupColor: String? = "#3B82F6",
        calendar: EventCalendar? = nil,
        in context: ModelContext
    ) -> TaskItem {
        let end = start.map { $0.addingTimeInterval(TimeInterval(durationMinutes * 60)) }
        let task = TaskItem(
            occurrenceKey: TaskItem.makeKey(seriesId: seriesId, occurrenceStart: start),
            seriesId: seriesId,
            occurrenceStart: start,
            occurrenceEnd: end,
            originalStart: start,
            title: title,
            isAllDay: isAllDay,
            requiresCompletion: requiresCompletion,
            completedAt: completed ? Date(timeIntervalSince1970: 1_700_000_000) : nil,
            isRecurring: isRecurring,
            groupColorToken: groupColor
        )
        task.calendar = calendar
        context.insert(task)
        return task
    }

    // MARK: - Day-state presets

    /// The content-state matrix snapshot tests sweep across.
    enum DayState: String, CaseIterable {
        case empty, single, overlapping, shortTasks, allDay, completedMix, recurring, heavy
    }

    /// Seeds `context` for `day` per `state`; returns the inserted tasks.
    @discardableResult
    static func seed(_ state: DayState, on day: Date, into context: ModelContext) -> [TaskItem] {
        let calendar = calendar(in: context)
        group(in: context)
        let gregorian = Calendar.current
        func at(_ hour: Int, _ minute: Int = 0) -> Date {
            gregorian.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        // An UPCOMING incomplete occurrence anchored to the harness `now` (not a
        // fixed wall-clock hour), so it stays in the future no matter what time the
        // snapshot suite runs. `TodayView.upNextOccurrence` picks the soonest open
        // upcoming occurrence, so the populated variants MUST carry one for the
        // Up-next hero Task Box to render; fixed-hour-only fixtures went past-dated
        // whenever the suite ran after that hour, collapsing every Today snapshot to
        // the "Nothing scheduled" empty state.
        func upcoming(minutesFromNow: Int) -> Date { day.addingTimeInterval(TimeInterval(minutesFromNow * 60)) }
        let blue = "#3B82F6", olive = "#466234", clay = "#BE4A28"

        switch state {
        case .empty:
            return []
        case .single:
            return [task(seriesId: "s1", title: "Standup with the platform team", start: upcoming(minutesFromNow: 75), durationMinutes: 30, groupColor: olive, calendar: calendar, in: context)]
        case .overlapping:
            return [
                task(seriesId: "s1", title: "Design review", start: at(10), durationMinutes: 90, groupColor: blue, calendar: calendar, in: context),
                task(seriesId: "s2", title: "1:1 with Pepper", start: at(10, 30), durationMinutes: 60, groupColor: clay, calendar: calendar, in: context),
                task(seriesId: "s3", title: "Lunch", start: at(11), durationMinutes: 45, groupColor: olive, calendar: calendar, in: context),
                // Upcoming open occurrence so `TodayView` has an Up-next hero to
                // render; positioned after the wall-clock cluster so the CalendarDay
                // timeline layout of the original three is preserved.
                task(seriesId: "s4", title: "Sync with the design team", start: upcoming(minutesFromNow: 90), durationMinutes: 45, groupColor: blue, calendar: calendar, in: context),
            ]
        case .shortTasks:
            return [
                task(seriesId: "s1", title: "Email triage", start: at(9), durationMinutes: 10, groupColor: blue, calendar: calendar, in: context),
                task(seriesId: "s2", title: "Standup", start: at(9, 15), durationMinutes: 15, groupColor: olive, calendar: calendar, in: context),
                task(seriesId: "s3", title: "Coffee with Happy", start: at(9, 35), durationMinutes: 10, groupColor: clay, calendar: calendar, in: context),
            ]
        case .allDay:
            return [
                task(seriesId: "s1", title: "Conference — day 1", start: at(0), isAllDay: true, groupColor: blue, calendar: calendar, in: context),
                task(seriesId: "s2", title: "Submit Q3 report", start: at(16), durationMinutes: 30, groupColor: clay, calendar: calendar, in: context),
            ]
        case .completedMix:
            return [
                task(seriesId: "s1", title: "Morning run", start: at(7), durationMinutes: 45, completed: true, groupColor: olive, calendar: calendar, in: context),
                task(seriesId: "s2", title: "Write the spec", start: at(11), durationMinutes: 90, completed: false, groupColor: blue, calendar: calendar, in: context),
                task(seriesId: "s3", title: "Review PRs", start: at(14), durationMinutes: 60, completed: true, groupColor: clay, calendar: calendar, in: context),
            ]
        case .recurring:
            return [task(seriesId: "s1", title: "Daily standup", start: at(9, 30), durationMinutes: 30, isRecurring: true, groupColor: olive, calendar: calendar, in: context)]
        case .heavy:
            var tasks = (0..<10).map { index in
                task(
                    seriesId: "s\(index)",
                    title: "Task #\(index + 1)",
                    start: at(8 + index, (index % 2) * 30),
                    durationMinutes: 45,
                    completed: index < 3,
                    groupColor: [blue, olive, clay][index % 3],
                    calendar: calendar,
                    in: context
                )
            }
            // Upcoming open occurrence so `TodayView` resolves an Up-next hero even
            // on the heaviest day; appended after the wall-clock block so the
            // CalendarDay heavy timeline layout of the ten fixed-hour tiles stands.
            tasks.append(
                task(seriesId: "s10", title: "Sync with the design team", start: upcoming(minutesFromNow: 90), durationMinutes: 45, groupColor: blue, calendar: calendar, in: context)
            )
            return tasks
        }
    }
}
