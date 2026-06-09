//
//  CalendarRootView.swift
//  cue
//

import SwiftData
import SwiftUI

/// Entry point for the Calendar tab. Owns the shared `CalendarStore`, the
/// `CalendarZoomContainer` (which hosts the year/month/day scopes and the
/// continuous zoom between them), and a `NavigationStack` used only for leaf
/// pushes (task detail).
///
/// Scope changes are zooms *within* the container, not navigation — so there
/// is no path seeding, no deep-link choreography, and the day scope renders
/// directly on cold launch.
///
/// It also owns the foreground-refresh trigger: this view observes
/// `@Environment(\.scenePhase)` and, on a return to `.active`, asks the store
/// to refetch the visible month. Observation lives here (rather than at
/// `RootView`) because this is where the `CalendarStore` and its
/// `modelContext` are in scope, and the Calendar tab only mounts once the
/// user is authenticated.
struct CalendarRootView: View {
    let user: UserDTO

    @Environment(AuthStore.self) private var authStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationStore.self) private var notifications

    @State private var store: CalendarStore
    @State private var path = NavigationPath()

    init(user: UserDTO) {
        self.user = user
        _store = State(initialValue: CalendarStore(user: user))
    }

    var body: some View {
        NavigationStack(path: $path) {
            CalendarZoomContainer(user: user, onSelectEvent: { path.append($0) })
                .navigationDestination(for: ScheduleEvent.self) { event in
                    TaskDetailScreen(event: event)
                }
        }
        .environment(store)
        .task { store.bind(notifications: notifications) }
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
}
