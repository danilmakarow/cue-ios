//
//  ScreenHost.swift
//  cueTests
//
//  Wraps a screen view with every environment object the app injects at the root
//  (mirrors cueApp), plus a seeded in-memory model container, so a full screen
//  renders in a snapshot test exactly as it does in the running app.
//

import Foundation
import SwiftUI
import SwiftData
@testable import cue

@MainActor
enum ScreenHost {
    /// Injects the full app environment around `content`. Pass a seeded container
    /// from `MockData.container()`; views read it via `@Query` / `@Environment(\.modelContext)`.
    ///
    /// By default the injected `AuthStore` is seeded as `.authenticated(user)` via
    /// the DEBUG-only `AuthStore.authenticated(_:)` factory — synchronous, no
    /// network/keychain/bootstrap — so signed-in screens (e.g. Account) render
    /// their real body instead of the signed-out fallback. The Auth / Onboarding
    /// suites — which snapshot the *signed-out* sign-in flow — pass
    /// `authenticated: false` to get a fresh unauthenticated store, and any suite
    /// needing a bespoke store can pass one explicitly via `authStore:`.
    static func wrap<Content: View>(
        _ content: Content,
        container: ModelContainer,
        user: UserDTO = MockData.user,
        authenticated: Bool = true,
        authStore: AuthStore? = nil,
        palette: AppPalette = .kraftInk
    ) -> some View {
        // Mirror the app launch: apply the serif navigation-title appearance so
        // snapshots render titles exactly as the running app does. Idempotent.
        CueAppearance.apply()
        let resolvedAuth = authStore
            ?? (authenticated ? AuthStore.authenticated(user) : AuthStore())
        return content
            .modelContainer(container)
            .environment(ThemeSettings())
            .environment(AppNavigation())
            .environment(resolvedAuth)
            .environment(NotificationStore())
            .environment(LanguageSettings())
            .environment(TelegramLinkStore())
            .environment(CalendarStore(user: user))
            .environment(\.theme, palette.colors)
            .tint(palette.colors.primary)
    }
}
