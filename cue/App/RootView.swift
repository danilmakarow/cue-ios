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
/// The tabbed app hides the system tab bar on every root screen; each screen
/// renders our own `AppTabBar` via `.safeAreaInset(edge: .bottom)`. Pushed
/// destinations don't include the inset, so the bar is simply absent on detail
/// pages — no hide/show animation, no flicker.
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
                        .toolbar(.hidden, for: .tabBar)
                }
            }
            Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                        .toolbar(.hidden, for: .tabBar)
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AuthStore())
        .environment(AppNavigation())
        .environment(ThemeSettings())
}
