//
//  Radius.swift
//  cue
//
//  Corner-radius scale — one of the four design-token axes. See
//  docs/specs/design-tokens.md.
//

import SwiftUI

/// The app's corner-radius scale. Kraft & Ink favours crisp "cut paper" edges
/// (no 16–20pt squircle bubbles): chips at 4pt, buttons/fields at 6pt, cards at
/// 10pt. The depth comes from a 1px border + value-step, not a big radius —
/// capsules are reserved for genuinely segmented toggles, never for chips.
///
/// React analogy: `theme.radii` tokens consumed instead of magic `border-radius`
/// values scattered across components.
enum Radius {
    /// 0pt — square, hairline-bordered edges.
    static let none: CGFloat = 0
    /// 2pt — barely-rounded micro-controls.
    static let tight: CGFloat = 2
    /// 4pt — chips: word + filled/empty shape, a hard "rubber-stamp" corner
    /// (never a pill). One step tighter than buttons so chips read as marks, not
    /// controls.
    static let chip: CGFloat = 4
    /// 6pt — the default "cut paper" radius for buttons, fields, overlays.
    static let small: CGFloat = 6
    /// 8pt — slightly softer containers (icon tiles, grouped rows).
    static let medium: CGFloat = 8
    /// 10pt — cards. Roomier than a button but still a crisp cut sheet (not a
    /// 16–20pt bubble), letting the 1px border + value-step do the lifting.
    static let card: CGFloat = 10
    /// 12pt — large surfaces (sheets, prominent cards).
    static let large: CGFloat = 12
}
