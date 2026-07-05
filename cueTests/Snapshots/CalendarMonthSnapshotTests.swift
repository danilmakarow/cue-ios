//
//  CalendarMonthSnapshotTests.swift
//  cueTests
//
//  Design-fidelity snapshots for the Calendar tab's MONTH scope.
//
//  Why this drives the UIKit `MonthScopeViewController` directly rather than
//  `CalendarHostView`: the SwiftUI host bridges in `CalendarContainerViewController`,
//  which ALWAYS rests/launches on the day scope (`active = dayScope`) and only
//  mounts the month scope lazily in response to a pinch/tap-driven zoom. That zoom
//  is gesture-driven and not statically reachable from a snapshot test — there is
//  no public API on the container to start in, or switch to, the month scope. The
//  month scope itself, however, is a fully self-contained `UIViewController`
//  constructed from the same four shared dependencies the container injects
//  (store, adapter, modelContext, theme), and it reads its per-day chips
//  synchronously from SwiftData via the adapter. So we build it directly over a
//  seeded in-memory store — the faithful month surface, minus the (irrelevant for a
//  still capture) zoom chrome.
//
//  Each test seeds a fixed month (June 2026, mirroring the "June" populated grid in
//  the design reference), points the store's selection into that month so the
//  infinite-section window seeds around it, then renders the scope and records a
//  PNG named "calendar-month-<state>".
//

import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import cue

@MainActor
struct CalendarMonthSnapshotTests {

    // MARK: - Fixtures

    /// Fixed anchor day inside the captured month so snapshots are deterministic
    /// regardless of the wall clock. June 15 2026 (local time) sits comfortably
    /// mid-month, matching the design reference's "June" overview.
    private static func anchorDay() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15
        components.hour = 12
        return Calendar.current.date(from: components) ?? Date(timeIntervalSince1970: 1_781_000_000)
    }

    /// A date at `hour`:`minute` on the given day-of-`month`, within the anchor month.
    private static func dayInMonth(_ dayOfMonth: Int, hour: Int = 9, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: anchorDay())
        components.day = dayOfMonth
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? anchorDay()
    }

    /// Builds a store whose selection sits inside the captured month, so the
    /// month scope's section window seeds around it.
    private static func makeStore() -> CalendarStore {
        CalendarStore(user: MockData.user, today: Calendar.current.startOfDay(for: anchorDay()))
    }

    /// Resolved Clean-theme UIKit theme for the scope (light palette).
    private static func makeTheme() -> CalendarTheme {
        CalendarTheme(colors: AppPalette.kraftInk.colors, traits: UITraitCollection.current)
    }

    /// Seeds a busy month: several days carry one or more occurrences across the
    /// five group colors, a recurring all-day bill, an all-day birthday, and a few
    /// "heavy" days (4–5 events) so the grid shows chip stacks and "+N more"
    /// overflow — mirroring the design reference's populated June.
    @discardableResult
    private static func seedBusyMonth(into context: ModelContext) -> [TaskItem] {
        let calendar = MockData.calendar(in: context)
        MockData.group(in: context)
        let blue = "#3B82F6", olive = "#466234", clay = "#BE4A28", gold = "#C9A24B", rose = "#A54B5A"

        var tasks: [TaskItem] = []
        func add(_ day: Int, _ title: String, hour: Int, minute: Int = 0, color: String, allDay: Bool = false, recurring: Bool = false, completed: Bool = false) {
            tasks.append(
                MockData.task(
                    seriesId: "m-\(day)-\(title)",
                    title: title,
                    start: dayInMonth(day, hour: hour, minute: minute),
                    durationMinutes: 60,
                    isAllDay: allDay,
                    completed: completed,
                    isRecurring: recurring,
                    groupColor: color,
                    calendar: calendar,
                    in: context
                )
            )
        }

        add(3, "Standup", hour: 9, minute: 30, color: olive)
        add(8, "Dentist", hour: 9, color: clay)
        add(8, "Sprint review", hour: 11, color: blue)
        // A heavy day: 4 events → chip stack + "+N more".
        add(15, "Pay rent", hour: 0, color: gold, allDay: true, recurring: true)
        add(15, "Call plumber", hour: 13, color: clay)
        add(15, "Groceries", hour: 17, color: clay)
        add(15, "Gym class", hour: 19, color: clay)
        add(17, "Flight BER→LIS", hour: 6, minute: 40, color: "#6E5C4C")
        add(18, "Mom's birthday", hour: 0, color: rose, allDay: true)
        add(21, "Review PR", hour: 15, color: blue, completed: true)
        // Another heavy day.
        add(24, "1:1 Anna", hour: 10, color: blue)
        add(24, "Lunch w/Sam", hour: 12, minute: 30, color: clay)
        add(24, "Design review", hour: 13, color: blue)
        add(24, "Sync w/ Mark", hour: 15, minute: 30, color: blue)
        add(24, "Invoice Acme", hour: 17, color: gold)
        add(25, "Lunch", hour: 12, minute: 30, color: clay)
        add(28, "Invoice Acme", hour: 16, color: gold)

        try? context.save()
        return tasks
    }

    /// Seeds a sparse month: a handful of single-event days, no overflow — the
    /// quieter end of the populated spectrum.
    @discardableResult
    private static func seedSparseMonth(into context: ModelContext) -> [TaskItem] {
        let calendar = MockData.calendar(in: context)
        MockData.group(in: context)
        let olive = "#466234", blue = "#3B82F6", clay = "#BE4A28"
        let tasks = [
            MockData.task(seriesId: "sp-1", title: "Standup", start: dayInMonth(4, hour: 9, minute: 30), groupColor: olive, calendar: calendar, in: context),
            MockData.task(seriesId: "sp-2", title: "Design review", start: dayInMonth(11, hour: 14), groupColor: blue, calendar: calendar, in: context),
            MockData.task(seriesId: "sp-3", title: "1:1 with Pepper", start: dayInMonth(19, hour: 10), groupColor: clay, calendar: calendar, in: context),
            MockData.task(seriesId: "sp-4", title: "Ship release", start: dayInMonth(26, hour: 16), completed: true, groupColor: olive, calendar: calendar, in: context),
        ]
        try? context.save()
        return tasks
    }

    /// Builds the month scope over `container`, mirroring the dependency wiring the
    /// container does in `makeScope(.month)`, and wraps it edge-to-edge in SwiftUI.
    private static func monthScope(over container: ModelContainer, store: CalendarStore) -> some View {
        let context = container.mainContext
        let adapter = CalendarDataAdapter(context: context, store: store)
        let viewController = MonthScopeViewController(
            store: store,
            adapter: adapter,
            modelContext: context,
            theme: makeTheme(),
            prefetchCoordinator: PrefetchCoordinator()
        )
        return MonthScopeRepresentable(viewController: viewController)
            .ignoresSafeArea()
    }

    // MARK: - Tests

    /// A busy month — multiple events per day, all-day chips, recurring + completed
    /// markers, and heavy days that overflow into "+N more". The primary state.
    @Test
    func populated() {
        let container = MockData.container()
        let store = Self.makeStore()
        Self.seedBusyMonth(into: container.mainContext)

        let screen = ScreenHost.wrap(
            Self.monthScope(over: container, store: store),
            container: container
        )
        #expect(SnapshotHarness.record(screen, named: "calendar-month-populated") != nil)
    }

    /// A sparse month — a few single-event days, no chip overflow.
    @Test
    func sparse() {
        let container = MockData.container()
        let store = Self.makeStore()
        Self.seedSparseMonth(into: container.mainContext)

        let screen = ScreenHost.wrap(
            Self.monthScope(over: container, store: store),
            container: container
        )
        #expect(SnapshotHarness.record(screen, named: "calendar-month-sparse") != nil)
    }

    /// An empty month — grid + weekday legend + month title, no day chips. The
    /// baseline scaffold.
    @Test
    func empty() {
        let container = MockData.container()
        let store = Self.makeStore()
        // No seeding — the calendar/group are unnecessary for an empty grid.

        let screen = ScreenHost.wrap(
            Self.monthScope(over: container, store: store),
            container: container
        )
        #expect(SnapshotHarness.record(screen, named: "calendar-month-empty") != nil)
    }
}

// MARK: - UIKit bridge

/// Minimal SwiftUI bridge for a single ``MonthScopeViewController`` instance, so a
/// snapshot test can host the UIKit month scope inside the harness's hosting
/// window exactly as `CalendarUIKitView` hosts the container. Holds the VC by
/// reference (it carries the seeded adapter + store) and presents it edge-to-edge.
private struct MonthScopeRepresentable: UIViewControllerRepresentable {
    let viewController: MonthScopeViewController

    func makeUIViewController(context: Context) -> MonthScopeViewController { viewController }
    func updateUIViewController(_ uiViewController: MonthScopeViewController, context: Context) {}
}
