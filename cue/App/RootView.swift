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

        TabView(selection: $navigation.selectedTab) {
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
        }
        // iOS 26 polish: the Liquid Glass tab bar shrinks while the user scrolls
        // down a tab's content, then re-expands on scroll-up.
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    RootView()
        .environment(AuthStore())
        .environment(AppNavigation())
        .environment(ThemeSettings())
}
