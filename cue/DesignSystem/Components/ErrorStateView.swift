//
//  ErrorStateView.swift
//  cue
//

import SwiftUI

/// Reusable full-page error state, built on `ContentUnavailableView` with a
/// retry action. Use this when an *entire screen* failed to load its primary
/// content (e.g. the first fetch of a tab threw) and the user has nothing else
/// to look at — as opposed to a transient failure during an interaction, which
/// should post a `NotificationStore` banner instead.
///
/// See `docs/specs/notifications-and-states.md` for the full
/// loading / error / empty decision matrix.
struct ErrorStateView: View {
    /// Short headline, e.g. "Couldn't load tasks".
    let title: String

    /// One or two sentences explaining what happened and what to do.
    let message: String

    /// SF Symbol for the glyph. Defaults to a neutral "no connection" icon.
    let systemImage: String

    /// Retry handler. When nil, the retry button is hidden (non-recoverable).
    let retry: (() -> Void)?

    /// - Parameters:
    ///   - title: headline.
    ///   - message: explanatory body text.
    ///   - systemImage: glyph (default `wifi.exclamationmark`).
    ///   - retry: optional retry action; hides the button when nil.
    init(
        title: String,
        message: String,
        systemImage: String = "wifi.exclamationmark",
        retry: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.retry = retry
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let retry {
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Convenience

extension ErrorStateView {
    /// Generic network-failure page wired to a retry closure. Convenience for
    /// the most common case so call sites don't restate boilerplate copy.
    static func networkFailure(retry: @escaping () -> Void) -> ErrorStateView {
        ErrorStateView(
            title: "Something went wrong",
            message: "We couldn't reach the server. Check your connection and try again.",
            systemImage: "wifi.exclamationmark",
            retry: retry
        )
    }
}

// MARK: - Previews

#Preview("With retry") {
    ErrorStateView.networkFailure(retry: {})
}

#Preview("No retry") {
    ErrorStateView(
        title: "Nothing to report",
        message: "This account has no completed tasks in the selected range.",
        systemImage: "chart.bar.xaxis"
    )
}
