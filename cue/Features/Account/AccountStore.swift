//
//  AccountStore.swift
//  cue
//

import PhotosUI
import SwiftUI

/// Drives the Account screen's editable profile, save, and delete-account flows.
///
/// Seeded from the signed-in `UserDTO` (read from `AuthStore` at the call site,
/// since `AuthStore` is owned by Auth and exposes the user read-only). Holds the
/// *working copy* of the editable fields (display name + avatar) so the screen can
/// show a dirty/edited state and a pinned "Save changes" affordance, then
/// round-trips the change through `APIClient.updateUserSettings`. Account deletion
/// goes through `APIClient.deleteAccount` and, on success, hands off to
/// `AuthStore.signOut` at the call site.
///
/// Follows the same `@Observable` + `@MainActor` shape as `AuthStore` /
/// `NotificationStore`, so it injects as plain view state without `ObservableObject`.
@Observable
@MainActor
final class AccountStore {
    // MARK: Private

    private let api: APIClient

    /// The app-wide banner queue. Seeded with a throwaway at `init` (the SwiftUI
    /// environment isn't readable when a `@State` store is constructed) and
    /// replaced with the live environment instance via `rebind(notifications:)`
    /// in the view's `.task`.
    private var notifications: NotificationStore

    /// The baseline values last persisted (or seeded from sign-in). Dirtiness is
    /// measured against these, and a successful save advances them.
    private var savedDisplayName: String
    private var savedAvatarData: Data?

    // MARK: Seed identity (read-only)

    /// The user's email — shown under the name and on the sign-in card. Immutable.
    let email: String?

    /// When the account was created — rendered as the "Member since" receipt line.
    let createdAt: Date

    /// The opaque user id — surfaced (truncated) in the support footer.
    let userId: String

    // MARK: Editable working copy

    /// The working display-name value the field binds to.
    var displayName: String

    /// The working avatar, decoded for display. `nil` falls through to initials.
    private(set) var avatarImage: UIImage?

    /// Raw bytes behind `avatarImage`, kept so the base64 payload is built once.
    private(set) var avatarData: Data?

    // MARK: Transient flow state

    /// True while a save round-trip is in flight (drives the blocking overlay).
    private(set) var isSaving = false

    /// True while the delete-account request is in flight.
    private(set) var isDeleting = false

    /// True when the last save failed because the device was offline — the screen
    /// keeps the edits and disables the connection-bound "Manage Apple ID" row.
    private(set) var isOffline = false

    /// Monotonic counter bumped on each successful save. Drives the screen's
    /// GREEN `RootsCommitView` (the design system's commit signature) so a save
    /// reads as a deliberate commit rather than a generic spinner.
    private(set) var saveCommitCount = 0

    // MARK: Init

    /// Seeds the working copy from the signed-in user.
    /// - Parameters:
    ///   - user: the authenticated profile to edit.
    ///   - api: the HTTP client (default `.shared`).
    ///   - notifications: the app-wide banner queue for save/error feedback.
    init(
        user: UserDTO,
        api: APIClient = .shared,
        notifications: NotificationStore
    ) {
        self.api = api
        self.notifications = notifications
        self.email = user.email
        self.createdAt = user.createdAt
        self.userId = user.id

        let seededName = user.displayName?.trimmingCharacters(in: .whitespaces) ?? ""
        self.displayName = seededName
        self.savedDisplayName = seededName

        let seededAvatar = Self.decodeAvatar(user.avatarBase64)
        self.avatarData = seededAvatar?.data
        self.avatarImage = seededAvatar?.image
        self.savedAvatarData = seededAvatar?.data
    }

    /// Swaps in the environment's live notification store so save/delete banners
    /// surface through the app-wide host. Called once from the view's `.task`,
    /// since the environment can't be read at `init`.
    /// - Parameter notifications: the environment-injected banner queue.
    func rebind(notifications: NotificationStore) {
        self.notifications = notifications
    }

    // MARK: Derived state

    /// The trimmed working name, or `nil` when blank.
    var trimmedDisplayName: String? {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The name shown in the hero + sign-in card — the working name, or a generic
    /// "Signed in" label when blank.
    var heroName: String {
        trimmedDisplayName ?? String(localized: "settings.profile.signedIn")
    }

    /// Whether the working copy differs from what's persisted — gates the dirty
    /// border, the "Edited" pill, and the pinned save CTA.
    var isDirty: Bool {
        nameChanged || avatarChanged
    }

    /// Whether the display name has been edited away from the persisted value.
    var nameChanged: Bool {
        savedDisplayName.trimmingCharacters(in: .whitespaces)
            != displayName.trimmingCharacters(in: .whitespaces)
    }

    /// Whether the avatar has been swapped or cleared since the last save.
    var avatarChanged: Bool {
        avatarData != savedAvatarData
    }

    /// Whether a save can proceed — dirty, not blank, and not already saving.
    var canSave: Bool {
        isDirty && trimmedDisplayName != nil && !isSaving
    }

    // MARK: Editing

    /// Clears the working display name back to empty (the field's clear button).
    func clearDisplayName() {
        displayName = ""
    }

    /// Applies a freshly-picked photo to the working copy. A `nil` payload (decode
    /// failure) is ignored so the previous avatar survives a bad pick.
    /// - Parameter item: the `PhotosPicker` selection, or `nil` when cleared.
    func applyPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else {
            notifications.post(.warning(String(localized: "account.photo.error")))
            return
        }
        avatarData = data
        avatarImage = image
    }

    // MARK: Saving

    /// Persists the dirty fields via `PATCH /users/me/settings`. On success posts a
    /// confirmation banner and advances the baseline; on a transport failure keeps
    /// the edits and flags the offline state; on any other API error surfaces it.
    func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }

        let request = UpdateUserSettingsRequest(
            displayName: nameChanged ? trimmedDisplayName : nil,
            avatarBase64: avatarChanged ? (avatarData?.base64EncodedString() ?? "") : nil
        )

        do {
            _ = try await api.updateUserSettings(request)
            savedDisplayName = trimmedDisplayName ?? ""
            savedAvatarData = avatarData
            isOffline = false
            saveCommitCount += 1
            notifications.post(.success(
                String(localized: "account.saved.title"),
                message: String(localized: "account.saved.message")
            ))
        } catch let error as APIError {
            if case .transport = error {
                // Edits are kept locally; we surface an offline-aware notice and
                // disable connection-bound rows rather than discarding the change.
                isOffline = true
                notifications.post(.warning(
                    String(localized: "account.offline.title"),
                    message: String(localized: "account.offline.message")
                ))
            } else {
                notifications.post(.from(error, title: String(localized: "account.save.error")))
            }
        } catch {
            notifications.post(.from(.transport(error.localizedDescription), title: String(localized: "account.save.error")))
        }
    }

    // MARK: Deletion

    /// Permanently deletes the account via `DELETE /users/me`. Returns `true` on
    /// success so the caller can drive `AuthStore.signOut`; on failure posts an
    /// error banner and returns `false`.
    func deleteAccount() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await api.deleteAccount()
            return true
        } catch let error as APIError {
            notifications.post(.from(error, title: String(localized: "account.delete.error")))
            return false
        } catch {
            notifications.post(.from(.transport(error.localizedDescription), title: String(localized: "account.delete.error")))
            return false
        }
    }

    // MARK: Helpers

    /// Decodes a base64 avatar payload into a `UIImage` plus its raw bytes, or
    /// `nil` when the payload is missing or undecodable.
    private static func decodeAvatar(_ base64: String?) -> (image: UIImage, data: Data)? {
        guard let base64, !base64.isEmpty,
              let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else {
            return nil
        }
        return (image, data)
    }
}
