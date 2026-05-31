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
/// Seeding happens *after first appear* (with animations disabled), not in
/// `init`. Pushing the scopes through the live `path` binding — the same code
/// path a user tap takes — registers each `.zoom` transition's source and wires
/// the interactive back-swipe. Pre-seeding a `NavigationPath` in `init` left the
/// gesture dead on cold launch (the destinations existed but their matched
/// sources never had, so the edge-swipe pop wouldn't attach until the user
/// popped via the back button and drilled in again). Disabling animations keeps
/// the deep open instantaneous, so there's no visible Year → Month → Day push.
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
            YearScopeView(namespace: zoom, onSelectMonth: selectMonth)
                .navigationDestination(for: CalendarScopeRoute.self) { route in
                    scopeDestination(route)
                }
                .navigationDestination(for: CalendarRoute.self) { route in
                    switch route {
                    case .newEvent: NewEventScreen()
                    }
                }
        }
        .environment(store)
        .task {
            store.bind(notifications: notifications)
            seedInitialScopeIfNeeded()
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
            MonthScopeView(monthAnchor: anchor, namespace: zoom, onSelectDay: selectDay)
                .navigationTransition(.zoom(sourceID: anchor, in: zoom))
        case .day(let day):
            CalendarView(user: user)
                .navigationTransition(.zoom(sourceID: day, in: zoom))
        }
    }

    /// Opens the app on the day scope by pushing month → day through the live
    /// path binding once, with animation suppressed so the deep open is
    /// instantaneous. Driving it through `path` (rather than seeding in `init`)
    /// is what makes the back-swipe zoom-out work on cold launch.
    private func seedInitialScopeIfNeeded() {
        guard !hasSeededPath else { return }
        hasSeededPath = true

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            path.append(CalendarScopeRoute.month(CalendarMath.startOfMonth(.now)))
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
