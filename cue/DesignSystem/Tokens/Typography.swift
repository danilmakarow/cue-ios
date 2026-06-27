//
//  Typography.swift
//  cue
//
//  Semantic type system — one of the four design-token axes. See
//  docs/specs/design-tokens.md.
//
//  Three voices, each with one job (Kraft & Ink):
//    • Display / headings — Fraunces (bundled serif). The human, "set by a
//      typesetter" voice. Falls back to the system serif until the font loads.
//    • Body / labels      — Public Sans (bundled humanist sans — explicitly NOT
//      Inter/system). Plain-spoken, legible. Per-glyph fallback to the system
//      font covers Cyrillic (Public Sans ships latin-only), so `uk` text still
//      renders; Latin reads in Public Sans.
//    • Code / receipts    — JetBrains Mono (bundled). IDs, dates, amounts,
//      stamps, eyebrow micro-labels — the "recorded by the system" voice. Full
//      Cyrillic coverage.
//
//  Swapping a face later is a one-file edit: change `Typography.serifFamily`,
//  `bodyFamily`, or `monoFamily` (or a single role below). All three families
//  are bundled in cue/Resources/Fonts and registered in Config/Info.plist.
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
    /// Section title — serif.
    case titleL
    /// Card / row title — serif.
    case titleM
    /// Emphasised lead line — serif, reading size.
    case headline
    /// Default body copy — SF Pro.
    case body
    /// Emphasised body — SF Pro, medium.
    case bodyEmphasis
    /// Supporting copy — SF Pro, slightly smaller.
    case callout
    /// Field labels / eyebrows — SF Pro, medium, tight.
    case label
    /// Captions, footnotes — SF Pro, small.
    case caption
    /// The receipt voice — monospaced IDs, dates, amounts, stamps.
    case code
    /// Small monospaced detail (micro-labels).
    case codeSmall
}

enum Typography {
    /// The bundled display family. One place to swap the serif face.
    /// Resolves to the system serif until the font registers (graceful).
    static let serifFamily = "Fraunces"

    /// The bundled body family — Public Sans (humanist sans, NOT Inter/system).
    /// Per-glyph fallback to the system font handles glyphs Public Sans lacks
    /// (e.g. Cyrillic for `uk`), so missing glyphs never blank out.
    static let bodyFamily = "Public Sans"

    /// The bundled monospace family — JetBrains Mono (receipts / IDs / dates /
    /// eyebrow micro-labels). Full Cyrillic coverage.
    static let monoFamily = "JetBrains Mono"

    /// The resolved `Font` for a role, scaled by Dynamic Type via `relativeTo`.
    static func font(for role: TextRole) -> Font {
        switch role {
        case .displayL:
            return serif(34, relativeTo: .largeTitle).weight(.semibold)
        case .displayM:
            return serif(27, relativeTo: .title).weight(.semibold)
        case .titleL:
            return serif(22, relativeTo: .title2).weight(.medium)
        case .titleM:
            return serif(18, relativeTo: .title3).weight(.medium)
        case .headline:
            return serif(17, relativeTo: .headline).weight(.medium)
        case .body:
            return body(16, relativeTo: .body).weight(.regular)
        case .bodyEmphasis:
            return body(16, relativeTo: .body).weight(.semibold)
        case .callout:
            return body(15, relativeTo: .callout).weight(.regular)
        case .label:
            return body(13, relativeTo: .footnote).weight(.medium)
        case .caption:
            return body(12, relativeTo: .caption).weight(.regular)
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

    /// A Fraunces font at `size`, scaling with Dynamic Type relative to `style`.
    /// Falls back to the system serif when the custom font is unavailable.
    private static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(serifFamily, size: size, relativeTo: style)
    }

    /// A Public Sans body font at `size`, scaling with Dynamic Type relative to
    /// `style`. Per-glyph fallback to the system font covers any missing glyphs.
    private static func body(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(bodyFamily, size: size, relativeTo: style)
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
