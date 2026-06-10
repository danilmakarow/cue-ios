//
//  SettingsView.swift
//  cue
//

import SwiftUI
import UIKit

/// Settings tab — profile summary, appearance, and sign-out.
struct SettingsView: View {
    @Environment(ThemeSettings.self) private var theme
    @Environment(LanguageSettings.self) private var language
    @Environment(AuthStore.self) private var authStore
    @Environment(TelegramLinkStore.self) private var telegramLink
    @Environment(NotificationStore.self) private var notifications

    var body: some View {
        @Bindable var theme = theme
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

            Section("settings.appearance.title") {
                Picker("settings.theme", selection: $theme.appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.titleKey).tag(mode)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("settings.appearance.palette")
                    PalettePicker(selection: $theme.palette)
                }
                .padding(.vertical, 4)
            }

            Section {
                Picker("settings.language", selection: $language.selected) {
                    ForEach(AppLanguage.allCases) { option in
                        option.label.tag(option)
                    }
                }
            } footer: {
                Text("settings.language.footer")
            }

            if case .authenticated = authStore.state {
                Section("settings.manage.title") {
                    NavigationLink {
                        GroupsScreen()
                    } label: {
                        Label("settings.groups", systemImage: "folder.fill")
                    }
                }
            }

            if case .authenticated = authStore.state {
                Section("settings.integrations.title") {
                    NavigationLink {
                        ConnectTelegramView()
                    } label: {
                        LabeledContent {
                            telegramStatusLabel
                        } label: {
                            Label("telegram.title", systemImage: "paperplane.fill")
                        }
                    }
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
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("settings.title")
        .task {
            telegramLink.bind(notifications: notifications)
            await telegramLink.refreshStatus()
        }
    }

    /// Trailing status indicator for the Telegram integration row: the linked
    /// `@handle` (or a generic "connected" label), "Not connected", or a spinner
    /// while the status is still resolving.
    @ViewBuilder
    private var telegramStatusLabel: some View {
        switch telegramLink.status {
        case .unknown, .loading:
            ProgressView()
        case .connected(let username, _):
            Text(connectedLabel(for: username))
                .foregroundStyle(.secondary)
        case .notConnected, .failed:
            Text("telegram.status.notConnected")
                .foregroundStyle(.secondary)
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
    let user: UserDTO

    var body: some View {
        HStack(spacing: 14) {
            avatar
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.headline)
                    .lineLimit(1)
                if let email = user.email, !email.isEmpty {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        let trimmed = user.displayName?.trimmingCharacters(in: .whitespaces)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return String(localized: "settings.profile.signedIn")
    }

    @ViewBuilder
    private var avatar: some View {
        if let image = decodedAvatar {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(.circle)
                .overlay {
                    Circle().strokeBorder(.tint, lineWidth: 1.5)
                }
                .accessibilityLabel("settings.profile.avatar.accessibility")
        } else {
            Circle()
                .fill(.secondary.opacity(0.15))
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .overlay {
                    Circle().strokeBorder(.tint, lineWidth: 1.5)
                }
                .accessibilityLabel("settings.profile.avatarDefault.accessibility")
        }
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

// MARK: - Palette picker

/// Two selectable color options, each shown as a labelled row with a small
/// swatch preview (canvas + primary + secondary). Replaces the old free
/// accent-color picker — the user now chooses one of two cohesive palettes
/// rather than an arbitrary hue.
private struct PalettePicker: View {
    @Binding var selection: AppPalette

    var body: some View {
        VStack(spacing: 10) {
            ForEach(AppPalette.allCases) { palette in
                row(for: palette)
            }
        }
    }

    private func row(for palette: AppPalette) -> some View {
        let isSelected = selection == palette
        return Button {
            selection = palette
        } label: {
            HStack(spacing: 14) {
                PaletteSwatch(palette: palette)

                VStack(alignment: .leading, spacing: 2) {
                    Text(palette.titleKey)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(palette.subtitleKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(palette.titleKey)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The three overlapping representative colors of a palette option.
private struct PaletteSwatch: View {
    let palette: AppPalette

    var body: some View {
        let swatch = palette.swatch
        return ZStack {
            circle(swatch.canvas).offset(x: -12)
            circle(swatch.secondary)
            circle(swatch.primary).offset(x: 12)
        }
        .frame(width: 56, height: 32)
    }

    private func circle(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 28, height: 28)
            .overlay(Circle().strokeBorder(.background, lineWidth: 2))
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
