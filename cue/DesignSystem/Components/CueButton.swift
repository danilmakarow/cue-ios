//
//  CueButton.swift
//  cue
//
//  The app's button style. Replaces ad-hoc .bordered/.borderedProminent/
//  .destructive with named, themed variants. Apply via `.buttonStyle(.cue(.primary))`.
//

import SwiftUI

/// Visual variants for `CueButtonStyle`.
enum CueButtonVariant {
    /// Clay fill, white label — the structural affirmative action (links,
    /// confirm, "Save changes"). The everyday primary.
    case primary
    /// Clay fill, white label — the ONE rationed hot CTA: the commit moment a
    /// screen is built around (create event, finish). Visually identical to
    /// `primary` (both resolve to clay now); the distinction is CONTEXT, not hue —
    /// reserve `decisive` for the single hero CTA per screen so it reads as the
    /// commit, with everything else staying secondary/ghost around it.
    case decisive
    /// Transparent + 1px functional border, clay label — secondary actions.
    case secondary
    /// Brick fill, white label — destructive actions (delete, disconnect).
    case destructive
    /// Clay accent-text, no fill — inline/tertiary actions.
    case ghost
}

/// CUE — Clean button style. Soft 10pt `Radius.small` corner, a 1pt downward
/// press nudge paired with a one-step-darker fill (no scale, no glow),
/// 160ms ease-out. Disabled buttons dim to 50%.
struct CueButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    let variant: CueButtonVariant

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .cueText(.bodyEmphasis)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.lg)
            .background(background(pressed: pressed))
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            // Press signature: a 1pt downward nudge instead of a scale/shadow,
            // paired with the darker fill below, so the control reads as pressed in.
            .offset(y: pressed ? 1 : 0)
            .opacity(opacity(pressed: pressed))
            .animation(.easeOut(duration: 0.16), value: pressed)
    }

    private var foreground: Color {
        switch variant {
        case .primary, .decisive, .destructive: return theme.onAccent
        case .secondary: return theme.primary
        case .ghost: return theme.accentText
        }
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
        switch variant {
        case .primary:
            shape.fill(pressed ? theme.primaryPressed : theme.primary)
        case .decisive:
            // Same clay fill as primary — the distinction is context (the one hero
            // CTA), not hue. Press steps one shade darker to `primaryPressed`.
            shape.fill(pressed ? theme.primaryPressed : theme.secondary)
        case .destructive:
            shape.fill(theme.danger).opacity(pressed ? 0.85 : 1)
        case .secondary:
            shape.fill(pressed ? theme.surfaceSunken : Color.clear)
        case .ghost:
            Color.clear
        }
    }

    @ViewBuilder
    private var border: some View {
        if variant == .secondary {
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1)
        }
    }

    private func opacity(pressed: Bool) -> Double {
        if !isEnabled { return 0.5 }
        if variant == .ghost && pressed { return 0.6 }
        return 1
    }
}

extension ButtonStyle where Self == CueButtonStyle {
    /// The CUE — Clean button style in the given variant.
    static func cue(_ variant: CueButtonVariant) -> CueButtonStyle {
        CueButtonStyle(variant: variant)
    }
}

// MARK: - Preview

#Preview("CueButton variants") {
    VStack(spacing: Spacing.lg) {
        Button("Create event") {}.buttonStyle(.cue(.decisive))
        Button("Save changes") {}.buttonStyle(.cue(.primary))
        Button("Add another") {}.buttonStyle(.cue(.secondary))
        Button("Delete task") {}.buttonStyle(.cue(.destructive))
        Button("Skip for now") {}.buttonStyle(.cue(.ghost))
        Button("Disabled") {}.buttonStyle(.cue(.primary)).disabled(true)
    }
    .padding(Spacing.xxl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(hex: 0xFFFFFF))
}
