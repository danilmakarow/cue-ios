//
//  TelegramLinkStore.swift
//  cue
//

import Foundation
import Observation

/// Shared source of truth for the Telegram-link integration: the live link
/// status plus the redeem / unlink mutations.
///
/// Created once at the app root (not per-tab) because the linking deep link can
/// arrive before Settings ever mounts — the store must already exist to hold and
/// act on the result. Modeled on `CalendarStore`: `@Observable @MainActor`, the
/// shared `APIClient`, and an idempotent `bind(notifications:)` that wires the
/// global `NotificationStore` post-init (the owning view can only read it from
/// `@Environment` in `body`, not in `init`).
///
/// Reads (`refreshStatus`) update `status`; writes (`link`/`unlink`) flip
/// `isMutating` and surface success/failure as banners via `NotificationStore`.
@Observable
@MainActor
final class TelegramLinkStore {
    /// High-level state of the Telegram link, driving every screen that shows it.
    enum Status: Equatable {
        /// Nothing fetched yet (initial state, and after `clear()`).
        case unknown
        /// A status fetch is in flight with nothing prior to show.
        case loading
        /// Confirmed there is no linked chat.
        case notConnected
        /// A chat is linked. `username` / `linkedAt` are display-only and may be
        /// `nil` while the backend doesn't yet thread them through.
        case connected(username: String?, linkedAt: String?)
        /// The status fetch itself failed; `message` is user-facing.
        case failed(message: String)
    }

    // MARK: Private

    private let api: APIClient

    /// Global notification queue for surfacing request outcomes as banners.
    /// Optional + wired post-init via `bind(notifications:)` — the owning view
    /// can only read it from `@Environment` in `body`, not in `init`.
    private var notifications: NotificationStore?

    // MARK: Public

    /// Current link status. Views branch on this.
    private(set) var status: Status = .unknown

    /// True while a `link`/`unlink` request is in flight, so the UI can disable
    /// inputs and show a blocking overlay. Distinct from `Status.loading`, which
    /// covers the initial *read*.
    private(set) var isMutating: Bool = false

    /// True after a `link` attempt was rejected with the typed
    /// `APIError.linkCodeInvalid` (a permanently bad / expired / used nonce).
    /// Drives a *persistent* brass "bad code" notice on the form — distinct from
    /// the transient error banner — that keeps the user in place to fetch a fresh
    /// code. Cleared the moment the user edits the code or a new attempt starts.
    private(set) var lastCodeRejected: Bool = false

    /// Dismisses the persistent bad-code notice. Called when the user edits the
    /// code field, so the brass warning never lingers over a fresh value.
    func clearCodeRejection() {
        lastCodeRejected = false
    }

    // MARK: Init

    init(api: APIClient = .shared, notifications: NotificationStore? = nil) {
        self.api = api
        self.notifications = notifications
    }

    /// Wires the global notification queue read from the owning view's
    /// environment. Idempotent — only binds the first time, so re-renders of the
    /// host view don't replace an already-attached store.
    func bind(notifications: NotificationStore) {
        guard self.notifications == nil else { return }
        self.notifications = notifications
    }

    // MARK: - Read

    /// Fetches the current link state via `GET /assistant/link`. Shows a loading
    /// state only on a cold read; a refresh of already-known state keeps the
    /// prior value until the new one lands. On failure the status itself becomes
    /// `.failed` (the screen renders an error state with retry) — no banner, to
    /// avoid double-surfacing a full-screen error.
    func refreshStatus() async {
        if case .connected = status {} else if case .notConnected = status {} else {
            status = .loading
        }

        do {
            let dto: TelegramLinkStatusDTO = try await api.get("/assistant/link")
            status = Self.status(from: dto)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            status = .failed(message: message)
        }
    }

    // MARK: - Mutations

    /// Redeems a linking nonce via `POST /assistant/link`. Updates `status` and
    /// posts a success banner on success; posts an error banner and leaves the
    /// prior status untouched on failure.
    ///
    /// - Parameter code: the single-use nonce from the deep link / pasted code.
    /// - Returns: `true` when the link succeeded (so the caller can dismiss).
    @discardableResult
    func link(code: String) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        lastCodeRejected = false
        defer { isMutating = false }

        do {
            let dto: TelegramLinkStatusDTO = try await api.post(
                "/assistant/link",
                body: LinkTelegramRequest(code: code)
            )
            status = Self.status(from: dto)
            notifications?.post(.success(
                String(localized: "telegram.connected.title"),
                message: String(localized: "telegram.connected.message")
            ))
            return true
        } catch {
            // Branch the typed INVALID_LINK_CODE (permanently bad nonce) from a
            // transient failure: the former is a "this code is no longer valid"
            // state the user fixes by getting a fresh code, not by retrying.
            if let apiError = error as? APIError, apiError.isInvalidLinkCode {
                // Latch the persistent in-form brass notice. No transient banner:
                // the inline notice is the dedicated affordance for this case and
                // a banner would double-surface it.
                lastCodeRejected = true
            } else {
                notifications?.postError(error, title: String(localized: "telegram.error.linkFailed"))
            }
            return false
        }
    }

    /// Revokes the link via `DELETE /assistant/link`. Flips to `.notConnected`
    /// and posts a success banner on success; posts an error banner and leaves
    /// the prior status untouched on failure.
    func unlink() async {
        guard !isMutating else { return }
        isMutating = true
        defer { isMutating = false }

        do {
            let _: TelegramLinkStatusDTO = try await api.delete("/assistant/link")
            status = .notConnected
            notifications?.post(.success(
                String(localized: "telegram.disconnected.title")
            ))
        } catch {
            notifications?.postError(error, title: String(localized: "telegram.error.unlinkFailed"))
        }
    }

    /// Resets to `.unknown` on sign-out so a new session can't see stale link
    /// state. Mirrors `AuthStore.signOut` clearing the session.
    func clear() {
        status = .unknown
        isMutating = false
    }

    // MARK: - Helpers

    /// Maps a wire DTO onto the view-facing `Status`.
    private static func status(from dto: TelegramLinkStatusDTO) -> Status {
        guard dto.linked else {
            return .notConnected
        }
        return .connected(username: dto.telegramUsername, linkedAt: dto.linkedAt)
    }
}
