//
//  AccountView.swift
//  cue
//

import PhotosUI
import SwiftUI
import UIKit

/// Account screen — profile summary, inline profile edit, sign-in method, and the
/// destructive account zone (sign out + delete).
///
/// Pushed from `SettingsView` (the profile row near the top of the Settings tab's
/// `NavigationStack`). Reads the signed-in user from `AuthStore` to seed an
/// `AccountStore`, which owns the editable working copy and the save/delete flows.
///
/// Layout (per the Account design spec):
/// - an avatar hero with a "Change photo" / "Add photo" picker, the display name,
///   and the sign-in email;
/// - a **Profile** card with an inline display-name field (dirty border + "Edited"
///   pill) and a read-only time-zone row;
/// - a **Sign-in method** card ("Signed in with Apple", member-since, and a
///   "Manage Apple ID" deep link disabled while offline);
/// - a destructive zone with a **Sign Out** confirmation and a **Delete account**
///   confirmation (brick / irreversible);
/// - a pinned "Save changes" CTA that appears only while the profile is dirty.
struct AccountView: View {
    @Environment(\.theme) private var theme
    @Environment(AuthStore.self) private var authStore
    @Environment(NotificationStore.self) private var notifications

    var body: some View {
        // Identity is read once from AuthStore; the editable copy lives in the
        // store seeded below. When the user isn't authenticated (shouldn't reach
        // here from Settings), fall back to a neutral empty state.
        if case .authenticated(let user) = authStore.state {
            AccountContent(user: user)
        } else {
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
}

// MARK: - Authenticated content

/// The signed-in body. Split from `AccountView` so the `AccountStore` can be
/// seeded from a concrete `UserDTO` in `init` (a `@State` store needs its seed at
/// construction, which a conditional `if case` in `body` can't provide cleanly).
private struct AccountContent: View {
    @Environment(\.theme) private var theme
    @Environment(AuthStore.self) private var authStore
    @Environment(NotificationStore.self) private var notifications
    @Environment(\.openURL) private var openURL

    @State private var store: AccountStore
    @State private var user: UserDTO
    @State private var photoItem: PhotosPickerItem?
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @FocusState private var nameFocused: Bool

    init(user: UserDTO) {
        // The store needs its seed at construction. The environment's live
        // `NotificationStore` isn't readable here, so we seed with a throwaway and
        // swap in the real one via `store.rebind(notifications:)` in `.task`.
        _store = State(initialValue: AccountStore(user: user, notifications: NotificationStore()))
        _user = State(initialValue: user)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                avatarHero
                profileSection
                signInMethodSection
                destructiveZone
                supportFooter
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl)
            // The pinned save CTA is hosted in a `safeAreaInset`, which already
            // reserves its own height; this is just the resting bottom breathing room.
            .padding(.bottom, Spacing.huge)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("account.title")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if store.isDirty {
                saveCTA
            }
        }
        .loadingOverlay(store.isSaving, label: String(localized: "account.saving"))
        .overlay {
            // The GREEN commit signature — fires once per successful save so the
            // commit reads as a deliberate "roots take hold" moment, not just a
            // spinner. Never on mount (gated on a non-zero commit count).
            if store.saveCommitCount > 0 {
                RootsCommitView(tone: .save, trigger: store.saveCommitCount)
                    .frame(width: 96, height: 96)
                    .allowsHitTesting(false)
            }
        }
        .disabled(store.isSaving || store.isDeleting)
        .onChange(of: photoItem) { _, newValue in
            Task { await store.applyPickedPhoto(newValue) }
        }
        .confirmActionSheet(
            isPresented: $showSignOutConfirm,
            title: String(localized: "account.signOut.confirm.title"),
            message: String(localized: "account.signOut.confirm.message"),
            primary: ConfirmAction(String(localized: "settings.signOut")) {
                authStore.signOut()
            }
        )
        .confirmActionSheet(
            isPresented: $showDeleteConfirm,
            title: String(localized: "account.delete.confirm.title"),
            message: String(localized: "account.delete.confirm.message"),
            primary: ConfirmAction(String(localized: "account.delete.confirm.action")) {
                Task { await deleteAccount() }
            }
        )
        .task {
            // Rebind the store onto the environment's live NotificationStore so its
            // save/delete banners surface through the app-wide host (the init seed
            // used a throwaway instance, since environment isn't readable in init).
            store.rebind(notifications: notifications)
        }
    }

    // MARK: - Avatar hero

    @ViewBuilder
    private var avatarHero: some View {
        VStack(spacing: Spacing.md) {
            ZStack(alignment: .bottomTrailing) {
                CueAvatar(image: store.avatarImage, name: store.heroName, size: 96)
                    .accessibilityLabel(Text("account.avatar.accessibility"))

                // Camera badge overlapping the ring's lower-right.
                Circle()
                    .fill(theme.surface)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().strokeBorder(theme.border, lineWidth: 1))
                    .overlay {
                        Image(systemName: "camera")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.primary)
                    }
                    .cueDepth(.letterpress, radius: 16)
                    .offset(x: 2, y: 2)
            }

            VStack(spacing: Spacing.xs) {
                Text(store.heroName)
                    .cueText(.displayM)
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let email = store.email, !email.isEmpty {
                    Text(email)
                        .cueText(.callout)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }

            // Read the main-actor `avatarImage` HERE (in the MainActor view body)
            // rather than inside the PhotosPicker's `Sendable` label closure, which
            // can't capture a main-actor-isolated property.
            let photoActionTitle = store.avatarImage == nil
                ? String(localized: "account.photo.add")
                : String(localized: "account.photo.change")
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(photoActionTitle, systemImage: "camera")
                    .cueText(.bodyEmphasis)
                    .foregroundStyle(theme.accentText)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Profile section

    @ViewBuilder
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("account.section.profile")

            CueCard(padding: 0) {
                VStack(spacing: 0) {
                    displayNameRow
                    Rectangle()
                        .fill(theme.separator)
                        .frame(height: 1)
                        .padding(.horizontal, Spacing.lg)
                    timeZoneRow
                }
            }
        }
    }

    @ViewBuilder
    private var displayNameRow: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Text("account.displayName.label")
                    .cueText(.label)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.textSecondary)

                if store.nameChanged {
                    HStack(spacing: Spacing.xxs) {
                        Circle()
                            .fill(theme.accentText)
                            .frame(width: 6, height: 6)
                        Text("account.edited")
                            .cueText(.label)
                            .textCase(.uppercase)
                            .foregroundStyle(theme.accentText)
                    }
                }
            }

            HStack(spacing: Spacing.sm) {
                TextField(
                    String(localized: "account.displayName.placeholder"),
                    text: Binding(get: { store.displayName }, set: { store.displayName = $0 })
                )
                .focused($nameFocused)
                .cueText(.body)
                .foregroundStyle(theme.textPrimary)
                .tint(theme.primary)
                .textContentType(.name)
                .accessibilityIdentifier("account.displayName.field")

                if !store.displayName.isEmpty {
                    Button {
                        store.clearDisplayName()
                        nameFocused = true
                    } label: {
                        // A 20pt sunken disc with a thin stroked X (design), not the
                        // heavier filled `xmark.circle.fill` glyph.
                        Circle()
                            .fill(theme.surfaceSunken)
                            .frame(width: 20, height: 20)
                            .overlay {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(theme.textSecondary)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("common.clear"))
                }
            }
            // Design field padding is 10×12; no 10pt Spacing token exists, so the
            // vertical inset is an explicit literal between sm (8) and md (12).
            .padding(.vertical, 10)
            .padding(.horizontal, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .fill(theme.surfaceSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .strokeBorder(store.nameChanged ? theme.primary : theme.border, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.16), value: store.nameChanged)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
    }

    @ViewBuilder
    private var timeZoneRow: some View {
        // A tappable disclosure (design renders a chevron): the device time zone is
        // managed in the OS Settings app, so the row deep-links there — mirroring the
        // "Manage Apple ID" pattern rather than inventing an in-app zone editor.
        Button {
            openSystemSettings()
        } label: {
            SettingsRow(
                String(localized: "account.timeZone.label"),
                subValue: timeZoneDescription,
                trailing: .navigation,
                showsSeparator: false
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sign-in method section

    @ViewBuilder
    private var signInMethodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("account.section.signInMethod")

            CueCard {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    HStack(alignment: .top, spacing: Spacing.md) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 22))
                            .foregroundStyle(theme.primary)
                            .frame(width: 34, height: 34)

                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("account.signInMethod.apple")
                                .cueText(.bodyEmphasis)
                                .foregroundStyle(theme.textPrimary)

                            if let email = store.email, !email.isEmpty {
                                Text(email)
                                    .cueText(.callout)
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(1)
                            }

                            Text(memberSinceDescription)
                                .cueText(.code)
                                .foregroundStyle(theme.textSecondary)
                                .padding(.top, Spacing.xxs)
                        }

                        Spacer(minLength: 0)
                    }

                    VStack(spacing: Spacing.sm) {
                        Button {
                            openSystemSettings()
                        } label: {
                            Text("account.manageAppleID")
                        }
                        .buttonStyle(.cue(.secondary))
                        .disabled(store.isOffline)
                        .accessibilityLabel(Text("account.manageAppleID.accessibility"))

                        if store.isOffline {
                            Text("account.manageAppleID.offline")
                                .cueText(.caption)
                                .foregroundStyle(theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Destructive zone

    @ViewBuilder
    private var destructiveZone: some View {
        VStack(spacing: Spacing.lg) {
            Button {
                showSignOutConfirm = true
            } label: {
                Text("settings.signOut")
            }
            .buttonStyle(.cue(.destructive))

            Button {
                showDeleteConfirm = true
            } label: {
                Text("account.delete")
                    .cueText(.bodyEmphasis)
                    .foregroundStyle(theme.accentText)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, Spacing.xxl)
    }

    // MARK: - Support footer

    @ViewBuilder
    private var supportFooter: some View {
        Button {
            UIPasteboard.general.string = store.userId
            notifications.post(.info(
                String(localized: "account.userId.copied"),
                message: nil
            ))
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(userIdDescription)
                    .cueText(.code)
                    .foregroundStyle(theme.textSecondary)
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("account.userId.copy.accessibility"))
        .padding(.top, Spacing.sm)
    }

    // MARK: - Pinned save CTA

    @ViewBuilder
    private var saveCTA: some View {
        Button {
            nameFocused = false
            Task { await store.save() }
        } label: {
            HStack(spacing: Spacing.sm) {
                WaxSeal(isStamped: false, size: 26)
                Text("account.save")
            }
        }
        .buttonStyle(.cue(.decisive))
        .disabled(!store.canSave)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .background(.bar)
    }

    // MARK: - Helpers

    /// An uppercase eyebrow above a grouped card section.
    private func sectionLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .cueText(.label)
            .textCase(.uppercase)
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, Spacing.xs)
    }

    /// "Member since · Mar 2026" — the account creation month/year in the receipt
    /// voice.
    private var memberSinceDescription: String {
        let month = user.createdAt.formatted(.dateTime.month(.abbreviated).year())
        return String(format: String(localized: "account.memberSince"), month)
    }

    /// The IANA zone identifier plus its current GMT offset, e.g. "Europe/Berlin · GMT+2".
    private var timeZoneDescription: String {
        let zone = TimeZone.current
        let offsetSeconds = zone.secondsFromGMT()
        let hours = offsetSeconds / 3600
        let sign = hours >= 0 ? "+" : "-"
        return "\(zone.identifier) · GMT\(sign)\(abs(hours))"
    }

    /// "User ID  usr_a1b2…f93" — the id truncated to a glanceable head + tail.
    private var userIdDescription: String {
        let id = store.userId
        let display: String
        if id.count > 12 {
            display = "\(id.prefix(8))…\(id.suffix(3))"
        } else {
            display = id
        }
        return String(format: String(localized: "account.userId"), display)
    }

    // MARK: - Actions

    /// Deletes the account, then signs out (returning the app to the sign-in
    /// screen) when the backend confirms the purge.
    private func deleteAccount() async {
        let didDelete = await store.deleteAccount()
        if didDelete {
            authStore.signOut()
        }
    }

    /// Deep-links to the OS Settings app — the closest reliable system destination
    /// for both managing the Apple ID and changing the device time zone (iOS exposes
    /// no direct pane URL for either, so this opens the app's Settings root).
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Preview

#Preview("Authenticated") {
    let sampleUser = UserDTO(
        id: "usr_a1b2c3d4e5f93",
        appleUserId: "apple_001",
        email: "jane.appleseed@icloud.com",
        displayName: "Jane Appleseed",
        avatarBase64: nil,
        timezone: "Europe/Berlin",
        createdAt: .now,
        updatedAt: .now
    )
    return NavigationStack {
        AccountContent(user: sampleUser)
    }
    .environment(\.theme, AppPalette.kraftInk.colors)
    .environment(AuthStore())
    .environment(NotificationStore())
}
