//
//  NotificationBanner.swift
//  cue
//

import SwiftUI

/// A single liquid-glass notification banner. Pure presentation: it takes a
/// payload plus two callbacks and reports interaction outward. It holds no
/// queue state — expansion is owned by `NotificationStore` and passed in — so
/// the same banner renders identically in the host overlay and in previews.
///
/// Layout: a leading severity rail + icon, a title/message column that reveals
/// `detail` when expanded, and a trailing close button. Tapping the body (when
/// the notification is expandable) calls `onToggleExpand`.
struct NotificationBanner: View {
    /// The notification to render.
    let notification: AppNotification

    /// Whether the detail section is currently revealed. Driven by the store.
    let isExpanded: Bool

    /// Called when the user taps an expandable banner's body.
    let onToggleExpand: () -> Void

    /// Called when the user taps the close button.
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            severityRail

            Image(systemName: notification.severity.systemImage)
                .font(.title3)
                .foregroundStyle(notification.severity.tint)
                .accessibilityHidden(true)

            content

            Spacer(minLength: 0)

            closeButton
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Hug the content vertically. Without this the severity rail's
        // `maxHeight: .infinity` makes the banner greedy, so the host's
        // full-height overlay stretches every banner to fill the screen. The
        // rail still spans the content height (like a Divider); expanding an
        // error simply grows the banner to fit its detail.
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(notification.severity.tint.opacity(0.25), lineWidth: 1)
        )
        .contentShape(.rect(cornerRadius: 18))
        .onTapGesture(perform: handleBodyTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(notification.isExpandable ? .isButton : [])
    }

    // MARK: - Subviews

    /// The vertical severity-colored rail on the leading edge.
    private var severityRail: some View {
        Capsule()
            .fill(notification.severity.tint)
            .frame(width: 4)
            .frame(maxHeight: .infinity)
            .accessibilityHidden(true)
    }

    /// Title, optional collapsed message, and the revealed detail block.
    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(notification.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            if let message = notification.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 2)
            }

            if isExpanded, let detail = notification.detail {
                Divider()
                    .padding(.vertical, 2)

                Text(detail)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if notification.isExpandable {
                expandAffordance
            }
        }
    }

    /// Small "Show more / Show less" cue shown on expandable banners.
    private var expandAffordance: some View {
        let disclosureLabel: LocalizedStringKey = isExpanded ? "notification.showLess" : "notification.showDetails"
        return HStack(spacing: 3) {
            Text(disclosureLabel)
            Image(systemName: "chevron.down")
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(notification.severity.tint)
        .padding(.top, 2)
        .accessibilityHidden(true)
    }

    /// Trailing dismiss control.
    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("notification.dismiss")
    }

    // MARK: - Interaction

    /// Toggles expansion when the banner is expandable; otherwise the body tap
    /// is inert (close button handles dismissal).
    private func handleBodyTap() {
        guard notification.isExpandable else { return }
        withAnimation(.snappy) {
            onToggleExpand()
        }
    }

    // MARK: - Accessibility

    /// Combined spoken label: "Error. <title>. <message>".
    private var accessibilityLabel: String {
        var parts = [notification.severity.accessibilityPrefix, notification.title]
        if let message = notification.message {
            parts.append(message)
        }
        return parts.joined(separator: ". ")
    }

    /// Spoken hint guiding the expand/collapse interaction.
    private var accessibilityHint: String {
        guard notification.isExpandable else { return "" }
        return isExpanded
            ? String(localized: "notification.a11y.collapseHint")
            : String(localized: "notification.a11y.expandHint")
    }
}

// MARK: - Previews

#Preview("Banner variants") {
    ZStack {
        LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

        VStack(spacing: 12) {
            NotificationBanner(
                notification: .success("Event saved", message: "Dentist at 3:00 PM was added."),
                isExpanded: false,
                onToggleExpand: {},
                onDismiss: {}
            )
            NotificationBanner(
                notification: .warning("Working offline", message: "Changes will sync when you reconnect."),
                isExpanded: false,
                onToggleExpand: {},
                onDismiss: {}
            )
            NotificationBanner(
                notification: .error(
                    "Couldn't save event",
                    message: "The server rejected the request.",
                    detail: "HTTP 422\n\n{\n  \"statusCode\": 422,\n  \"message\": [\"title should not be empty\"],\n  \"error\": \"Unprocessable Entity\"\n}"
                ),
                isExpanded: true,
                onToggleExpand: {},
                onDismiss: {}
            )
        }
        .padding()
    }
}
