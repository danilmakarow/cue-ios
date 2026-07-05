//
//  EventDetailSnapshotTests.swift
//  cueTests
//
//  Snapshot suite for the task/event detail screen (`TaskDetailScreen`). Renders
//  one PNG per meaningful occurrence state — a pure timed event, a completable
//  task (incomplete + completed), and a recurring task — by constructing
//  `ScheduleEvent` fixtures inline and hosting the screen through `ScreenHost`
//  over a seeded in-memory store.
//
//  The screen's `.task` fires a best-effort `GET /tasks/:id` for the series
//  detail (reminders + recurrence summary). The backend is not reachable in the
//  test process, so that fetch is a no-op; the capture reads the synchronously
//  available `ScheduleEvent` state, which is what these snapshots assert on.
//

import SwiftData
import SwiftUI
import Testing
@testable import cue

@MainActor
struct EventDetailSnapshotTests {
    /// A FUTURE reference instant (~4 months ahead of the render's "now"), so the
    /// detail sheet exercises the human-friendly time-until row
    /// (`RelativeTimeFormatter.timeUntil` → e.g. "in 4 mo") the design places near
    /// the time band — a fixed past instant suppressed it (the countdown renders
    /// only for a future/current occurrence). Anchored to a stable time-of-day so
    /// the absolute range stays visually steady across runs.
    private static let baseStart: Date = {
        let calendar = Calendar.current
        let inFourMonths = calendar.date(byAdding: .month, value: 4, to: .now) ?? .now
        return calendar.date(
            bySettingHour: 9, minute: 30, second: 0, of: inFourMonths
        ) ?? inFourMonths
    }()

    /// Builds a fresh seeded container plus the synced group whose name the
    /// header meta row resolves (`groupId` -> `EventTaskGroup.name`).
    private func makeContainer() -> ModelContainer {
        let container = MockData.container()
        MockData.group(id: "grp-work", calendarId: "cal-1", name: "Work", color: "#466234", in: container.mainContext)
        return container
    }

    /// Hosts `TaskDetailScreen` in a NavigationStack so the inline nav title and
    /// trailing edit button render as in the app.
    private func host(_ event: ScheduleEvent, container: ModelContainer) -> some View {
        ScreenHost.wrap(
            NavigationStack { TaskDetailScreen(event: event) },
            container: container
        )
    }

    // MARK: - Timed event (incomplete, no completion fork)

    @Test func timedEventIncomplete() {
        let container = makeContainer()
        let start = Self.baseStart
        let event = ScheduleEvent(
            id: "evt-timed#1",
            seriesId: "evt-timed",
            occurrenceStart: start,
            originalStart: start,
            title: "Design review with the platform team",
            notes: "Walk through the new token system and the day-strip rewrite.",
            startAt: start,
            endAt: start.addingTimeInterval(90 * 60),
            groupId: "grp-work",
            groupColorToken: "#466234",
            requiresCompletion: false
        )
        #expect(SnapshotHarness.record(host(event, container: container), named: "event-detail-timed-event") != nil)
    }

    // MARK: - Completable task (incomplete — decisive "Mark done" CTA)

    @Test func completableTaskIncomplete() {
        let container = makeContainer()
        let start = Self.baseStart
        let event = ScheduleEvent(
            id: "evt-task#1",
            seriesId: "evt-task",
            occurrenceStart: start,
            originalStart: start,
            title: "Write the Q3 planning spec",
            notes: "Lead with Context, Goals, Non-goals.",
            startAt: start,
            endAt: start.addingTimeInterval(60 * 60),
            groupId: "grp-work",
            groupColorToken: "#3B82F6",
            requiresCompletion: true,
            completedAt: nil
        )
        #expect(SnapshotHarness.record(host(event, container: container), named: "event-detail-completable-task") != nil)
    }

    // MARK: - Completed task (olive check, strikethrough, "Mark not done")

    @Test func completedTask() {
        let container = makeContainer()
        let start = Self.baseStart
        let event = ScheduleEvent(
            id: "evt-done#1",
            seriesId: "evt-done",
            occurrenceStart: start,
            originalStart: start,
            title: "Morning run",
            notes: "5k along the river.",
            startAt: start,
            endAt: start.addingTimeInterval(45 * 60),
            groupId: "grp-work",
            groupColorToken: "#466234",
            requiresCompletion: true,
            completedAt: start.addingTimeInterval(50 * 60)
        )
        #expect(SnapshotHarness.record(host(event, container: container), named: "event-detail-completed-task") != nil)
    }

    // MARK: - Recurring task (repeat badge + recurrence + applies-to picker)

    @Test func recurringTask() {
        let container = makeContainer()
        let start = Self.baseStart
        let event = ScheduleEvent(
            id: "evt-recur#1",
            seriesId: "evt-recur",
            occurrenceStart: start,
            originalStart: start,
            title: "Daily standup",
            notes: nil,
            startAt: start,
            endAt: start.addingTimeInterval(30 * 60),
            groupId: "grp-work",
            groupColorToken: "#466234",
            requiresCompletion: true,
            completedAt: nil,
            isRecurring: true
        )
        #expect(SnapshotHarness.record(host(event, container: container), named: "event-detail-recurring") != nil)
    }
}
