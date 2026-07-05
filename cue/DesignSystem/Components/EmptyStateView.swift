//
//  EmptyStateView.swift
//  cue
//

import SwiftUI

/// How an ``EmptyStateView`` CTA paints itself.
///
/// - `secondary`: a quiet outline button (clear fill + 1px border + clay label) —
///   the calm default used by Today and most screens.
/// - `primary`: a FILLED clay button (clay fill + white label) with a leading "+"
///   glyph — the decisive "create your first …" CTA the Groups empty state asks for.
enum EmptyStateCTAStyle {
    case secondary
    case primary
}

/// Reusable empty state, built on `ContentUnavailableView`. Use this when a
/// screen or section loaded successfully but has *nothing to show yet* — an
/// empty day, a calendar with no groups, a report range with no completions —
/// as opposed to a *failure* to load (use `ErrorStateView`) or a load still in
/// flight (use `LoadingStateView`).
///
/// Layout follows the CUE — Clean "Empty states" specimen: the glyph sits inside
/// a 64×64 WHITE rounded tile (`Radius.card`, 1px `theme.border`, soft resting
/// shadow) rather than as a bare SF Symbol, under a serif `.titleM` headline, a
/// constrained `.callout` body, and an optional CTA. The CTA's treatment is the
/// caller's choice via ``EmptyStateCTAStyle`` — Today keeps the quiet `.secondary`
/// outline (the default), while Groups opts into the FILLED clay `.primary` button
/// (white label, leading "+" glyph) that the Groups empty-state design specifies.
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

    /// SF Symbol for the glyph. Rendered in `textSecondary` inside a white tile so
    /// it reads as a calm placeholder rather than an alarm.
    let systemImage: String

    /// Optional call-to-action title (e.g. "New group"). When nil, no button.
    let actionTitle: LocalizedStringKey?

    /// How the CTA paints — `.secondary` (quiet outline, default) or `.primary`
    /// (filled clay, white label, leading "+" glyph).
    let ctaStyle: EmptyStateCTAStyle

    /// Optional CTA handler. Only used when `actionTitle` is also supplied.
    let action: (() -> Void)?

    /// - Parameters:
    ///   - title: headline.
    ///   - message: one-sentence explanation.
    ///   - systemImage: glyph (default a neutral "tray").
    ///   - actionTitle: optional CTA label; hides the button when nil.
    ///   - ctaStyle: CTA treatment — `.secondary` outline (default) or `.primary`
    ///     filled clay with a leading "+" glyph.
    ///   - action: optional CTA handler; hides the button when nil.
    init(
        title: String,
        message: String,
        systemImage: String = "tray",
        actionTitle: LocalizedStringKey? = nil,
        ctaStyle: EmptyStateCTAStyle = .secondary,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.ctaStyle = ctaStyle
        self.action = action
    }

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: Spacing.md) {
                glyphTile

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
                cta(actionTitle, action: action)
            }
        }
    }

    /// The empty glyph inside a 64×64 white rounded tile (`Radius.card`, 1px
    /// `theme.border`, soft resting shadow) — the CUE — Clean treatment that
    /// replaces the bare 44pt SF Symbol.
    private var glyphTile: some View {
        Image(systemName: systemImage)
            .font(.system(size: 30, weight: .regular))
            .foregroundStyle(theme.textSecondary)
            .frame(width: 64, height: 64)
            .background(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(theme.surface)
            )
            .cueDepth(.letterpress, radius: Radius.card)
            .accessibilityHidden(true)
    }

    /// Renders the CTA in the requested treatment. `.primary` is a filled clay
    /// button with a leading "+" glyph; `.secondary` is the quiet outline default.
    @ViewBuilder
    private func cta(_ actionTitle: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        switch ctaStyle {
        case .primary:
            Button(action: action) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "plus")
                    Text(actionTitle)
                }
            }
            .buttonStyle(.cue(.primary))
        case .secondary:
            Button(actionTitle, action: action)
                .buttonStyle(.cue(.secondary))
                // Hug the label rather than stretching edge-to-edge.
                .fixedSize()
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

#Preview("No groups · filled clay CTA") {
    EmptyStateView(
        title: "No groups",
        message: "Tap + to create your first group.",
        systemImage: "folder",
        actionTitle: "Create your first group",
        ctaStyle: .primary,
        action: {}
    )
    .environment(\.theme, AppPalette.kraftInk.colors)
}
