//
//  Spacing.swift
//  cue
//
//  Semantic spacing scale — one of the four design-token axes (color, type,
//  spacing, radius). See docs/specs/design-tokens.md.
//

import SwiftUI

/// The app's spacing scale, on a 4pt grid. Feature code spaces and pads with
/// these named steps instead of raw literals, so the whole app's rhythm is a
/// one-file edit.
///
/// React analogy: a `theme.space` scale (`space.md`, `space.lg`) consumed
/// everywhere rather than hardcoded pixel values sprinkled through components.
///
/// Usage:
/// ```swift
/// VStack(spacing: Spacing.md) { … }
/// .padding(.horizontal, Spacing.lg)
/// ```
enum Spacing {
    /// 2pt — hairline gaps (e.g. a glyph hugging its label).
    static let xxs: CGFloat = 2
    /// 4pt — very tight inline gaps.
    static let xs: CGFloat = 4
    /// 8pt — within-control padding, chip insets.
    static let sm: CGFloat = 8
    /// 12pt — label-to-field, compact stacks.
    static let md: CGFloat = 12
    /// 16pt — the default gap; card inner padding.
    static let lg: CGFloat = 16
    /// 20pt — between fields, roomy card padding.
    static let xl: CGFloat = 20
    /// 24pt — between cards, section padding.
    static let xxl: CGFloat = 24
    /// 32pt — between major sections.
    static let xxxl: CGFloat = 32
    /// 48pt — hero / empty-state breathing room.
    static let huge: CGFloat = 48
}
