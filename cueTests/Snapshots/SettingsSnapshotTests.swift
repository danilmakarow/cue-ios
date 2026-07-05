//
//  SettingsSnapshotTests.swift
//  cueTests
//
//  Storybook-style snapshot tests for `SettingsView` — the Settings tab rendered
//  as a scroll of floating `CueCard` sections (CUE — Clean). The screen gates most
//  of its content on `AuthStore.state == .authenticated`, so the "full" state needs
//  an authenticated store. `ScreenHost.wrap` now seeds an `.authenticated(MockData.user)`
//  store by default (via the DEBUG-only `AuthStore.authenticated(_:)` factory —
//  synchronous, no network / keychain / bootstrap), so the "full" test needs no
//  bespoke store and the "signedOut" test opts out with `authenticated: false`.
//
//  States per the design reference (Settings.dc.html):
//    • full          — signed in: profile + Appearance + Language + Manage +
//                      Integrations + Account + Sign out (the complete list)
//    • signedOut     — unauthenticated: only Appearance + Language render
//

import SwiftUI
import Testing
@testable import cue

@MainActor
struct SettingsSnapshotTests {
    /// Full signed-in settings list: profile row, Appearance, Language, Manage
    /// (Groups), Integrations (Telegram/Notifications/Assistant), Account, and the
    /// destructive Sign-out card. Telegram status defaults to `.unknown`, so its
    /// row shows a spinner (the seeded, network-independent state).
    @Test func full() {
        let container = MockData.container()

        let screen = NavigationStack {
            SettingsView()
        }

        // `wrap` seeds an `.authenticated(MockData.user)` store by default, which
        // ungates the full signed-in section list.
        #expect(
            SnapshotHarness.record(
                ScreenHost.wrap(screen, container: container),
                named: "settings-full"
            ) != nil
        )
    }

    /// Signed-out state: with an unauthenticated `AuthStore` (`authenticated:
    /// false`), the profile + Manage/Integrations/Account/Sign-out sections are
    /// gated off and only the always-visible Appearance and Language sections render.
    @Test func signedOut() {
        let container = MockData.container()

        let screen = NavigationStack {
            SettingsView()
        }

        #expect(
            SnapshotHarness.record(
                ScreenHost.wrap(screen, container: container, authenticated: false),
                named: "settings-signedOut"
            ) != nil
        )
    }
}
