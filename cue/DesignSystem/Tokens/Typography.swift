//
//  Typography.swift
//  cue
//
//  Semantic type system — one of the four design-token axes. See
//  docs/specs/design-tokens.md.
//
//  Three voices, each with one job (CUE — Clean):
//    • Display — IBM Plex Serif (bundled). The editorial, upright slab serif.
//      LARGE-SCREEN TITLES ONLY (display-L / display-M — app name, big screen
//      titles / page H1); never section headers, row labels, or body. Section /
//      card / row titles (title-L, title-M, headline) render in the system sans.
//      Falls back to the system serif until the font loads.
//    • Body / labels      — the native system sans (SF Pro / -apple-system), via
//      SwiftUI's Dynamic-Type text styles. Full Unicode incl. Cyrillic for `uk`.
//      (Replaces the bundled Public Sans, which was latin-only.)
//    • Code / receipts    — JetBrains Mono (bundled). IDs, dates, amounts,
//      stamps, eyebrow micro-labels — the "recorded by the system" voice.
//
//  Swapping the serif/mono face later is a one-line edit (`serifFamily` /
//  `monoFamily`). Both are bundled in cue/Resources/Fonts and registered in
//  Config/Info.plist. Body uses the system font (no bundle needed).
//

import SwiftUI

/// A semantic text role. Views call `.cueText(.titleM)` instead of reaching for
/// `.font(.system(size:))`, so the type ramp is defined in exactly one place.
///
/// React analogy: a `<Text variant="titleM">` component whose variants resolve
/// to font/size/tracking from the theme, rather than ad-hoc inline font styles.
enum TextRole {
    /// Screen hero — the largest serif voice (app name, big screen titles).
    case displayL
    /// Secondary hero — large serif.
    case displayM
    /// Section title — system sans (22pt). Serif is reserved for display roles.
    case titleL
    /// Card / row title — system sans (18pt). Serif is reserved for display roles.
    case titleM
    /// Emphasised lead line — system sans, reading size (17pt).
    case headline
    /// Default body copy — system sans (16pt).
    case body
    /// Emphasised body — system sans, semibold (16pt). Button labels.
    case bodyEmphasis
    /// Supporting copy — system sans (15pt).
    case callout
    /// Field labels / eyebrows — system sans, medium (13pt).
    case label
    /// Captions, footnotes — system sans (12pt).
    case caption
    /// The receipt voice — monospaced IDs, dates, amounts, stamps (13pt).
    case code
    /// Small monospaced detail (micro-labels, 11pt).
    case codeSmall
}

enum Typography {
    /// The bundled display family. One place to swap the serif face.
    /// Resolves to the system serif until the font registers (graceful).
    static let serifFamily = "IBM Plex Serif"

    /// The bundled monospace family — JetBrains Mono (receipts / IDs / dates /
    /// eyebrow micro-labels). Full Cyrillic coverage.
    static let monoFamily = "JetBrains Mono"

    /// The resolved `Font` for a role, scaled by Dynamic Type. Serif/mono roles
    /// scale via `.custom(_:size:relativeTo:)`; body roles use the native system
    /// text styles (which carry exact ramp sizes and scale automatically).
    static func font(for role: TextRole) -> Font {
        switch role {
        case .displayL:
            return serif(34, relativeTo: .largeTitle).weight(.semibold)
        case .displayM:
            return serif(27, relativeTo: .title).weight(.semibold)
        case .titleL:
            return .system(.title2).weight(.medium)          // 22pt sans
        case .titleM:
            return .system(.title3).weight(.medium)          // 18pt sans
        case .headline:
            return .system(.headline).weight(.medium)        // 17pt sans
        case .body:
            return .system(.callout).weight(.regular)        // 16pt
        case .bodyEmphasis:
            return .system(.callout).weight(.semibold)       // 16pt
        case .callout:
            return .system(.subheadline).weight(.regular)    // 15pt
        case .label:
            return .system(.footnote).weight(.medium)        // 13pt
        case .caption:
            return .system(.caption).weight(.regular)        // 12pt
        case .code:
            return mono(13, relativeTo: .footnote).weight(.regular)
        case .codeSmall:
            return mono(11, relativeTo: .caption2).weight(.medium)
        }
    }

    /// Letter-spacing per role (points). Display reads tighter; receipts read wider.
    static func tracking(for role: TextRole) -> CGFloat {
        switch role {
        case .displayL, .displayM: return -0.4
        case .titleL, .titleM: return -0.2
        case .label: return 0.3
        case .code: return 0.2
        case .codeSmall: return 0.8
        default: return 0
        }
    }

    /// An IBM Plex Serif font at `size`, scaling with Dynamic Type relative to
    /// `style`. Falls back to the system serif when the custom font is unavailable.
    private static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(serifFamily, size: size, relativeTo: style)
    }

    /// A JetBrains Mono font at `size`, scaling with Dynamic Type relative to
    /// `style`. Falls back to the system font when unavailable.
    private static func mono(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(monoFamily, size: size, relativeTo: style)
    }
}

// MARK: - View sugar

private struct CueTextModifier: ViewModifier {
    let role: TextRole

    func body(content: Content) -> some View {
        content
            .font(Typography.font(for: role))
            .tracking(Typography.tracking(for: role))
    }
}

extension View {
    /// Applies a semantic text role (font + tracking). Color stays separate —
    /// set it with `.foregroundStyle(theme.textPrimary)` etc.
    func cueText(_ role: TextRole) -> some View {
        modifier(CueTextModifier(role: role))
    }
}
