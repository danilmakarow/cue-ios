//
//  AccountView.swift
//  cue
//

import SwiftUI

/// Account screen — profile summary, edit profile, sign out, and delete account.
///
/// Pushed from `SettingsView` (the profile row near the top of the Settings
/// tab's `NavigationStack`). Reads the signed-in user and stores from the
/// environment, so it takes no arguments; the navigating call site stays a plain
/// value-less push.
///
// TODO(4c): Account workstream builds this out — profile summary card, an
// "Edit profile" flow, a destructive "Sign out", and a confirmation-gated
// "Delete account". Consume `AuthStore` for the user + sign-out, and the
// design-system components (`CueCard`, `SettingsRow`, `ConfirmActionSheet`).
struct AccountView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        EmptyStateView(
            title: String(localized: "account.title"),
            message: String(localized: "account.placeholder.message"),
            systemImage: "person.crop.circle"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("account.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AccountView()
    }
    .environment(\.theme, AppPalette.kraftInk.colors)
    .environment(AuthStore())
}
