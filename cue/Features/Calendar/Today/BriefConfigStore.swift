//
//  BriefConfigStore.swift
//  cue
//

import Foundation
import Observation

/// Shared source of truth for the **Brief configuration** editor: the user's
/// custom brief prompt (how the daily brief is written) plus the save / reset
/// mutations.
///
/// Modeled on `PersonaStore` — `@Observable @MainActor`, the shared `APIClient`,
/// and an idempotent `bind(notifications:)` that wires the global
/// `NotificationStore` post-init (the owning view can only read it from
/// `@Environment` in `body`, not in `init`).
///
/// The custom prompt is `GET`/`PATCH`/`DELETE /users/me/brief-settings`, exposed
/// as the typed `briefSettings()` / `updateBriefSettings(_:)` /
/// `resetBriefSettings()` helpers on `APIClient`. On save/reset the backend
/// invalidates today's cached brief so the new prompt takes effect immediately.
@Observable
@MainActor
final class BriefConfigStore {
    /// Load state of the custom brief prompt the editor renders around.
    enum LoadState: Equatable {
        /// Nothing fetched yet (initial state).
        case idle
        /// The cold read is in flight.
        case loading
        /// Loaded; the editor is interactive.
        case loaded
        /// The initial read failed; `message` is user-facing and the screen
        /// shows a full-page error with retry.
        case failed(message: String)
    }

    // MARK: Private

    private let api: APIClient

    /// Global notification queue for surfacing mutation outcomes as banners.
    /// Optional + wired post-init via `bind(notifications:)`.
    private var notifications: NotificationStore?

    // MARK: Public

    /// Cold-read state. Views branch on this for loading / error / content.
    private(set) var loadState: LoadState = .idle

    /// The user's custom brief prompt, or nil when the default voice is in effect.
    private(set) var customPrompt: String?

    /// True while a save / reset request is in flight, so the UI can show the
    /// "Saving…" CTA and block inputs. Distinct from `LoadState.loading`, which
    /// covers the initial *read*.
    private(set) var isMutating: Bool = false

    // MARK: Init

    init(api: APIClient = .shared, notifications: NotificationStore? = nil) {
        self.api = api
        self.notifications = notifications
    }

    /// Wires the global notification queue read from the owning view's
    /// environment. Idempotent — only binds the first time.
    func bind(notifications: NotificationStore) {
        guard self.notifications == nil else { return }
        self.notifications = notifications
    }

    #if DEBUG
    /// Debug/test-only: builds a store already in `.loaded` with a concrete custom
    /// prompt, skipping the async `load()` entirely. Snapshot tests inject this via
    /// `BriefConfigView(store:)` so the editor renders its settled content
    /// synchronously — no `URLProtocol` stub, no settle timing. Compiled out of
    /// release builds.
    static func previewLoaded(customPrompt: String?) -> BriefConfigStore {
        let store = BriefConfigStore()
        store.customPrompt = customPrompt
        store.loadState = .loaded
        return store
    }
    #endif

    // MARK: - Read

    /// Loads the custom brief prompt via `GET /users/me/brief-settings`. Shows a
    /// loading state only on a cold read; a refresh of already-loaded content
    /// keeps the prior value until the new one lands. On failure `loadState`
    /// becomes `.failed` (the screen renders a full-page error with retry) — no
    /// banner, to avoid double-surfacing a full-page error.
    func load() async {
        if loadState != .loaded {
            loadState = .loading
        }

        do {
            let settings = try await api.briefSettings()
            customPrompt = settings.customPrompt
            loadState = .loaded
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            loadState = .failed(message: message)
        }
    }

    // MARK: - Mutations

    /// Saves a custom brief prompt via `PATCH /users/me/brief-settings`. Updates
    /// `customPrompt` and posts a success banner on success; posts an error banner
    /// and leaves the prior prompt untouched on failure.
    ///
    /// - Parameter customPrompt: the custom brief instruction text to persist.
    /// - Returns: `true` when the save succeeded (so the caller can stamp the
    ///   seal / collapse the keyboard).
    @discardableResult
    func save(customPrompt: String) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        defer { isMutating = false }

        do {
            let dto = try await api.updateBriefSettings(
                UpdateBriefSettingsRequest(customPrompt: customPrompt)
            )
            self.customPrompt = dto.customPrompt
            notifications?.post(.success(
                String(localized: "brief.config.saved.title", defaultValue: "Brief configuration saved"),
                message: String(
                    localized: "brief.config.saved.message",
                    defaultValue: "Your next brief will be written this way."
                )
            ))
            return true
        } catch {
            notifications?.postError(
                error,
                title: String(
                    localized: "brief.config.error.save",
                    defaultValue: "Couldn't save configuration"
                )
            )
            return false
        }
    }

    /// Resets the brief configuration back to its default via
    /// `DELETE /users/me/brief-settings` (clears the custom prompt). Updates
    /// `customPrompt` to nil and posts a success banner on success; posts an error
    /// banner and leaves the prior prompt untouched on failure.
    ///
    /// - Returns: `true` when the reset succeeded (so the caller can re-seed its
    ///   editing buffer), else `false`.
    @discardableResult
    func reset() async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        defer { isMutating = false }

        do {
            try await api.resetBriefSettings()
            customPrompt = nil
            notifications?.post(.success(
                String(localized: "brief.config.reset.title", defaultValue: "Reset to default")
            ))
            return true
        } catch {
            notifications?.postError(
                error,
                title: String(
                    localized: "brief.config.error.reset",
                    defaultValue: "Couldn't reset configuration"
                )
            )
            return false
        }
    }
}
