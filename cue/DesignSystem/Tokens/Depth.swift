//
//  Depth.swift
//  cue
//
//  Elevation/depth token — one of the four design-token axes. CUE — Clean uses
//  SOFT FLOATING SHADOWS (the old Kraft "letterpress, not float" blur-0 treatment
//  is retired). Surfaces lift off the white page with a gentle shadow plus a
//  hairline border, not a hard value-cut. See docs/specs/design-tokens.md.
//

import SwiftUI

/// How a surface sits relative to the page.
///
/// Replaces the three incompatible idioms the app used to mix (soft drop
/// shadows, flat opacity fills, ad-hoc glass) with one named choice.
///
/// The case names `letterpress` / `valueCut` are retained to avoid ripple, but
/// they now render as Clean soft shadows: `letterpress` → resting card shadow,
/// `valueCut` → heavier floating/elevated shadow.
enum Depth {
    /// No elevation — sits flat on its background.
    case flat
    /// Resting card: a 1pt hairline border plus a soft resting shadow
    /// (`0 1px 2px / 5%`). The default for cards.
    case letterpress
    /// Floating / elevated: a 1pt hairline border plus a layered float shadow
    /// (`0 1px 2px / 4%` + `0 3px 7px / 5%`) for movable or raised surfaces.
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
                .shadow(color: theme.textPrimary.opacity(0.05), radius: 2, x: 0, y: 1)
        case .valueCut:
            content
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1)
                )
                .shadow(color: theme.textPrimary.opacity(0.04), radius: 2, x: 0, y: 1)
                .shadow(color: theme.textPrimary.opacity(0.05), radius: 7, x: 0, y: 3)
        case .glass:
            content
                .glassEffect(.regular, in: .rect(cornerRadius: radius))
        }
    }
}

extension View {
    /// Applies a CUE — Clean depth treatment (soft floating shadow + hairline).
    /// - Parameters:
    ///   - depth: the elevation style.
    ///   - radius: corner radius the treatment should match (default `Radius.small`).
    func cueDepth(_ depth: Depth, radius: CGFloat = Radius.small) -> some View {
        modifier(CueDepthModifier(depth: depth, radius: radius))
    }
}
