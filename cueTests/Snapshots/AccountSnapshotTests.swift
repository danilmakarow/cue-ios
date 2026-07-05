//
//  AccountSnapshotTests.swift
//  cueTests
//
//  Design-fidelity snapshots for the Account screen (AccountView).
//
//  AccountView only renders its real profile body when the injected `AuthStore`
//  is in `.authenticated`; otherwise it falls back to a neutral empty state.
//  `ScreenHost.wrap` now seeds an `.authenticated` store by default (via the
//  DEBUG-only `AuthStore.authenticated(_:)` factory — synchronous, no network /
//  keychain / bootstrap), so each test simply passes the `UserDTO` it wants the
//  seeded store to carry — avatar present vs. absent — and the authenticated
//  `AccountContent` renders for both states.
//

import Foundation
import SwiftUI
import Testing
@testable import cue

@MainActor
struct AccountSnapshotTests {
    // MARK: - Fixtures

    /// A profile WITH an avatar (a tiny solid-color PNG, base64-encoded) so the
    /// hero ring shows an image and the picker reads "Change photo".
    private func userWithAvatar() -> UserDTO {
        UserDTO(
            id: "usr_a1b2c3d4e5f93",
            appleUserId: "apple_001",
            email: "jane.appleseed@icloud.com",
            displayName: "Jane Appleseed",
            avatarBase64: Self.solidAvatarBase64,
            timezone: "Europe/Berlin",
            createdAt: Date(timeIntervalSince1970: 1_741_000_000), // ~Mar 2025/2026 era
            updatedAt: Date(timeIntervalSince1970: 1_741_000_000)
        )
    }

    /// A profile with NO avatar → the hero falls back to initials and the picker
    /// reads "Add photo" (design "no_avatar" state).
    private func userWithoutAvatar() -> UserDTO {
        UserDTO(
            id: "usr_a1b2c3d4e5f93",
            appleUserId: "apple_001",
            email: "jane.appleseed@icloud.com",
            displayName: "Jane Appleseed",
            avatarBase64: nil,
            timezone: "Europe/Berlin",
            createdAt: Date(timeIntervalSince1970: 1_741_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_741_000_000)
        )
    }

    /// A 2×2 deep-olive PNG, base64-encoded — just enough for the avatar ring to
    /// render a real image instead of initials.
    private static let solidAvatarBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGNkYPj/n4GBgQEAEAYBAYrL2lcAAAAASUVORK5CYII="

    // MARK: - Tests

    /// Default authenticated profile: avatar, name, email, profile card, sign-in
    /// method card, destructive zone, support footer. No dirty CTA.
    @Test
    func defaultProfile() {
        let container = MockData.container()

        let screen = NavigationStack {
            AccountView()
        }

        // Default `wrap` seeds an `.authenticated` store from `user:`, so the
        // authenticated `AccountContent` renders with the avatar present.
        let view = ScreenHost.wrap(screen, container: container, user: userWithAvatar())

        #expect(SnapshotHarness.record(view, named: "account-default") != nil)
    }

    /// No-avatar variant — hero shows initials and the picker label reads
    /// "Add photo" (design "no_avatar" state).
    @Test
    func noAvatarProfile() {
        let container = MockData.container()

        let screen = NavigationStack {
            AccountView()
        }

        // No-avatar user → the authenticated hero falls back to initials and the
        // picker label reads "Add photo".
        let view = ScreenHost.wrap(screen, container: container, user: userWithoutAvatar())

        #expect(SnapshotHarness.record(view, named: "account-no-avatar") != nil)
    }
}
