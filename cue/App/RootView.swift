//
//  RootView.swift
//  cue
//

import SwiftUI

/// Root container of the app. Gates the tab UI behind auth state.
///
/// - `.loading` — initial splash while `AuthStore.bootstrap()` validates any
///   persisted JWT against `/auth/me`.
/// - `.unauthenticated` — shows `AuthView` with Sign in with Apple.
/// - `.authenticated` — shows the tabbed main app.
///
/// The tabbed app uses a native `TabView`, so on iOS 26 the bottom bar renders
/// with Liquid Glass automatically — no custom chrome. The bar persists across
/// pushes within each tab's `NavigationStack` (standard iOS behavior) and
/// minimizes on scroll-down.
struct RootView: View {
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        Group {
            switch authStore.state {
            case .loading:
                LoadingView()
            case .unauthenticated:
                AuthView()
            case .authenticated(let user):
                MainTabs(user: user)
            }
        }
        .task {
            if case .loading = authStore.state {
                await authStore.bootstrap()
            }
        }
        // Global notification overlay — rendered above every screen (loading,
        // auth, and the tabbed app) so banners are visible regardless of auth
        // state. The host reads `NotificationStore` from the environment.
        .notificationHost()
    }
}

/// Tabbed experience shown once the user is authenticated. Split out so it can
/// freely read `AppNavigation` from the environment without the loading and
/// auth branches needing it.
private struct MainTabs: View {
    @Environment(AppNavigation.self) private var navigation
    let user: UserDTO

    var body: some View {
        @Bindable var navigation = navigation

        TabView(selection: tabSelection) {
            Tab(AppTab.calendar.title, systemImage: AppTab.calendar.systemImage, value: AppTab.calendar) {
                CalendarRootView(user: user)
            }
            Tab(AppTab.dashboard.title, systemImage: AppTab.dashboard.systemImage, value: AppTab.dashboard) {
                NavigationStack {
                    DashboardView()
                }
            }
            Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                }
            }
            // "New Event" lives in the native tab bar as its own round item next
            // to the real tabs, so it inherits Liquid Glass for free (no
            // hand-rolled bar). It's an *action* item, not a destination: the
            // `tabSelection` setter below intercepts a tap, opens the New Event
            // sheet, and keeps the previously-selected tab — so it never
            // "selects" and its empty content never shows.
            Tab(AppTab.newEvent.title, systemImage: AppTab.newEvent.systemImage, value: AppTab.newEvent) {
                EmptyView()
            }
        }
        // iOS 26 polish: the Liquid Glass tab bar shrinks while the user scrolls
        // down a tab's content, then re-expands on scroll-up.
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $navigation.isPresentingNewEvent) {
            NavigationStack {
                NewEventScreen()
            }
        }
    }

    /// Tab-selection binding that treats `.newEvent` as a one-shot action: when
    /// the user taps it, present the New Event sheet and *keep* the current tab
    /// rather than switching. All real tabs pass through unchanged.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { navigation.selectedTab },
            set: { tapped in
                guard tapped == .newEvent else {
                    navigation.selectedTab = tapped
                    return
                }
                navigation.isPresentingNewEvent = true
            }
        )
    }
}

#Preview {
    RootView()
        .environment(AuthStore())
        .environment(AppNavigation())
        .environment(ThemeSettings())
        .environment(NotificationStore())
}
