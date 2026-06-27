//
//  EmptyStateView.swift
//  cue
//

import SwiftUI

/// Reusable empty state, built on `ContentUnavailableView`. Use this when a
/// screen or section loaded successfully but has *nothing to show yet* — an
/// empty day, a calendar with no groups, a report range with no completions —
/// as opposed to a *failure* to load (use `ErrorStateView`) or a load still in
/// flight (use `LoadingStateView`).
///
/// Layout follows the States kit "Empty states" specimen: a thin, quiet SF
/// Symbol glyph, a serif `.titleM` headline, a constrained `.callout` body, and
/// an optional secondary CTA (e.g. "New group") rendered with `.cue(.secondary)`.
///
/// See `docs/specs/notifications-and-states.md` for the full
/// loading / error / empty decision matrix.
struct EmptyStateView: View {
    @Environment(\.theme) private var theme

    /// Short headline, e.g. "No tasks".
    let title: String

    /// One short sentence explaining the emptiness, e.g. "Nothing scheduled for
    /// this day."
    let message: String

    /// SF Symbol for the glyph. Rendered thin and in `textSecondary` so it reads
    /// as a calm placeholder rather than an alarm.
    let systemImage: String

    /// Optional call-to-action title (e.g. "New group"). When nil, no button.
    let actionTitle: LocalizedStringKey?

    /// Optional CTA handler. Only used when `actionTitle` is also supplied.
    let action: (() -> Void)?

    /// - Parameters:
    ///   - title: headline.
    ///   - message: one-sentence explanation.
    ///   - systemImage: glyph (default a neutral "tray").
    ///   - actionTitle: optional CTA label; hides the button when nil.
    ///   - action: optional CTA handler; hides the button when nil.
    init(
        title: String,
        message: String,
        systemImage: String = "tray",
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityHidden(true)

                Text(title)
                    .cueText(.titleM)
                    .foregroundStyle(theme.textPrimary)
            }
        } description: {
            Text(message)
                .cueText(.callout)
                .foregroundStyle(theme.textSecondary)
                // Keep the body to a comfortable measure (~3-4 words/line) so it
                // reads as a calm caption, matching the specimen's 248pt cap.
                .frame(maxWidth: 248)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.cue(.secondary))
                    // Hug the label rather than stretching edge-to-edge.
                    .fixedSize()
            }
        }
    }
}

// MARK: - Previews

#Preview("No tasks") {
    EmptyStateView(
        title: "No tasks",
        message: "Nothing scheduled for this day.",
        systemImage: "checkmark.circle"
    )
    .environment(\.theme, AppPalette.kraftInk.colors)
}

#Preview("No groups · with CTA") {
    EmptyStateView(
        title: "No groups",
        message: "Tap + to create your first group.",
        systemImage: "folder",
        actionTitle: "New group",
        action: {}
    )
    .environment(\.theme, AppPalette.kraftInk.colors)
}
