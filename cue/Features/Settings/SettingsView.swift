//
//  SettingsView.swift
//  cue
//

import SwiftUI
import UIKit

/// Settings tab — profile summary, appearance, language, manage, integrations,
/// and account. Rendered as a scroll of floating `CueCard` sections (CUE — Clean),
/// each fronted by a section eyebrow, rather than a native `Form`.
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

        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xxl) {
                if case .authenticated(let user) = authStore.state {
                    UserProfileRow(user: user)
                }

                appearanceSection(themeSettings: $themeSettings.appearance)
                languageSection(language: $language.selected)

                if case .authenticated = authStore.state {
                    manageSection
                    integrationsSection
                    accountSection
                    signOutSection
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxxl)
        }
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("settings.title")
        .task {
            telegramLink.bind(notifications: notifications)
            await telegramLink.refreshStatus()
        }
    }

    // MARK: - Sections

    /// Appearance — a single Theme row whose value is a tappable fill-pill chip
    /// opening a `Menu` of `AppearanceMode`s.
    private func appearanceSection(themeSettings: Binding<AppearanceMode>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionEyebrow("settings.appearance.title", uppercase: true)
            CueCard(padding: 0, radius: Radius.xlarge) {
                PillRow(label: "settings.theme") {
                    Menu {
                        Picker(selection: themeSettings) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(mode.titleKey).tag(mode)
                            }
                        } label: { EmptyView() }
                    } label: {
                        FillPill { Text(themeSettings.wrappedValue.titleKey) }
                    }
                }
            }
        }
    }

    /// Language — a single Language row (fill-pill chip + restart footnote).
    private func languageSection(language: Binding<AppLanguage>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionEyebrow("settings.language", uppercase: true)
            CueCard(padding: 0, radius: Radius.xlarge) {
                PillRow(label: "settings.language") {
                    Menu {
                        Picker(selection: language) {
                            ForEach(AppLanguage.allCases) { option in
                                option.label.tag(option)
                            }
                        } label: { EmptyView() }
                    } label: {
                        FillPill { language.wrappedValue.label }
                    }
                }
            }
            Text("settings.language.footer")
                .cueText(.caption)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Spacing.xs)
        }
    }

    /// Manage — Groups only (AI Assistant + Notifications moved to Integrations).
    private var manageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionEyebrow("settings.manage.title", uppercase: true)
            CueCard(padding: 0, radius: Radius.xlarge) {
                NavigationLink {
                    GroupsScreen()
                } label: {
                    SettingsTileRow(
                        icon: "folder.fill",
                        tile: .accent,
                        title: Text("settings.groups"),
                        showsSeparator: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Integrations — Telegram (live status), Notifications & Report, AI Assistant.
    private var integrationsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionEyebrow("settings.integrations.title", uppercase: true)
            CueCard(padding: 0, radius: Radius.xlarge) {
                NavigationLink {
                    ConnectTelegramView()
                } label: {
                    SettingsTileRow(
                        icon: "paperplane.fill",
                        tile: .neutral,
                        title: Text("telegram.title")
                    ) {
                        telegramStatusLabel
                    }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    NotificationsReportView()
                } label: {
                    SettingsTileRow(
                        icon: "bell.badge",
                        tile: .neutral,
                        title: Text("settings.notificationsReport")
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    PersonaEditorView()
                } label: {
                    SettingsTileRow(
                        icon: "sparkles",
                        tile: .accentInk,
                        title: Text("settings.assistant"),
                        showsSeparator: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Account — a dedicated, sentence-case section (the profile row above is now
    /// display-only).
    private var accountSection: some View {
        // New "Account" key carries an inline default so the catalog auto-extracts
        // it; the shared xcstrings file is never hand-edited.
        let accountTitle = String(localized: "settings.account.title", defaultValue: "Account")
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(accountTitle)
                .font(.system(size: 13, weight: .medium))
                .tracking(0.3)
                .textCase(nil)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Spacing.xs)
            CueCard(padding: 0, radius: Radius.xlarge) {
                NavigationLink {
                    AccountView()
                } label: {
                    SettingsTileRow(
                        icon: "person.crop.circle",
                        tile: .success,
                        title: Text(verbatim: accountTitle),
                        showsSeparator: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var signOutSection: some View {
        CueCard(padding: 0, radius: Radius.xlarge) {
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
                .padding(.vertical, Spacing.md + 1)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    /// A section eyebrow rendered in the system-sans label voice. `uppercase`
    /// selects the heading's case: uppercased for Appearance/Language/Manage/
    /// Integrations, sentence-case for Account.
    private func sectionEyebrow(_ key: LocalizedStringKey, uppercase: Bool) -> some View {
        Text(key)
            .cueText(.label)
            .textCase(uppercase ? .uppercase : nil)
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, Spacing.xs)
    }

    /// Trailing status indicator for the Telegram integration row: a `@handle`
    /// with an olive connected dot, a "Not connected" label, or a spinner while
    /// the status is still resolving.
    @ViewBuilder
    private var telegramStatusLabel: some View {
        switch telegramLink.status {
        case .unknown, .loading:
            ProgressView()
                .tint(theme.primary)
        case .connected(let username, _):
            HStack(spacing: Spacing.xs + 2) {
                Circle()
                    .fill(theme.success)
                    .frame(width: 7, height: 7)
                Text(connectedLabel(for: username))
                    .cueText(.code)
                    .foregroundStyle(theme.textPrimary)
            }
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

// MARK: - Fill-pill value chip

/// A gray fill-pill carrying a settings value (Theme/Language) with a trailing
/// up/down chevron — the tappable affordance that opens a `Menu`.
private struct FillPill<Label: View>: View {
    @Environment(\.theme) private var theme

    @ViewBuilder let label: () -> Label

    var body: some View {
        HStack(spacing: Spacing.xs + 2) {
            label()
                .cueText(.callout)
                .foregroundStyle(theme.textPrimary)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.vertical, Spacing.xs + 2)
        .padding(.horizontal, Spacing.md)
        .background(theme.surfaceSunken, in: Capsule())
    }
}

/// A row whose leading column is a `body` label and whose trailing column is a
/// fill-pill value (used by Appearance/Language). One row per card, no separator.
private struct PillRow<Trailing: View>: View {
    @Environment(\.theme) private var theme

    let label: LocalizedStringKey
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(label)
                .cueText(.body)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Settings tile row

/// The role color of a `SettingsTileRow`'s 28×28 leading glyph tile.
private enum SettingsTileStyle {
    /// Clay wash tile, clay glyph — the decisive/primary destination (Groups).
    case accent
    /// Gray fill tile, muted glyph — neutral integrations (Telegram, Notifications).
    case neutral
    /// Gray fill tile, deepened-clay glyph (AI Assistant).
    case accentInk
    /// Gray fill tile, olive glyph (Account).
    case success
}

/// A navigation list row with a 28×28 radius-8 role-colored icon tile, a body
/// label, an optional trailing status slot, and a tertiary chevron. Wrapped in a
/// `NavigationLink`/`Button` at the call site (presentation-only). A 1px
/// separator sits under the row unless suppressed (final row in a card).
private struct SettingsTileRow<Trailing: View>: View {
    @Environment(\.theme) private var theme

    private let icon: String
    private let tile: SettingsTileStyle
    private let title: Text
    private let showsSeparator: Bool
    private let trailing: () -> Trailing

    init(
        icon: String,
        tile: SettingsTileStyle,
        title: Text,
        showsSeparator: Bool = true,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.icon = icon
        self.tile = tile
        self.title = title
        self.showsSeparator = showsSeparator
        self.trailing = trailing
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                iconTile
                title
                    .cueText(.body)
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                trailing()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm + 1)

            if showsSeparator {
                Rectangle()
                    .fill(theme.separator)
                    .frame(height: 1)
                    .padding(.leading, Spacing.lg + 28 + Spacing.md)
            }
        }
        .contentShape(Rectangle())
    }

    private var iconTile: some View {
        RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
            .fill(tileBackground)
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(tileForeground)
            }
    }

    private var tileBackground: Color {
        switch tile {
        case .accent: return theme.accentSoft
        case .neutral, .accentInk, .success: return theme.surfaceSunken
        }
    }

    private var tileForeground: Color {
        switch tile {
        case .accent: return theme.primary
        case .neutral: return theme.textSecondary
        case .accentInk: return theme.accentText
        case .success: return theme.success
        }
    }
}

extension SettingsTileRow where Trailing == EmptyView {
    /// A tile row with no trailing status — just the chevron.
    init(
        icon: String,
        tile: SettingsTileStyle,
        title: Text,
        showsSeparator: Bool = true
    ) {
        self.init(
            icon: icon,
            tile: tile,
            title: title,
            showsSeparator: showsSeparator,
            trailing: { EmptyView() }
        )
    }
}

// MARK: - User profile row

/// Avatar + name + email card rendered at the top of Settings — display-only
/// (Account now has its own dedicated section/link below).
private struct UserProfileRow: View {
    @Environment(\.theme) private var theme

    let user: UserDTO

    var body: some View {
        CueCard(padding: 0, radius: Radius.xlarge) {
            HStack(spacing: Spacing.lg) {
                CueAvatar(image: decodedAvatar, name: displayName)
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
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
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
