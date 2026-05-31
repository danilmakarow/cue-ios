//
//  CalendarRootView.swift
//  cue
//

import SwiftData
import SwiftUI

/// Entry point for the Calendar tab. Owns the shared `CalendarStore`, the zoom
/// `@Namespace`, and the scope `NavigationStack`.
///
/// The stack root is the year scope; the path is seeded at launch to
/// `[month(thisMonth), day(today)]` so the app opens on the day scope while
/// back-swipe zooms out Day → Month → Year. (A programmatically-seeded stack
/// renders without a zoom on cold launch — there's no on-screen source cell to
/// morph from — which is the desired behavior.)
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

    @State private var store: CalendarStore
    @State private var path: NavigationPath
    @Namespace private var zoom

    init(user: UserDTO) {
        self.user = user
        _store = State(initialValue: CalendarStore(user: user))

        var seeded = NavigationPath()
        seeded.append(CalendarScopeRoute.month(CalendarMath.startOfMonth(.now)))
        seeded.append(CalendarScopeRoute.day(CalendarMath.startOfDay(.now)))
        _path = State(initialValue: seeded)
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
        .toolbar(.hidden, for: .tabBar)
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

    private func selectMonth(_ anchor: Date) {
        path.append(CalendarScopeRoute.month(anchor))
    }

    private func selectDay(_ day: Date) {
        store.selectedDate = day
        path.append(CalendarScopeRoute.day(day))
    }
}
