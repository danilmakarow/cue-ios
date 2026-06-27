//
//  ReportSettingsStore.swift
//  cue
//

import Foundation
import Observation
import os.lock
import UserNotifications
import UIKit

/// Shared source of truth for the Notifications & Report screen: the daily-report
/// settings (`GET`/`PATCH /users/me/report-settings`) and the two cross-device
/// brief/recap opt-ins that live on the account (`GET`/`PATCH /users/me/settings`).
///
/// Modeled on `TelegramLinkStore`: `@Observable @MainActor`, the shared
/// `APIClient`, and an idempotent `bind(notifications:)` that wires the global
/// `NotificationStore` post-init (the owning view can only read it from
/// `@Environment` in `body`, not in `init`).
///
/// The screen reads `phase` for the cold load and reads the individual fields to
/// render each control. Every mutation is optimistic: the control flips
/// immediately, the matching `PATCH` fires, and on failure the field reverts to
/// the last server-confirmed value and an inline "Couldn't save" caption shows.
/// A successful save flashes a transient "Saved" stamp.
@Observable
@MainActor
final class ReportSettingsStore {
    /// Cold-load lifecycle for the whole screen.
    enum Phase: Equatable {
        /// Nothing fetched yet (initial state).
        case idle
        /// The first read is in flight with nothing prior to show.
        case loading
        /// Both settings payloads loaded; the form is interactive.
        case loaded
        /// The cold read failed; `message` is user-facing and the screen shows a
        /// retry.
        case failed(message: String)
    }

    // MARK: Private

    private let api: APIClient

    /// Global notification queue for surfacing mutation failures as banners.
    /// Optional + wired post-init via `bind(notifications:)`.
    private var notifications: NotificationStore?

    /// Last server-confirmed report settings, used to revert an optimistic edit
    /// that failed to persist.
    private var confirmedReport: ReportSettingsDTO?

    /// Last server-confirmed account settings (only the brief/recap opt-ins are
    /// edited here), used to revert a failed optimistic toggle.
    private var confirmedUser: UserSettingsDTO?

    /// Hides the transient "Saved" stamp after a beat. Cancelled and re-armed on
    /// each successful save so rapid edits don't leave it stuck on.
    private var savedFlashTask: Task<Void, Never>?

    // MARK: Public — lifecycle

    /// Cold-load phase. The screen renders loading / error / form from this.
    private(set) var phase: Phase = .idle

    // MARK: Public — report settings

    /// Whether the daily report is on. Drives the master toggle and the reveal of
    /// the channel + time card.
    var enabled: Bool = false

    /// Local wall-clock send time. Bridged to `HH:mm` for the wire on save.
    var reportTime: Date = ReportSettingsStore.defaultTime

    /// Preferred delivery channel. NOTE: push delivery is deferred server-side —
    /// a `.push` value persists but Telegram delivers today regardless.
    var channel: NotificationChannel = .telegram

    /// IANA zone the send time resolves against (display-only footnote). Sourced
    /// from the account settings; falls back to the device zone until loaded.
    private(set) var timezoneIdentifier: String = TimeZone.current.identifier

    // MARK: Public — account opt-ins

    /// Cross-device morning-brief push opt-in (`UserSettings.morningBriefEnabled`).
    var morningBriefEnabled: Bool = false

    /// Cross-device evening-recap push opt-in (`UserSettings.eveningRecapEnabled`).
    var eveningRecapEnabled: Bool = false

    // MARK: Public — transient UI flags

    /// True for a beat after any successful save, so the screen can flash a
    /// green "Saved" stamp.
    private(set) var showSaved: Bool = false

    /// Set after a save fails (and the field reverts) so the screen can show the
    /// inline "Couldn't save — reverted" caption. Cleared on the next attempt.
    private(set) var showSaveError: Bool = false

    /// True while any optimistic `PATCH` is in flight, so the screen can show the
    /// small inline spinner in place of the toggle.
    private(set) var isSaving: Bool = false

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

    // MARK: - Read

    /// Fetches both settings payloads via `GET /users/me/report-settings` and
    /// `GET /users/me/settings`. Shows the cold-load spinner only when nothing is
    /// loaded yet; a refresh of already-loaded state keeps the form visible. On
    /// failure the phase becomes `.failed` so the screen renders a retry.
    func load() async {
        if case .loaded = phase {} else {
            phase = .loading
        }

        do {
            async let report = api.reportSettings()
            async let user = api.userSettings()
            let (reportDTO, userDTO) = try await (report, user)
            apply(report: reportDTO)
            apply(user: userDTO)
            phase = .loaded
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            phase = .failed(message: message)
        }
    }

    // MARK: - Mutations

    /// Toggles the daily report on/off. Enabling first requests notification
    /// permission and registers the APNs device (push delivery is deferred
    /// server-side, but the token is persisted now so it's ready when push lands),
    /// then persists `enabled` — optimistically, reverting on failure.
    func setEnabled(_ newValue: Bool) async {
        guard newValue != enabled else { return }
        enabled = newValue

        if newValue {
            await requestPushAuthorizationAndRegister()
        }

        await persistReport(
            UpdateReportSettingsRequest(enabled: newValue),
            revert: { [weak self] in self?.enabled = !newValue }
        )
    }

    /// Persists a new delivery channel optimistically, reverting on failure.
    func setChannel(_ newValue: NotificationChannel) async {
        let previous = channel
        guard newValue != previous else { return }
        channel = newValue
        await persistReport(
            UpdateReportSettingsRequest(channel: newValue),
            revert: { [weak self] in self?.channel = previous }
        )
    }

    /// Persists the send time optimistically (formatted to `HH:mm`), reverting on
    /// failure. Called when the inline time picker commits a new value.
    func commitTime() async {
        let previous = confirmedReport?.reportTimeLocal
        let wire = Self.wireTime(from: reportTime)
        guard wire != previous else { return }
        await persistReport(
            UpdateReportSettingsRequest(reportTimeLocal: wire),
            revert: { [weak self] in
                guard let self, let previous else { return }
                self.reportTime = Self.time(from: previous) ?? self.reportTime
            }
        )
    }

    /// Persists the morning-brief opt-in optimistically, reverting on failure.
    func setMorningBrief(_ newValue: Bool) async {
        let previous = morningBriefEnabled
        guard newValue != previous else { return }
        morningBriefEnabled = newValue
        await persistUser(
            UpdateUserSettingsRequest(morningBriefEnabled: newValue),
            revert: { [weak self] in self?.morningBriefEnabled = previous }
        )
    }

    /// Persists the evening-recap opt-in optimistically, reverting on failure.
    func setEveningRecap(_ newValue: Bool) async {
        let previous = eveningRecapEnabled
        guard newValue != previous else { return }
        eveningRecapEnabled = newValue
        await persistUser(
            UpdateUserSettingsRequest(eveningRecapEnabled: newValue),
            revert: { [weak self] in self?.eveningRecapEnabled = previous }
        )
    }

    // MARK: - Persistence helpers

    /// Runs a report-settings `PATCH`, syncing the confirmed snapshot on success
    /// and invoking `revert` + flashing the error caption on failure.
    private func persistReport(
        _ request: UpdateReportSettingsRequest,
        revert: @escaping () -> Void
    ) async {
        beginSave()
        do {
            let dto = try await api.updateReportSettings(request)
            apply(report: dto)
            flashSaved()
        } catch {
            revert()
            flashError(error)
        }
        isSaving = false
    }

    /// Runs an account-settings `PATCH`, syncing the confirmed snapshot on success
    /// and invoking `revert` + flashing the error caption on failure.
    private func persistUser(
        _ request: UpdateUserSettingsRequest,
        revert: @escaping () -> Void
    ) async {
        beginSave()
        do {
            let dto = try await api.updateUserSettings(request)
            apply(user: dto)
            flashSaved()
        } catch {
            revert()
            flashError(error)
        }
        isSaving = false
    }

    /// Common pre-save bookkeeping: clear a lingering error and mark in flight.
    private func beginSave() {
        showSaveError = false
        isSaving = true
    }

    // MARK: - Push authorization

    /// Requests notification authorization and, when granted, asks UIKit to
    /// register for remote notifications and upserts the APNs token via
    /// `POST /users/me/devices`. Best-effort: a denied prompt or a token that
    /// isn't available yet (no AppDelegate callback wired) is swallowed silently —
    /// push delivery is deferred, so the report still persists and delivers via
    /// Telegram. A genuine registration *request* failure surfaces as a banner.
    private func requestPushAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        guard granted else { return }

        UIApplication.shared.registerForRemoteNotifications()

        guard let token = PushTokenBridge.shared.currentToken() else { return }
        do {
            _ = try await api.registerDevice(token: token, platform: .ios)
        } catch {
            notifications?.postError(error, title: String(localized: "reports.error.deviceRegister"))
        }
    }

    // MARK: - Transient flags

    /// Flashes the green "Saved" stamp for ~1.6s, re-arming the timer on rapid
    /// successive saves so it never sticks.
    private func flashSaved() {
        showSaveError = false
        showSaved = true
        savedFlashTask?.cancel()
        savedFlashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.showSaved = false
        }
    }

    /// Shows the inline "Couldn't save" caption and posts a banner with the
    /// failure detail.
    private func flashError(_ error: Error) {
        showSaved = false
        showSaveError = true
        notifications?.postError(error, title: String(localized: "reports.error.saveFailed"))
    }

    // MARK: - Mapping

    /// Folds a report-settings payload into the local fields + confirmed snapshot.
    private func apply(report dto: ReportSettingsDTO) {
        confirmedReport = dto
        enabled = dto.enabled
        channel = dto.channel
        if let parsed = Self.time(from: dto.reportTimeLocal) {
            reportTime = parsed
        }
    }

    /// Folds an account-settings payload into the local opt-ins + timezone.
    private func apply(user dto: UserSettingsDTO) {
        confirmedUser = dto
        morningBriefEnabled = dto.morningBriefEnabled
        eveningRecapEnabled = dto.eveningRecapEnabled
        timezoneIdentifier = dto.timezone
    }

    // MARK: - Time bridging

    /// The seeded send time (`08:00`) used before the server value lands.
    private static var defaultTime: Date {
        time(from: "08:00") ?? Date()
    }

    /// A fixed-format `HH:mm` parser/formatter in the POSIX locale so the wire
    /// value never drifts with the user's 12/24-hour preference.
    private static let wireFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// Parses a `HH:mm` wire string into a `Date` on a reference day (only the
    /// time components matter to the picker).
    private static func time(from wire: String) -> Date? {
        wireFormatter.date(from: wire)
    }

    /// Formats a picked `Date` back to the `HH:mm` wire string.
    private static func wireTime(from date: Date) -> String {
        wireFormatter.string(from: date)
    }
}

/// Process-wide bridge that hands the latest APNs device token to the
/// `@MainActor` stores that register it. Mirrors `AuthTokenBridge`: the App's
/// `didRegisterForRemoteNotificationsWithDeviceToken` callback (when wired) sets
/// the token here, and `ReportSettingsStore` reads it on enable.
///
/// Until that callback exists the token is `nil` and device registration is
/// skipped — harmless while push delivery is deferred server-side.
final class PushTokenBridge: Sendable {
    nonisolated static let shared = PushTokenBridge()

    private let token = OSAllocatedUnfairLock<String?>(initialState: nil)

    nonisolated init() {}

    /// The latest APNs token as a hex string, or nil if none has arrived yet.
    nonisolated func currentToken() -> String? {
        token.withLock { $0 }
    }

    /// Installs a freshly-issued APNs token (or clears it with `nil`).
    nonisolated func setToken(_ newToken: String?) {
        token.withLock { stored in stored = newToken }
    }
}
