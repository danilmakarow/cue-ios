//
//  AppNotification.swift
//  cue
//

import SwiftUI

// MARK: - NotificationSeverity

/// Visual + semantic severity of a notification. Drives the icon, accent color,
/// and the accessibility prefix announced by VoiceOver.
///
/// Kept free of any networking knowledge — the integration layer (e.g. the API
/// error bridge) maps its own concepts onto these cases so the design system
/// stays a dumb, reusable renderer.
enum NotificationSeverity: Sendable, Hashable, CaseIterable {
    case info
    case success
    case warning
    case error

    /// SF Symbol shown in the banner's leading icon slot.
    var systemImage: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    // Severity color is intentionally NOT defined here. This type is `Sendable`
    // and may be built off the main actor, so it can't read the active palette
    // from `@Environment(\.theme)`. `NotificationBanner` maps severity onto the
    // theme's functional roles (info/success/warning/danger) at render time.

    /// Spoken prefix so VoiceOver users hear the severity before the message.
    var accessibilityPrefix: String {
        switch self {
        case .info: return String(localized: "notification.severity.info")
        case .success: return String(localized: "notification.severity.success")
        case .warning: return String(localized: "notification.severity.warning")
        case .error: return String(localized: "notification.severity.error")
        }
    }
}

// MARK: - NotificationDismissal

/// When (if ever) a notification removes itself without user interaction.
enum NotificationDismissal: Sendable, Hashable {
    /// Disappears automatically after `seconds`. The store schedules a
    /// cancellable timer; dismissing early (swipe / tap close) cancels it.
    case auto(seconds: Double)

    /// Stays until the user explicitly dismisses it. Used for errors the user
    /// must acknowledge or act on.
    case permanent

    /// Default auto-dismiss interval (4s) — long enough to read a short line,
    /// short enough not to linger.
    static let auto = NotificationDismissal.auto(seconds: 4)
}

// MARK: - AppNotification

/// A single, self-contained notification payload. This is the *only* type the
/// notification store and host render — it carries no networking, no closures
/// to feature code beyond an optional user action, and is `Sendable` so it can
/// be constructed off the main actor and handed to the store.
///
/// Construct directly for ad-hoc messages, or via the convenience factories
/// (`.info`, `.success`, `.warning`, `.error`) for the common cases. The API
/// error bridge (`AppNotification+APIError`) builds an expandable `.error`
/// notification from a structured `APIError`.
struct AppNotification: Identifiable, Sendable {
    /// Stable identity used by SwiftUI's diffing and by the store's dismissal
    /// lookup. Defaulted so callers rarely supply it.
    let id: UUID

    /// Severity — drives styling and the VoiceOver prefix.
    let severity: NotificationSeverity

    /// One-line headline always visible in the collapsed state.
    let title: String

    /// Short supporting line shown under the title in the collapsed state.
    /// Keep it to a sentence; put long content in `detail`.
    let message: String?

    /// Full detail revealed when an expandable notification is tapped open.
    /// `nil` means the notification is *not* expandable. For API errors this
    /// holds the raw status + response body + underlying description.
    let detail: String?

    /// Auto-dismiss vs. permanent behavior.
    let dismissal: NotificationDismissal

    /// Whether tapping the banner toggles the `detail` disclosure. Only
    /// meaningful when `detail != nil`.
    let isExpandable: Bool

    /// Memberwise initializer with sensible defaults so most call sites pass
    /// only `severity` + `title` (+ `message`).
    /// - Parameters:
    ///   - severity: visual/semantic level.
    ///   - title: always-visible headline.
    ///   - message: optional short supporting line.
    ///   - detail: optional full text; supplying it makes expansion possible.
    ///   - dismissal: auto (default) or permanent.
    ///   - isExpandable: opt-in tap-to-expand; auto-enabled when `detail` is set
    ///     unless explicitly overridden.
    init(
        id: UUID = UUID(),
        severity: NotificationSeverity,
        title: String,
        message: String? = nil,
        detail: String? = nil,
        dismissal: NotificationDismissal = .auto,
        isExpandable: Bool? = nil
    ) {
        self.id = id
        self.severity = severity
        self.title = title
        self.message = message
        self.detail = detail
        self.dismissal = dismissal
        // Default: expandable iff there's detail to reveal. Callers can force
        // it off (a long detail they never want expanded) via `isExpandable:`.
        self.isExpandable = isExpandable ?? (detail != nil)
    }
}

// MARK: - Convenience factories

extension AppNotification {
    /// Auto-dismissing informational notification.
    static func info(
        _ title: String,
        message: String? = nil,
        dismissal: NotificationDismissal = .auto
    ) -> AppNotification {
        AppNotification(severity: .info, title: title, message: message, dismissal: dismissal)
    }

    /// Auto-dismissing success notification.
    static func success(
        _ title: String,
        message: String? = nil,
        dismissal: NotificationDismissal = .auto
    ) -> AppNotification {
        AppNotification(severity: .success, title: title, message: message, dismissal: dismissal)
    }

    /// Warning notification — defaults to permanent since warnings usually want
    /// acknowledgement, but the caller can pass `.auto`.
    static func warning(
        _ title: String,
        message: String? = nil,
        detail: String? = nil,
        dismissal: NotificationDismissal = .permanent
    ) -> AppNotification {
        AppNotification(
            severity: .warning,
            title: title,
            message: message,
            detail: detail,
            dismissal: dismissal
        )
    }

    /// Error notification — defaults to permanent so the user must dismiss it,
    /// and expandable when `detail` is supplied.
    static func error(
        _ title: String,
        message: String? = nil,
        detail: String? = nil,
        dismissal: NotificationDismissal = .permanent
    ) -> AppNotification {
        AppNotification(
            severity: .error,
            title: title,
            message: message,
            detail: detail,
            dismissal: dismissal
        )
    }
}
