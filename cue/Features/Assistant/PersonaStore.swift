//
//  PersonaStore.swift
//  cue
//

import Foundation
import Observation

/// Shared source of truth for the AI-assistant persona editor: the active
/// persona (custom text or seeded preset), the curated preset list, and the
/// save / reset mutations.
///
/// Modeled on `TelegramLinkStore` — `@Observable @MainActor`, the shared
/// `APIClient`, and an idempotent `bind(notifications:)` that wires the global
/// `NotificationStore` post-init (the owning view can only read it from
/// `@Environment` in `body`, not in `init`).
///
/// The active persona is `GET`/`PATCH`/`DELETE /users/me/persona-settings`; the
/// presets are `GET /users/me/persona-presets`. The frozen `APIClient` exposes
/// the typed `listPersonaPresets()` / `resetPersona()` helpers plus the generic
/// verbs (`get`/`patch`) this store calls directly for the settings document —
/// the same pattern `TelegramLinkStore` uses for `/assistant/link`.
@Observable
@MainActor
final class PersonaStore {
    /// Load state of the active persona + presets the editor renders around.
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

    /// The persona the assistant currently adopts (custom text or a preset).
    private(set) var active: PersonaSettingsDTO?

    /// The curated presets offered as pickable starting points.
    private(set) var presets: [PersonaPresetDTO] = []

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

    // MARK: Derived

    /// Whether the active persona is a read-only preset (vs. an editable custom
    /// persona). Drives the locked / editable treatment of the prompt field.
    var isPreset: Bool {
        active?.source == .preset
    }

    /// The receipt-voice label for the active persona's provenance —
    /// `PRESET` / `CUSTOM` — shown as the monospaced tag beside the field.
    var sourceTag: String {
        isPreset
            ? String(localized: "assistant.persona.tag.preset", defaultValue: "PRESET")
            : String(localized: "assistant.persona.tag.custom", defaultValue: "CUSTOM")
    }

    // MARK: - Read

    /// Loads the active persona and the preset list together via
    /// `GET /users/me/persona-settings` + `GET /users/me/persona-presets`. Shows
    /// a loading state only on a cold read; a refresh of already-loaded content
    /// keeps the prior values until the new ones land. On failure `loadState`
    /// becomes `.failed` (the screen renders a full-page error with retry) — no
    /// banner, to avoid double-surfacing a full-page error.
    func load() async {
        if loadState != .loaded {
            loadState = .loading
        }

        do {
            async let settings: PersonaSettingsDTO = api.get("/users/me/persona-settings")
            async let presetList: [PersonaPresetDTO] = api.listPersonaPresets()
            let (loadedSettings, loadedPresets) = try await (settings, presetList)
            active = loadedSettings
            presets = loadedPresets
            loadState = .loaded
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            loadState = .failed(message: message)
        }
    }

    // MARK: - Mutations

    /// Saves a custom persona via `PATCH /users/me/persona-settings`. Updates
    /// `active` and posts a success banner on success; posts an error banner and
    /// leaves the prior persona untouched on failure.
    ///
    /// - Parameter promptText: the custom persona instruction text to persist.
    /// - Returns: `true` when the save succeeded (so the caller can stamp the
    ///   seal / collapse the keyboard).
    @discardableResult
    func save(promptText: String) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        defer { isMutating = false }

        do {
            let dto: PersonaSettingsDTO = try await api.patch(
                "/users/me/persona-settings",
                body: UpdatePersonaSettingsRequest(promptText: promptText)
            )
            active = dto
            notifications?.post(.success(
                String(localized: "assistant.persona.saved.title", defaultValue: "Persona saved"),
                message: String(
                    localized: "assistant.persona.saved.message",
                    defaultValue: "Your assistant will use it on Telegram."
                )
            ))
            return true
        } catch {
            notifications?.postError(
                error,
                title: String(
                    localized: "assistant.persona.error.save",
                    defaultValue: "Couldn't save persona"
                )
            )
            return false
        }
    }

    /// Resets the custom persona back to the seeded preset via
    /// `DELETE /users/me/persona-settings`. Updates `active` to the now-active
    /// preset and posts a success banner on success; posts an error banner and
    /// leaves the prior persona untouched on failure.
    ///
    /// - Returns: the reset preset's text on success (so the caller can re-seed
    ///   its editing buffer), else `nil`.
    @discardableResult
    func reset() async -> String? {
        guard !isMutating else { return nil }
        isMutating = true
        defer { isMutating = false }

        do {
            let dto = try await api.resetPersona()
            active = dto
            notifications?.post(.success(
                String(localized: "assistant.persona.reset.title", defaultValue: "Reset to preset")
            ))
            return dto.promptText
        } catch {
            notifications?.postError(
                error,
                title: String(
                    localized: "assistant.persona.error.reset",
                    defaultValue: "Couldn't reset persona"
                )
            )
            return nil
        }
    }
}
