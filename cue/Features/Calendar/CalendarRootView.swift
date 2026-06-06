//
//  CalendarRootView.swift
//  cue
//

import SwiftData
import SwiftUI

/// Entry point for the Calendar tab. Owns the shared `CalendarStore`, the zoom
/// `@Namespace`, the `ZoomSourceRegistry`, and the scope `NavigationStack`.
///
/// The stack root is the year scope; the path is seeded to
/// `[month(thisMonth), day(today)]` so the app opens on the day scope while
/// back-swipe zooms out Day → Month → Year.
///
/// Seeding (and every programmatic "go to today") happens *after first appear*
/// with animations disabled and routes through ``deepLinkToDay(_:inMonth:)``,
/// which pushes the month, *waits for its lazy grid to realize today's zoom
/// source* via the `ZoomSourceRegistry`, then pushes the day — so the
/// interactive zoom-out has a live anchor instead of racing layout. Without
/// that handshake the zoom-out is dead on cold launch and after a jump.
///
/// It also owns the foreground-refresh trigger: this view observes
/// `@Environment(\.scenePhase)` and, on a return to `.active`, asks the store to
/// refetch the visible month. Observation lives here (rather than at `RootView`)
/// because this is where the `CalendarStore` and its `modelContext` are in
/// scope, and the Calendar tab only mounts once the user is authenticated.
struct CalendarRootView: View {
    let user: UserDTO

    @Environment(AuthStore.self) private var authStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationStore.self) private var notifications

    @State private var store: CalendarStore
    @State private var path = NavigationPath()
    @State private var hasSeededPath = false
    @State private var zoomSources = ZoomSourceRegistry()
    @Namespace private var zoom

    init(user: UserDTO) {
        self.user = user
        _store = State(initialValue: CalendarStore(user: user))
    }

    var body: some View {
        NavigationStack(path: $path) {
            YearScopeView(namespace: zoom, onSelectMonth: selectMonth, onOpenToday: openTodayDay)
                .navigationDestination(for: CalendarScopeRoute.self) { route in
                    scopeDestination(route)
                }
        }
        .environment(store)
        .environment(zoomSources)
        .task {
            store.bind(notifications: notifications)
            await seedInitialScopeIfNeeded()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    /// Refetches the visible month when the app returns to the foreground.
    ///
    /// Only acts on a transition *into* `.active`, and only while authenticated.
    /// A real background trip (`.background → .active`) always refetches; a brief
    /// `.inactive → .active` blip (banner, Control Center) defers to the store's
    /// staleness threshold so it doesn't spam the API. The store guards overlap.
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        guard newPhase == .active else { return }
        guard case .authenticated = authStore.state else { return }

        let wasBackgrounded = oldPhase == .background
        store.refreshIfStale(context: modelContext, wasBackgrounded: wasBackgrounded)
    }

    @ViewBuilder
    private func scopeDestination(_ route: CalendarScopeRoute) -> some View {
        switch route {
        case .month(let anchor):
            MonthScopeView(monthAnchor: anchor, namespace: zoom, onSelectDay: selectDay, onOpenToday: openTodayDay)
                .navigationTransition(.zoom(sourceID: anchor, in: zoom))
        case .day(let day):
            CalendarView(user: user, onOpenToday: openTodayInDayScope, onSelect: selectEvent)
                .navigationTransition(.zoom(sourceID: day, in: zoom))
        case .taskDetail(let event):
            TaskDetailScreen(event: event)
        }
    }

    /// Opens *today* in the day scope from the day scope's own nav-bar "today"
    /// button. Distinct from the in-scope "Today" pill, which only recenters the
    /// pager: this re-targets the navigation entries themselves, so it reaches
    /// today even when the current day is outside the pager's ±90-day window.
    ///
    /// Rebuilds the stack to `[month(thisMonth), day(today)]` via
    /// ``deepLinkToDay(_:inMonth:)`` rather than swapping only the top `.day` in
    /// place: if the parent month doesn't contain today (the user scrolled the
    /// month list elsewhere before drilling in), re-anchoring just the day would
    /// leave the parent without today's matched source and kill the zoom-out.
    /// Going through the deep-link makes the parent today's month with a realized
    /// source cell. The resulting depth `[month, day]` is the correct drill-in
    /// depth, so the stack stays Year → Month → Day rather than deepening.
    ///
    /// Only reachable from the day scope's "open today" button, which shows
    /// solely when the current day isn't today.
    private func openTodayInDayScope() {
        let today = CalendarMath.startOfDay(.now)
        Task { await deepLinkToDay(today, inMonth: CalendarMath.startOfMonth(today)) }
    }

    /// Resets the calendar back to *today's day page* from the year or month
    /// overview — the "back to right now" action behind the nav-bar button in
    /// those scopes. Distinct from each scope's in-place "Today" pill, which only
    /// recenters that scope (year stays on year, month on month): this drills all
    /// the way down to today's day, regardless of where the user has scrolled to.
    private func openTodayDay() {
        Task {
            await deepLinkToDay(CalendarMath.startOfDay(.now), inMonth: CalendarMath.startOfMonth(.now))
        }
    }

    /// Builds the stack to `[month(month), day(day)]` deterministically, pushing
    /// *both* levels via their zoom animation so *both* interactive zoom-outs are
    /// armed: any existing stack is first collapsed to the year root without
    /// animation, then the month is pushed animated (arming month → year), its
    /// day source is awaited, and the day is pushed animated (arming day →
    /// month). An animations-disabled push only *places* a destination without
    /// establishing a reversible zoom presentation — that, not a missing source,
    /// was why the programmatic zoom-outs (cold launch, "go to today") were dead.
    /// The zoom-out itself is a two-finger pinch / one-finger swipe-down.
    ///
    /// Awaiting the month's `MonthDayCell` for `day` (via the registry) both
    /// guarantees the day's matched source exists before the day is pushed and
    /// keeps the two pushes as separate transactions, so each establishes its own
    /// zoom presentation instead of coalescing into a single jump.
    ///
    /// The single entry point for *every* programmatic day-open (cold-launch
    /// seed, both "go to today" buttons). `day` must be `startOfDay`-normalized
    /// and `month` its `startOfMonth`: the grid's day cells are produced at
    /// midnight, so this `day` is byte-equal to the cell's
    /// `matchedTransitionSource(id:)`, the registry key it reports, and the
    /// `.day(...)` route value — the three-way equality the zoom requires.
    private func deepLinkToDay(_ day: Date, inMonth month: Date) async {
        store.selectedDate = day

        // Collapse any existing stack to the year root without animation, so only
        // the level pushes below carry a zoom. Skipped on cold launch (path
        // already empty); the yield lets the collapse commit before the animated
        // month push so the two don't merge into one transaction.
        if !path.isEmpty {
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { path = NavigationPath() }
            await Task.yield()
        }

        // Push the month WITH its zoom animation so its zoom presentation is
        // established and the month → year interactive zoom-out is armed.
        path.append(CalendarScopeRoute.month(month))

        // Await the month's `MonthDayCell` for `day` mounting (bounded ~1s inside
        // the registry): guarantees the day's matched source exists before the
        // day push, and keeps the month and day pushes as separate animated
        // transactions so each establishes its own zoom presentation.
        await zoomSources.waitUntilPresent(day)

        // Push the day WITH its zoom animation so the day → month zoom-out is
        // likewise armed.
        path.append(CalendarScopeRoute.day(day))
    }

    /// Seeds the calendar onto today's day page on first appear via
    /// ``deepLinkToDay(_:inMonth:)``, so the interactive zoom-out gesture works
    /// on the very first cold launch. One-shot, guarded by `hasSeededPath`.
    private func seedInitialScopeIfNeeded() async {
        guard !hasSeededPath else { return }
        hasSeededPath = true

        await deepLinkToDay(CalendarMath.startOfDay(.now), inMonth: CalendarMath.startOfMonth(.now))
    }

    private func selectMonth(_ anchor: Date) {
        path.append(CalendarScopeRoute.month(anchor))
    }

    private func selectDay(_ day: Date) {
        store.selectedDate = day
        path.append(CalendarScopeRoute.day(day))
    }

    private func selectEvent(_ event: ScheduleEvent) {
        path.append(CalendarScopeRoute.taskDetail(event))
    }
}
