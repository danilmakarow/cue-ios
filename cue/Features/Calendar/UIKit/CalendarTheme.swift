//
//  CalendarTheme.swift
//  cue
//

import SwiftUI
import UIKit

/// A plain, value-type projection of the SwiftUI design tokens into UIKit
/// primitives (`UIColor` / `UIFont` / `CGFloat`), for the UIKit calendar surface.
///
/// UIKit can't read SwiftUI's `@Environment(\.theme)`, so the representable host
/// builds one of these from the active ``ThemeColors`` and the current
/// `UITraitCollection`, then pushes it down into the container and every cell.
/// Rebuild and re-apply it whenever the SwiftUI theme changes
/// (`updateUIViewController`) or the content-size category changes
/// (`traitCollectionDidChange`).
///
/// **Colors** mirror the semantic roles of ``ThemeColors`` one-to-one, bridged
/// with `UIColor(_:)`. **Fonts** mirror the ``Typography`` ramp: each role's
/// base size + weight is reconstructed and scaled for Dynamic Type with
/// `UIFontMetrics` against the same text style ``Typography`` uses for its
/// `relativeTo:`. **Metrics** are fixed point values used by the day timeline
/// and the shared spacing/radius scale.
///
/// `Equatable` so a scope can early-out of a re-style when the theme is unchanged.
struct CalendarTheme: Equatable {

    // MARK: - Colors

    let background: UIColor
    let surface: UIColor
    let surfaceElevated: UIColor
    let surfaceSunken: UIColor
    let primary: UIColor
    let primaryPressed: UIColor
    let secondary: UIColor
    let accentText: UIColor
    let onAccent: UIColor
    let textPrimary: UIColor
    let textSecondary: UIColor
    let separator: UIColor
    let border: UIColor
    let success: UIColor
    let warning: UIColor
    let danger: UIColor
    let info: UIColor

    // MARK: - Fonts (Dynamic-Type-scaled)

    let displayL: UIFont
    let displayM: UIFont
    let titleL: UIFont
    let titleM: UIFont
    let headline: UIFont
    let body: UIFont
    let bodyEmphasis: UIFont
    let callout: UIFont
    let label: UIFont
    let caption: UIFont
    let code: UIFont
    let codeSmall: UIFont

    // MARK: - Metrics

    let spacingXS: CGFloat = 4
    let spacingSM: CGFloat = 8
    let spacingMD: CGFloat = 12
    let spacingLG: CGFloat = 16
    let spacingXL: CGFloat = 20
    let radiusSmall: CGFloat = 10
    let radiusMedium: CGFloat = 12
    let radiusCard: CGFloat = 12
    let radiusLarge: CGFloat = 14
    let hourHeight: CGFloat = 36
    let timelineTopPadding: CGFloat = 10

    // MARK: - Soft floating shadow (CUE — Clean)

    /// CUE — Clean depth params, mirroring the SwiftUI `Depth` token. A surface
    /// lifts off the white page with a gentle shadow plus a hairline border — the
    /// old Kraft blur-0 "letterpress value-cut" is retired.
    ///
    /// `CALayer` paints a single shadow, so the resting card uses the soft
    /// `restShadow*` pair and a floating/elevated surface uses the heavier
    /// `floatShadow*` pair. Opacity is baked into `shadowOpacity`; color the layer's
    /// `shadowColor` with `textPrimary` (already opaque) to match the SwiftUI token.
    let restShadowRadius: CGFloat = 2
    let restShadowOffset = CGSize(width: 0, height: 1)
    let restShadowOpacity: Float = 0.05
    let floatShadowRadius: CGFloat = 7
    let floatShadowOffset = CGSize(width: 0, height: 3)
    let floatShadowOpacity: Float = 0.05

    // MARK: - Init

    /// Builds the UIKit theme from the active semantic colors and a trait
    /// collection (whose `preferredContentSizeCategory` drives Dynamic Type).
    ///
    /// - Parameters:
    ///   - colors: the resolved SwiftUI ``ThemeColors`` for the active palette.
    ///   - traits: the trait collection to scale fonts for (content-size category).
    init(colors: ThemeColors, traits: UITraitCollection) {
        background = UIColor(colors.background)
        surface = UIColor(colors.surface)
        surfaceElevated = UIColor(colors.surfaceElevated)
        surfaceSunken = UIColor(colors.surfaceSunken)
        primary = UIColor(colors.primary)
        primaryPressed = UIColor(colors.primaryPressed)
        secondary = UIColor(colors.secondary)
        accentText = UIColor(colors.accentText)
        onAccent = UIColor(colors.onAccent)
        textPrimary = UIColor(colors.textPrimary)
        textSecondary = UIColor(colors.textSecondary)
        separator = UIColor(colors.separator)
        border = UIColor(colors.border)
        success = UIColor(colors.success)
        warning = UIColor(colors.warning)
        danger = UIColor(colors.danger)
        info = UIColor(colors.info)

        // Display / heading voices — the bundled serif face (falls back to the
        // system serif until the font registers), mirroring Typography's sizes,
        // weights and `relativeTo:` text styles. Body/label/caption — the native
        // system sans (SF Pro). Code — JetBrains Mono (bundled; falls back to
        // SF Mono). All scaled for `traits` via `UIFontMetrics`.
        displayL = Self.serif(34, weight: .semibold, relativeTo: .largeTitle, traits: traits)
        displayM = Self.serif(27, weight: .semibold, relativeTo: .title1, traits: traits)
        titleL = Self.serif(22, weight: .medium, relativeTo: .title2, traits: traits)
        titleM = Self.serif(18, weight: .medium, relativeTo: .title3, traits: traits)
        headline = Self.serif(17, weight: .medium, relativeTo: .headline, traits: traits)
        body = Self.bodyFont(16, weight: .regular, relativeTo: .body, traits: traits)
        bodyEmphasis = Self.bodyFont(16, weight: .semibold, relativeTo: .body, traits: traits)
        callout = Self.bodyFont(15, weight: .regular, relativeTo: .callout, traits: traits)
        label = Self.bodyFont(13, weight: .medium, relativeTo: .footnote, traits: traits)
        caption = Self.bodyFont(12, weight: .regular, relativeTo: .caption1, traits: traits)
        code = Self.monoFont(13, weight: .regular, relativeTo: .footnote, traits: traits)
        codeSmall = Self.monoFont(11, weight: .medium, relativeTo: .caption2, traits: traits)
    }

    // MARK: - Font builders

    /// A serif `UIFont` at `size`/`weight`, scaled for Dynamic Type relative to
    /// `style`. Falls back to the system serif design when the bundled face isn't
    /// registered, matching the SwiftUI token's behavior.
    private static func serif(
        _ size: CGFloat,
        weight: UIFont.Weight,
        relativeTo style: UIFont.TextStyle,
        traits: UITraitCollection
    ) -> UIFont {
        let base: UIFont
        if let serifFace = UIFont(name: Typography.serifFamily, size: size) {
            base = Self.applying(weight: weight, to: serifFace, size: size)
        } else {
            base = Self.designed(.serif, size: size, weight: weight)
        }
        return Self.scaled(base, relativeTo: style, traits: traits)
    }

    /// The native system-sans body `UIFont` at `size`/`weight`, scaled for
    /// Dynamic Type relative to `style`. Matches the SwiftUI body token, which
    /// now uses the system font (SF Pro) rather than a bundled face.
    private static func bodyFont(
        _ size: CGFloat,
        weight: UIFont.Weight,
        relativeTo style: UIFont.TextStyle,
        traits: UITraitCollection
    ) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        return Self.scaled(base, relativeTo: style, traits: traits)
    }

    /// The bundled JetBrains Mono `UIFont` at `size`/`weight`, scaled for Dynamic
    /// Type relative to `style`. Falls back to SF Mono when the bundled face
    /// isn't registered, matching the SwiftUI code token's behavior.
    private static func monoFont(
        _ size: CGFloat,
        weight: UIFont.Weight,
        relativeTo style: UIFont.TextStyle,
        traits: UITraitCollection
    ) -> UIFont {
        let base: UIFont
        if let jetBrains = UIFont(name: Typography.monoFamily, size: size) {
            base = Self.applying(weight: weight, to: jetBrains, size: size)
        } else {
            base = UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        }
        return Self.scaled(base, relativeTo: style, traits: traits)
    }

    /// A system font with an explicit design (e.g. `.serif`) and weight at `size`.
    /// Used as the graceful fallback when the bundled serif isn't available.
    private static func designed(
        _ design: UIFontDescriptor.SystemDesign,
        size: CGFloat,
        weight: UIFont.Weight
    ) -> UIFont {
        let weighted = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = weighted.fontDescriptor.withDesign(design) else {
            return weighted
        }
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Applies a weight trait to a named (non-system) font without changing its
    /// family, so the bundled serif honors the role's weight where possible.
    private static func applying(weight: UIFont.Weight, to font: UIFont, size: CGFloat) -> UIFont {
        let descriptor = font.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight],
        ])
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Scales a base font for the given trait collection's content-size category,
    /// relative to `style` — the UIKit equivalent of SwiftUI's
    /// `.custom(_:size:relativeTo:)` / `.system(size:)` Dynamic Type behavior.
    private static func scaled(
        _ base: UIFont,
        relativeTo style: UIFont.TextStyle,
        traits: UITraitCollection
    ) -> UIFont {
        UIFontMetrics(forTextStyle: style).scaledFont(for: base, compatibleWith: traits)
    }
}
