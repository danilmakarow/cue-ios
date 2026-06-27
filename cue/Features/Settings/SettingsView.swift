//
//  SettingsView.swift
//  cue
//

import SwiftUI
import UIKit

/// Settings tab — profile summary, appearance, and sign-out.
struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(ThemeSettings.self) private var themeSettings
    @Environment(LanguageSettings.self) private var language
    @Environment(AuthStore.self) private var authStore
    @Environment(TelegramLinkStore.self) private var telegramLink
    @Environment(NotificationStore.self) private var notifications

    var body: some View {
        @Bindable var themeSettings = themeSettings
        @Bindable var language = language

        Form {
            #if DEBUG
            NotificationDebugSection()
            #endif

            if case .authenticated(let user) = authStore.state {
                Section {
                    UserProfileRow(user: user)
                }
            }

            Section {
                Picker(selection: $themeSettings.appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.titleKey).tag(mode)
                    }
                } label: {
                    Text("settings.theme")
                        .cueText(.body)
                        .foregroundStyle(theme.textPrimary)
                }

                // Kraft & Ink is the sole palette; the multi-option picker is
                // gone. A static read-only row keeps the section meaningful.
                LabeledContent {
                    Text(AppPalette.kraftInk.titleKey)
                        .cueText(.body)
                        .foregroundStyle(theme.textSecondary)
                } label: {
                    Text("settings.appearance.palette")
                        .cueText(.body)
                        .foregroundStyle(theme.textPrimary)
                }
            } header: {
                sectionHeader("settings.appearance.title")
            }

            Section {
                Picker(selection: $language.selected) {
                    ForEach(AppLanguage.allCases) { option in
                        option.label.tag(option)
                    }
                } label: {
                    Text("settings.language")
                        .cueText(.body)
                        .foregroundStyle(theme.textPrimary)
                }
            } footer: {
                Text("settings.language.footer")
                    .cueText(.caption)
                    .foregroundStyle(theme.textSecondary)
            }

            if case .authenticated = authStore.state {
                Section {
                    NavigationLink {
                        GroupsScreen()
                    } label: {
                        Label("settings.groups", systemImage: "folder.fill")
                            .cueText(.body)
                            .foregroundStyle(theme.textPrimary)
                    }
                } header: {
                    sectionHeader("settings.manage.title")
                }
            }

            if case .authenticated = authStore.state {
                Section {
                    NavigationLink {
                        ConnectTelegramView()
                    } label: {
                        LabeledContent {
                            telegramStatusLabel
                        } label: {
                            Label("telegram.title", systemImage: "paperplane.fill")
                                .cueText(.body)
                                .foregroundStyle(theme.textPrimary)
                        }
                    }
                } header: {
                    sectionHeader("settings.integrations.title")
                }
            }

            if case .authenticated = authStore.state {
                Section {
                    Button(role: .destructive) {
                        authStore.signOut()
                        telegramLink.clear()
                    } label: {
                        HStack {
                            Spacer()
                            Text("settings.signOut")
                                .cueText(.bodyEmphasis)
                                .foregroundStyle(theme.danger)
                            Spacer()
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("settings.title")
        .task {
            telegramLink.bind(notifications: notifications)
            await telegramLink.refreshStatus()
        }
    }

    /// A Fraunces section header rendered in the serif label voice, with system
    /// uppercasing suppressed so it reads as a typeset heading.
    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .cueText(.label)
            .textCase(nil)
            .foregroundStyle(theme.textSecondary)
    }

    /// Trailing status indicator for the Telegram integration row: the linked
    /// `@handle` (or a generic "connected" label), "Not connected", or a spinner
    /// while the status is still resolving.
    @ViewBuilder
    private var telegramStatusLabel: some View {
        switch telegramLink.status {
        case .unknown, .loading:
            ProgressView()
                .tint(theme.primary)
        case .connected(let username, _):
            Text(connectedLabel(for: username))
                .cueText(.code)
                .foregroundStyle(theme.textSecondary)
        case .notConnected, .failed:
            Text("telegram.status.notConnected")
                .cueText(.callout)
                .foregroundStyle(theme.textSecondary)
        }
    }

    /// Formats the connected username as `@handle`, or a generic label when the
    /// backend hasn't supplied one.
    private func connectedLabel(for username: String?) -> String {
        guard let username, !username.isEmpty else {
            return String(localized: "telegram.status.connected")
        }
        return username.hasPrefix("@") ? username : "@\(username)"
    }
}

// MARK: - User profile row

/// Avatar + name + email row rendered at the top of Settings.
private struct UserProfileRow: View {
    @Environment(\.theme) private var theme

    let user: UserDTO

    var body: some View {
        HStack(spacing: Spacing.lg) {
            CueAvatar(image: decodedAvatar)
                .accessibilityLabel(avatarAccessibilityLabel)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(displayName)
                    .cueText(.titleM)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                if let email = user.email, !email.isEmpty {
                    Text(email)
                        .cueText(.callout)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.xs)
    }

    private var displayName: String {
        let trimmed = user.displayName?.trimmingCharacters(in: .whitespaces)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return String(localized: "settings.profile.signedIn")
    }

    /// Accessibility label matching whichever avatar variant `CueAvatar` renders.
    private var avatarAccessibilityLabel: LocalizedStringKey {
        decodedAvatar == nil
            ? "settings.profile.avatarDefault.accessibility"
            : "settings.profile.avatar.accessibility"
    }

    private var decodedAvatar: UIImage? {
        guard let avatarBase64 = user.avatarBase64, !avatarBase64.isEmpty,
              let data = Data(base64Encoded: avatarBase64),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
}

// MARK: - Notification debug section (DEBUG only)

#if DEBUG
/// Developer-only controls for firing each notification variant, so the global
/// notification system can be exercised on-device without triggering a real API
/// failure. Compiled out of release builds.
private struct NotificationDebugSection: View {
    @Environment(NotificationStore.self) private var notifications

    var body: some View {
        Section("Developer · Notifications") {
            Button("Post info (auto-dismiss)") {
                notifications.post(.info("Synced", message: "Your calendar is up to date."))
            }
            Button("Post success (auto-dismiss)") {
                notifications.post(.success("Saved", message: "Your changes were saved."))
            }
            Button("Post warning (permanent)") {
                notifications.post(.warning(
                    "Working offline",
                    message: "Changes will sync when you reconnect."
                ))
            }
            Button("Post error (expandable)") {
                notifications.post(.from(
                    .http(
                        status: 422,
                        body: #"{"statusCode":422,"message":["title should not be empty"],"error":"Unprocessable Entity"}"#
                    ),
                    title: "Couldn't save event"
                ))
            }
            Button("Clear all", role: .destructive) {
                notifications.dismissAll()
            }
        }
    }
}
#endif

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(ThemeSettings())
    .environment(LanguageSettings())
    .environment(AppNavigation())
    .environment(AuthStore())
    .environment(NotificationStore())
    .environment(TelegramLinkStore())
}
