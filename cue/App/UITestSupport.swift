//
//  UITestSupport.swift
//  cue
//

#if DEBUG
import Foundation
import SwiftData

/// Hermetic UI-test mode. When the app is launched with `--uitest`, it boots
/// straight into an authenticated session backed by a deterministic in-memory
/// store, with all network sync disabled — so XCUITest flows are fast, offline,
/// and repeatable. DEBUG-only: compiled out of release builds entirely.
enum UITestSupport {
    /// Launch argument that activates UI-test mode (set via `XCUIApplication.launchArguments`).
    static let launchArgument = "--uitest"

    /// True when the current process was launched for UI testing.
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// Deterministic signed-in user used while UI testing.
    static let user = UserDTO(
        id: "usr_uitest",
        appleUserId: "apple_uitest",
        email: "tony@stark.com",
        displayName: "Tony Stark",
        avatarBase64: nil,
        timezone: TimeZone.current.identifier,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    /// Seeds the container with a calendar, a group, and a handful of today's
    /// tasks — including incomplete, completion-requiring ones the toggle flows
    /// can act on. Idempotent enough for a fresh in-memory store per launch.
    static func seed(into container: ModelContainer) {
        let context = container.mainContext
        let calendar = EventCalendar(id: "cal-uitest", name: "Personal", colorHex: "#466234")
        context.insert(calendar)
        let group = EventTaskGroup(id: "grp-uitest", calendarId: calendar.id, name: "Work", colorHex: "#3B82F6")
        context.insert(group)

        let gregorian = Calendar.current
        func at(_ hour: Int, _ minute: Int = 0) -> Date {
            gregorian.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
        }
        // An UPCOMING incomplete occurrence anchored to `now` (not a fixed wall-clock
        // hour), so it is always in the future regardless of when the suite runs.
        // `TodayView.upNextOccurrence` then resolves it as the Up-next hero, which
        // exposes the `task.toggle` accessibility id the smoke test taps. A fixed-
        // hour seed became past-dated whenever the tests ran after that hour, so no
        // hero rendered and the toggle never appeared.
        let upcomingStart = Date.now.addingTimeInterval(75 * 60)
        let fixtures: [(seriesId: String, title: String, start: Date, minutes: Int, completed: Bool, color: String)] = [
            ("u0", "Sync with the design team", upcomingStart, 45, false, "#3B82F6"),
            ("u1", "Standup with the platform team", at(9, 30), 30, false, "#466234"),
            ("u2", "Design review", at(11), 60, false, "#3B82F6"),
            ("u3", "Submit Q3 expense report", at(16), 30, false, "#BE4A28"),
            ("u4", "Morning run", at(7), 45, true, "#466234"),
        ]
        for fixture in fixtures {
            let task = TaskItem(
                occurrenceKey: TaskItem.makeKey(seriesId: fixture.seriesId, occurrenceStart: fixture.start),
                seriesId: fixture.seriesId,
                occurrenceStart: fixture.start,
                occurrenceEnd: fixture.start.addingTimeInterval(TimeInterval(fixture.minutes * 60)),
                originalStart: fixture.start,
                title: fixture.title,
                requiresCompletion: true,
                completedAt: fixture.completed ? Date(timeIntervalSince1970: 1_700_000_000) : nil,
                groupColorToken: fixture.color
            )
            task.calendar = calendar
            context.insert(task)
        }
        try? context.save()
    }
}
#endif
