//
//  Radius.swift
//  cue
//
//  Corner-radius scale — one of the four design-token axes. See
//  docs/specs/design-tokens.md.
//

import SwiftUI

/// The app's corner-radius scale. CUE — Clean uses SOFT corners (the old Kraft
/// "cut paper" 4–10pt is retired): chips at 8pt, buttons/fields at 10pt, cards at
/// 12pt, a 14pt floating ceiling, and 16pt for the FAB. Depth comes from a soft
/// floating shadow (see `Depth`), not a big radius — capsules are still reserved
/// for genuinely segmented toggles.
///
/// React analogy: `theme.radii` tokens consumed instead of magic `border-radius`
/// values scattered across components.
enum Radius {
    /// 0pt — square, hairline-bordered edges.
    static let none: CGFloat = 0
    /// 2pt — barely-rounded micro-controls.
    static let tight: CGFloat = 2
    /// 8pt — chips and small selectable pills (soft, not a hard cut).
    static let chip: CGFloat = 8
    /// 10pt — the default radius for buttons, fields, and overlays.
    static let small: CGFloat = 10
    /// 12pt — icon tiles, grouped rows, inset containers.
    static let medium: CGFloat = 12
    /// 12pt — cards / tiles.
    static let card: CGFloat = 12
    /// 14pt — the floating-element ceiling (prominent sheets / elevated cards).
    static let large: CGFloat = 14
    /// 16pt — the FAB and large floating affordances.
    static let xlarge: CGFloat = 16
}
