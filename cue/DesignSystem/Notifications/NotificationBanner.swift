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
    @Environment(\.theme) private var theme

    /// The notification to render.
    let notification: AppNotification

    /// Whether the detail section is currently revealed. Driven by the store.
    let isExpanded: Bool

    /// Called when the user taps an expandable banner's body.
    let onToggleExpand: () -> Void

    /// Called when the user taps the close button.
    let onDismiss: () -> Void

    // Banner corner radius. The States kit error specimen draws the banner at a
    // 12pt radius (`Radius.medium`), softer than the floating ceiling.
    private let radius: CGFloat = Radius.medium

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            severityRail

            severityIcon

            content

            Spacer(minLength: 0)

            closeButton
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Hug the content vertically. Without this the severity rail's
        // `maxHeight: .infinity` makes the banner greedy, so the host's
        // full-height overlay stretches every banner to fill the screen.
        .fixedSize(horizontal: false, vertical: true)
        // The banner stays intentionally Liquid Glass (chrome), per the depth
        // system's `.glass` treatment — distinct from the letterpress cards.
        .glassEffect(.regular, in: .rect(cornerRadius: radius))
        // Neutral hairline edge — severity is carried by the rail + icon stamp,
        // not by tinting the frame (matches CueBanner's `--glass-border`).
        .overlay(
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(theme.separator, lineWidth: 1)
        )
        .contentShape(.rect(cornerRadius: radius))
        .onTapGesture(perform: handleBodyTap)
        // Combine the message body into one element so the title, message and
        // expand affordance read as a single banner — but expose dismissal as a
        // first-class named action so VoiceOver keeps an independent "Dismiss"
        // (it would otherwise be flattened away by `.combine`).
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(notification.isExpandable ? .isButton : [])
        .accessibilityAction(named: Text("notification.dismiss"), onDismiss)
    }

    // MARK: - Color

    /// Maps severity onto the active palette's functional roles, resolved here
    /// (not on the `Sendable` enum) so it always tracks the theme.
    private var severityColor: Color {
        switch notification.severity {
        case .info: return theme.info
        case .success: return theme.success
        case .warning: return theme.warning
        case .error: return theme.danger
        }
    }

    // MARK: - Subviews

    /// The filled severity-colored 22pt stamp circle with the severity glyph
    /// centered inside. White ink on the fill, except `warning` (brass), which
    /// uses dark `textPrimary` ink for contrast — matching the CueBanner spec.
    private var severityIcon: some View {
        Image(systemName: notification.severity.systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(notification.severity == .warning ? theme.textPrimary : theme.onAccent)
            .frame(width: 22, height: 22)
            .background(Circle().fill(severityColor))
            .accessibilityHidden(true)
    }

    /// The vertical severity-colored rail on the leading edge.
    private var severityRail: some View {
        Capsule()
            .fill(severityColor)
            .frame(width: 4)
            .frame(maxHeight: .infinity)
            .accessibilityHidden(true)
    }

    /// Title, optional collapsed message, the revealed mono detail block, and the
    /// "Show more / Show less" disclosure on expandable banners.
    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(notification.title)
                .cueText(.bodyEmphasis)
                .foregroundStyle(theme.textPrimary)

            if let message = notification.message {
                Text(message)
                    .cueText(.callout)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(isExpanded ? nil : 2)
            }

            if isExpanded, let detail = notification.detail {
                detailBlock(detail)
            }

            if notification.isExpandable {
                disclosureButton
            }
        }
    }

    /// The HTTP / diagnostic detail line, revealed when expanded. Rendered in
    /// JetBrains Mono inside a sunken, hairline-bordered box per the States kit
    /// error specimen — selectable so the user can copy the payload.
    private func detailBlock(_ detail: String) -> some View {
        Text(detail)
            .cueText(.code)
            .foregroundStyle(theme.textPrimary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .fill(theme.surfaceSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .strokeBorder(theme.separator, lineWidth: 1)
            )
            .padding(.top, Spacing.xs)
    }

    /// Tappable "Show more / Show less" disclosure shown on expandable banners.
    /// A real button (not a decorative cue) per the States kit error specimen:
    /// the chevron rotates 0↔180° as the detail reveals. Uses the clay
    /// accent-text (AA-safe) — one of the few sanctioned clay text uses.
    private var disclosureButton: some View {
        let disclosureLabel: LocalizedStringKey = isExpanded ? "notification.showLess" : "notification.showDetails"
        return Button(action: toggleExpansion) {
            HStack(spacing: Spacing.xs) {
                Text(disclosureLabel)
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .cueText(.caption)
            .foregroundStyle(theme.accentText)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.top, Spacing.xxs)
        .accessibilityHidden(true)
    }

    /// Trailing dismiss control. Visually present, but hidden from VoiceOver: the
    /// banner combines its body into one element, so dismissal is surfaced via the
    /// root's `.accessibilityAction(named: "Dismiss")` rather than as a stray
    /// flattened button inside the combined label.
    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 28, height: 28)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    // MARK: - Interaction

    /// Toggles expansion when the banner is expandable; otherwise the body tap
    /// is inert (close button handles dismissal). The whole-body tap and the
    /// disclosure button both route through `toggleExpansion`.
    private func handleBodyTap() {
        toggleExpansion()
    }

    /// Animates the detail disclosure open/closed via the store-owned callback.
    /// Guarded so a non-expandable banner ignores the gesture entirely.
    private func toggleExpansion() {
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
        Color(hex: 0xFFFFFF)
            .ignoresSafeArea()

        VStack(spacing: Spacing.md) {
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
