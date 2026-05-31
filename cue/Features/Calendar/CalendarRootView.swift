//
//  CalendarRootView.swift
//  cue
//

import SwiftData
import SwiftUI

/// Entry point for the Calendar tab. Owns the shared `CalendarStore`, the zoom
/// `@Namespace`, and the scope `NavigationStack`.
///
/// The stack root is the year scope; the path is seeded to
/// `[month(thisMonth), day(today)]` so the app opens on the day scope while
/// back-swipe zooms out Day → Month → Year.
///
/// Seeding happens *after first appear* (with animations disabled) and is
/// staged one level at a time — see ``seedInitialScopeIfNeeded()`` for why the
/// month scope must mount before the day is pushed, otherwise the interactive
/// zoom-out is dead on cold launch.
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
            CalendarView(user: user, onOpenToday: openTodayInDayScope)
                .navigationTransition(.zoom(sourceID: day, in: zoom))
        }
    }

    /// Opens *today* in the day scope by re-anchoring the top `.day` route to
    /// today (and selecting it). Distinct from the in-scope "Today" pill, which
    /// only recenters the pager: this re-targets the navigation entry itself, so
    /// it reaches today even when the current day is outside the pager's ±90-day
    /// window and gives the day scope a today-anchored zoom source. Swaps the
    /// top entry in place (rather than pushing) so the stack stays
    /// Year → Month → Day rather than deepening.
    ///
    /// Only reachable from the day scope's "open today" button, which shows
    /// solely when the current day isn't today — so the top route is always a
    /// non-today `.day` and the remove-then-append is a clean re-anchor.
    private func openTodayInDayScope() {
        let today = CalendarMath.startOfDay(.now)
        store.selectedDate = today
        path.removeLast()
        path.append(CalendarScopeRoute.day(today))
    }

    /// Resets the calendar back to *today's day page* from the year or month
    /// overview — the "back to right now" action behind the nav-bar button in
    /// those scopes. Distinct from each scope's in-place "Today" pill, which only
    /// recenters that scope (year stays on year, month on month): this drills all
    /// the way down to today's day, regardless of where the user has scrolled to.
    private func openTodayDay() {
        store.selectedDate = CalendarMath.startOfDay(.now)
        Task { await stageTodayDayPath() }
    }

    /// Rebuilds the navigation path to `[month(thisMonth), day(today)]`, pushing
    /// one level at a time with a yielded tick between pushes so the month scope
    /// mounts and registers today's zoom source before the day is pushed — the
    /// same staging ``seedInitialScopeIfNeeded()`` relies on to keep the
    /// interactive zoom-out alive (here, after the jump). Animations are disabled
    /// so the reset lands instantly rather than zooming through two levels.
    private func stageTodayDayPath() async {
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            path = NavigationPath()
            path.append(CalendarScopeRoute.month(CalendarMath.startOfMonth(.now)))
        }
        await Task.yield()

        withTransaction(transaction) {
            path.append(CalendarScopeRoute.day(CalendarMath.startOfDay(.now)))
        }
    }

    /// Opens the app on the day scope, then deep-links into the month and day
    /// scopes *one level at a time across run-loop ticks* so the interactive
    /// zoom-out gesture works on the very first cold launch.
    ///
    /// Why staged rather than a single `path = [month, day]` append: the `.zoom`
    /// pop is interactive only when the *destination's parent* has rendered a
    /// `.matchedTransitionSource` for the same id. Those sources live in lazy
    /// grids (`YearMonthCell` in the year root, `MonthDayCell` in the month
    /// scope) and are realized only when their page is actually laid out on
    /// screen. Appending both routes in one transaction jumps straight to the
    /// day scope, so the month scope never lays out its grid and the
    /// today-cell source for the day-zoom is never registered — leaving the
    /// back-swipe dead until the user manually pops to the month (which finally
    /// renders it) and drills back in. That was the real cold-launch bug.
    ///
    /// Pushing month, yielding a tick for `MonthScopeView` to mount and lay out
    /// its grid (registering the day source), then pushing day, makes every
    /// level's matched source live before we rest on the day scope. Animations
    /// stay disabled so the staged open is still visually instantaneous.
    private func seedInitialScopeIfNeeded() async {
        guard !hasSeededPath else { return }
        hasSeededPath = true

        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            path.append(CalendarScopeRoute.month(CalendarMath.startOfMonth(.now)))
        }
        // Let the month scope mount and lay out its grid so today's
        // `MonthDayCell` registers as the zoom source before we push the day.
        await Task.yield()

        withTransaction(transaction) {
            path.append(CalendarScopeRoute.day(CalendarMath.startOfDay(.now)))
        }
    }

    private func selectMonth(_ anchor: Date) {
        path.append(CalendarScopeRoute.month(anchor))
    }

    private func selectDay(_ day: Date) {
        store.selectedDate = day
        path.append(CalendarScopeRoute.day(day))
    }
}
