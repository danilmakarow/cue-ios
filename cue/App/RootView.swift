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
/// pushes within each tab's `NavigationStack` (standard iOS behavior) and stays
/// fully expanded at all times — it never minimizes/collapses on scroll.
struct RootView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(AppNavigation.self) private var navigation

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
        // Capture Telegram linking deep links from any auth state. The code is
        // parked on `AppNavigation`; the "Connect Telegram?" sheet (in
        // `MainTabs`) only presents once authenticated, so a link tapped while
        // signed out surfaces automatically after Apple sign-in.
        .onOpenURL { url in
            if case .telegramLink(let code) = DeepLink(url: url) {
                navigation.pendingTelegramCode = code
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
            Tab(AppTab.calendar.titleKey, systemImage: AppTab.calendar.systemImage, value: AppTab.calendar) {
                CalendarHostView(user: user)
            }
            Tab(AppTab.dashboard.titleKey, systemImage: AppTab.dashboard.systemImage, value: AppTab.dashboard) {
                NavigationStack {
                    DashboardView()
                }
            }
            Tab(AppTab.settings.titleKey, systemImage: AppTab.settings.systemImage, value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                }
            }
            // "New Event" sits in the tab bar as a *standalone* trailing item,
            // detached from the three destination tabs (which stay merged in the
            // main group). The `.search` role is the only API that renders a tab
            // in its own separated capsule, so we repurpose it purely for that
            // placement. It's an *action* item, not a destination: the
            // `tabSelection` setter below intercepts the tap, opens the New Event
            // sheet, and keeps the previously-selected tab — so it never
            // "selects" and its empty content never shows.
            Tab(AppTab.newEvent.titleKey, systemImage: AppTab.newEvent.systemImage, value: AppTab.newEvent, role: .search) {
                EmptyView()
            }
        }
        // Keep the Liquid Glass tab bar fully expanded at all times — it must
        // never minimize/collapse while a tab's content scrolls.
        .tabBarMinimizeBehavior(.never)
        .sheet(isPresented: $navigation.isPresentingNewEvent) {
            NavigationStack {
                NewEventScreen()
            }
        }
        // Global "Search" sheet — mirrors the New Event sheet. Driven by
        // `AppNavigation.isPresentingSearch`, which the Calendar nav-bar search
        // button flips. Hosted here (not in the Calendar tab) so search is
        // reachable from any tab; the Calendar team only sets the flag.
        .sheet(isPresented: $navigation.isPresentingSearch) {
            NavigationStack {
                SearchView()
            }
        }
        // "Connect Telegram?" confirmation, driven by a deep-linked code parked
        // on `AppNavigation`. Presented as a sheet (mirrors the New Event sheet)
        // only while authenticated — this view only mounts in that state — so a
        // code captured during sign-out surfaces here once sign-in completes.
        .sheet(isPresented: telegramLinkPresented) {
            NavigationStack {
                ConnectTelegramView(prefilledCode: navigation.pendingTelegramCode ?? "")
            }
        }
    }

    /// Bool binding mirroring `pendingTelegramCode != nil`; clearing the code on
    /// dismiss so the sheet doesn't immediately re-present.
    private var telegramLinkPresented: Binding<Bool> {
        Binding(
            get: { navigation.pendingTelegramCode != nil },
            set: { isPresented in
                if !isPresented {
                    navigation.pendingTelegramCode = nil
                }
            }
        )
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
        .environment(LanguageSettings())
        .environment(TelegramLinkStore())
}
