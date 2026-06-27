//
//  Depth.swift
//  cue
//
//  Elevation/depth token — one of the four design-token axes. Encodes the
//  Kraft & Ink rule "letterpress, not float": depth comes from a value-step and
//  a functional border, not from soft drop shadows. See docs/specs/design-tokens.md.
//

import SwiftUI

/// How a surface sits relative to the page.
///
/// Replaces the three incompatible idioms the app used to mix (soft drop
/// shadows, flat opacity fills, ad-hoc glass) with one named choice.
enum Depth {
    /// No elevation — sits flat on its background.
    case flat
    /// Pressed into the paper: a 1pt functional border plus a faint warm
    /// value-cut beneath. The default for cards.
    case letterpress
    /// A crisp, hard-edged warm offset (a printed/stacked-paper edge) — no blur.
    case valueCut
    /// Explicit passthrough to the system Liquid Glass material, for chrome that
    /// is intentionally glass (notification banner, floating controls).
    case glass
}

private struct CueDepthModifier: ViewModifier {
    @Environment(\.theme) private var theme

    let depth: Depth
    let radius: CGFloat

    func body(content: Content) -> some View {
        switch depth {
        case .flat:
            content
        case .letterpress:
            content
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1)
                )
                .shadow(color: theme.textPrimary.opacity(0.06), radius: 0, x: 0, y: 1)
        case .valueCut:
            content
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1)
                )
                .shadow(color: theme.textPrimary.opacity(0.12), radius: 0, x: 0, y: 2)
        case .glass:
            content
                .glassEffect(.regular, in: .rect(cornerRadius: radius))
        }
    }
}

extension View {
    /// Applies a Kraft & Ink depth treatment ("letterpress, not float").
    /// - Parameters:
    ///   - depth: the elevation style.
    ///   - radius: corner radius the treatment should match (default `Radius.small`).
    func cueDepth(_ depth: Depth, radius: CGFloat = Radius.small) -> some View {
        modifier(CueDepthModifier(depth: depth, radius: radius))
    }
}
