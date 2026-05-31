//
//  AppNotification+APIError.swift
//  cue
//

import Foundation

/// Bridge from the network layer's `APIError` to a generic, design-system
/// `AppNotification`. Lives in `Networking/` (not `DesignSystem/`) on purpose:
/// the dependency points one way — networking knows about the design system,
/// never the reverse. The store and banner stay ignorant of `APIError`.
extension AppNotification {
    /// Builds an expandable error notification from an `APIError`.
    ///
    /// - Collapsed: the friendly `userMessage` under a caller-supplied title.
    /// - Expanded: the full `diagnosticDetail` (HTTP status, raw body,
    ///   underlying description).
    ///
    /// Permanent by default so the user must acknowledge the failure.
    ///
    /// - Parameters:
    ///   - error: the failure to surface.
    ///   - title: short headline describing what failed, e.g.
    ///     "Couldn't load tasks". Defaults to a generic line.
    ///   - dismissal: override the default permanent behavior if desired.
    static func from(
        _ error: APIError,
        title: String = String(localized: "error.somethingWrong"),
        dismissal: NotificationDismissal = .permanent
    ) -> AppNotification {
        AppNotification(
            severity: .error,
            title: title,
            message: error.userMessage,
            detail: error.diagnosticDetail,
            dismissal: dismissal
        )
    }
}

extension NotificationStore {
    /// Convenience: post an error notification for a failed request in one call.
    /// Non-`APIError` failures still surface — they're wrapped with their
    /// `localizedDescription` as the detail.
    ///
    /// - Parameters:
    ///   - error: the thrown error (ideally an `APIError`).
    ///   - title: headline describing the failed operation.
    /// - Returns: the posted notification's id.
    @discardableResult
    func postError(_ error: Error, title: String = String(localized: "error.somethingWrong")) -> UUID {
        if let apiError = error as? APIError {
            return post(.from(apiError, title: title))
        }
        return post(
            AppNotification(
                severity: .error,
                title: title,
                message: error.localizedDescription,
                detail: String(reflecting: error),
                dismissal: .permanent
            )
        )
    }
}
