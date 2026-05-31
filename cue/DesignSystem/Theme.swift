//
//  Theme.swift
//  cue
//
//  The single source of truth for Cue's color system.
//
//  ─────────────────────────────────────────────────────────────────────────
//  Brand palette (4 base colors)
//  ─────────────────────────────────────────────────────────────────────────
//      #FFF9D2  pale warm yellow   →  app background (light canvas)
//      #FFEBCC  soft peach         →  app surface    (cards / grouped rows)
//      #BFDDF0  light sky blue     →  secondary accent (subtle tints, fills)
//      #8CC0EB  medium blue        →  primary / accent (buttons, selection, tint)
//
//  Roles, not hex, are what the rest of the app references. Read the
//  "Semantic tokens" section below for the full vocabulary
//  (`Color.appBackground`, `.appSurface`, `.appPrimary`, …).
//
//  Light vs dark: the supplied palette is light-leaning, so light mode uses it
//  almost literally — warm "paper" canvas, warm surfaces, cool-blue ink. Dark
//  mode is *designed*, not inverted: deep blue-charcoal neutrals (the brand's
//  cool identity carried into the dark) with a slightly brightened blue accent.
//  Warm tones are intentionally NOT used as dark surfaces (they read as muddy
//  brown on black); they survive only as faint accent hints.
//

import SwiftUI

// MARK: - Appearance

/// User-selectable appearance preference. `.system` follows the OS.
enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// Human-readable label for pickers. Localized via the String Catalog.
    var displayName: String {
        switch self {
        case .system: return String(localized: "theme.appearance.system")
        case .light: return String(localized: "theme.appearance.light")
        case .dark: return String(localized: "theme.appearance.dark")
        }
    }

    /// Value to pass to `.preferredColorScheme(_)`. `nil` defers to the OS.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Brand palette (raw values)

/// The raw brand colors and their derived shades.
///
/// These are *implementation detail*: feature code should never reach in here.
/// Use the semantic `Color.app…` tokens (declared further down) instead — they
/// map intent ("background", "primary") onto these raw values and pick the
/// right light/dark variant automatically.
///
/// Shades are derived from the four bases by mixing toward white or black
/// (`mix(with:by:)`) so the whole system stays inside the brand's hue family
/// instead of introducing unrelated colors.
enum BrandPalette {
    // The four supplied base colors.
    static let warmYellow = Color(hex: 0xFFF9D2) // pale warm yellow
    static let peach = Color(hex: 0xFFEBCC)      // soft peach
    static let skyBlue = Color(hex: 0xBFDDF0)    // light sky blue
    static let blue = Color(hex: 0x8CC0EB)       // medium blue (the hero color)

    // Derived blue family — steps around the hero color for hierarchy.
    /// A deeper, more saturated blue for pressed states and ink that must read
    /// on light surfaces. Used as the *dark*-mode accent base too (brightened).
    static let blueDeep = Color(hex: 0x4F96C9)
    /// A brighter blue for dark mode so the accent stays vivid on dark fills.
    static let blueBright = Color(hex: 0x9CCBF0)
    /// Very dark navy used as "ink on accent": dark text/icons placed on top of
    /// the light blue accent (white fails WCAG contrast on `#8CC0EB`).
    static let navyInk = Color(hex: 0x0E2A3D)

    // Derived warm family — lighter/darker paper tones for light mode.
    /// Slightly deeper than `warmYellow`; used for elevated warm fills.
    static let warmYellowDeep = Color(hex: 0xFCEFB0)
    /// A soft warm hairline/separator tone for light mode.
    static let warmBorder = Color(hex: 0xEAD9B0)

    // Dark-mode neutral family — blue-leaning charcoals (cool, on-brand).
    /// App canvas in dark mode (near-black with a hint of blue).
    static let inkBackground = Color(hex: 0x12171D)
    /// Card/surface in dark mode — one step lighter than the canvas.
    static let inkSurface = Color(hex: 0x1C232B)
    /// Elevated surface (sheets, popovers) in dark mode.
    static let inkSurfaceElevated = Color(hex: 0x252E38)
    /// Hairline/separator tone in dark mode.
    static let inkBorder = Color(hex: 0x35404C)

    // Text tones.
    /// Primary text in dark mode — warm-leaning off-white for comfort.
    static let textLight = Color(hex: 0xF3F6FA)
    /// Secondary text in dark mode.
    static let textLightMuted = Color(hex: 0xA8B4C2)
    /// Primary text in light mode — deep navy (on-brand, not pure black).
    static let textDark = Color(hex: 0x16242E)
    /// Secondary text in light mode.
    static let textDarkMuted = Color(hex: 0x5A6B78)
}

// MARK: - Semantic tokens

/// Intent-named color tokens — the vocabulary the rest of the app speaks.
///
/// Every token resolves to a different value in light and dark via the
/// `Color(light:dark:)` initializer, so a single token name renders correctly
/// in both appearances. Reference these (`Color.appBackground`, `.appPrimary`,
/// …) instead of raw palette colors or `Color(hex:)`.
///
/// Roles:
/// - **background** — the app canvas behind everything.
/// - **surface / surfaceElevated** — cards, grouped rows, sheets sitting on top.
/// - **primary / primaryPressed** — the hero brand color for key actions.
/// - **secondary** — quieter brand accent for subtle fills and selection tints.
/// - **accent** — alias of `primary`; matches the system `Color.accentColor`.
/// - **onAccent** — ink (text/icons) placed on top of a `primary`/`accent` fill.
/// - **textPrimary / textSecondary** — body and supporting text.
/// - **separator** — hairlines and dividers.
extension Color {
    /// App canvas behind all content. Warm paper (light) / blue-charcoal (dark).
    static let appBackground = Color(
        light: BrandPalette.warmYellow,
        dark: BrandPalette.inkBackground
    )

    /// Card / grouped-row surface that sits on the background.
    static let appSurface = Color(
        light: BrandPalette.peach,
        dark: BrandPalette.inkSurface
    )

    /// Higher-elevation surface for sheets, popovers, floating panels.
    static let appSurfaceElevated = Color(
        light: BrandPalette.warmYellowDeep,
        dark: BrandPalette.inkSurfaceElevated
    )

    /// Hero brand color for primary actions, selection, and the app tint.
    static let appPrimary = Color(
        light: BrandPalette.blue,
        dark: BrandPalette.blueBright
    )

    /// Pressed / active variant of `appPrimary`.
    static let appPrimaryPressed = Color(
        light: BrandPalette.blueDeep,
        dark: BrandPalette.blue
    )

    /// Quieter brand accent — subtle tinted fills, selected-cell backgrounds.
    static let appSecondary = Color(
        light: BrandPalette.skyBlue,
        dark: BrandPalette.blueDeep
    )

    /// Semantic alias of `appPrimary`. Mirrors the asset-backed
    /// `Color.accentColor`, so either name yields the brand blue.
    static let appAccent = appPrimary

    /// Ink (text / icons) for content placed *on top of* `appPrimary`/`appAccent`.
    /// Deep navy in both modes — white would fail WCAG contrast on the light blue.
    static let appOnAccent = Color(
        light: BrandPalette.navyInk,
        dark: BrandPalette.navyInk
    )

    /// Primary body text.
    static let appTextPrimary = Color(
        light: BrandPalette.textDark,
        dark: BrandPalette.textLight
    )

    /// Secondary / supporting text.
    static let appTextSecondary = Color(
        light: BrandPalette.textDarkMuted,
        dark: BrandPalette.textLightMuted
    )

    /// Hairlines, dividers, and subtle borders.
    static let appSeparator = Color(
        light: BrandPalette.warmBorder,
        dark: BrandPalette.inkBorder
    )
}

// MARK: - Accent color

/// Accent colors selectable in Settings.
///
/// `.brand` is Cue's signature medium blue (`#8CC0EB`) and the default. The
/// remaining cases let the user override the system tint with a standard hue.
/// Stored as a raw string so it round-trips through `UserDefaults`.
enum AppAccentColor: String, CaseIterable, Identifiable, Sendable {
    case brand
    case blue
    case indigo
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case teal

    var id: String { rawValue }

    /// SwiftUI color to tint the app with.
    /// `.brand` resolves to the appearance-aware brand primary token.
    var color: Color {
        switch self {
        case .brand: return .appPrimary
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .teal: return .teal
        }
    }

    /// Human-readable label for accessibility and pickers. Localized via the
    /// String Catalog so color names translate (e.g. "Blue" → "Синій").
    var displayName: String {
        switch self {
        case .brand: return String(localized: "theme.accent.brand", defaultValue: "Cue Blue")
        case .blue: return String(localized: "theme.accent.blue")
        case .indigo: return String(localized: "theme.accent.indigo")
        case .purple: return String(localized: "theme.accent.purple")
        case .pink: return String(localized: "theme.accent.pink")
        case .red: return String(localized: "theme.accent.red")
        case .orange: return String(localized: "theme.accent.orange")
        case .yellow: return String(localized: "theme.accent.yellow")
        case .green: return String(localized: "theme.accent.green")
        case .teal: return String(localized: "theme.accent.teal")
        }
    }
}

// MARK: - ThemeSettings

/// Global, user-editable theme preferences persisted to `UserDefaults`.
/// Inject into the environment once at the app root via `.environment(_)`
/// and read downstream with `@Environment(ThemeSettings.self)`.
@Observable
@MainActor
final class ThemeSettings {
    // MARK: Private

    private enum Keys {
        static let appearance = "theme.appearance"
        static let accentColor = "theme.accentColor"
    }

    private let userDefaults: UserDefaults

    // MARK: Public

    /// Current appearance preference. Writing persists to `UserDefaults`.
    var appearance: AppearanceMode {
        didSet {
            userDefaults.set(appearance.rawValue, forKey: Keys.appearance)
        }
    }

    /// Current accent color preference. Writing persists to `UserDefaults`.
    var accentColor: AppAccentColor {
        didSet {
            userDefaults.set(accentColor.rawValue, forKey: Keys.accentColor)
        }
    }

    // MARK: Init

    /// Loads persisted preferences, falling back to defaults (`.system`, `.brand`).
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let appearanceRaw = userDefaults.string(forKey: Keys.appearance)
            ?? AppearanceMode.system.rawValue
        self.appearance = AppearanceMode(rawValue: appearanceRaw) ?? .system

        let accentRaw = userDefaults.string(forKey: Keys.accentColor)
            ?? AppAccentColor.brand.rawValue
        self.accentColor = AppAccentColor(rawValue: accentRaw) ?? .brand
    }
}

// MARK: - Color utilities

extension Color {
    /// Builds a `Color` from a packed 24-bit RGB hex literal (e.g. `0x8CC0EB`).
    /// - Parameter hex: `0xRRGGBB`. The alpha component is always opaque.
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }

    /// Builds a dynamic color that resolves to `light` in light mode and `dark`
    /// in dark mode, mirroring how an asset-catalog color with "Any/Dark"
    /// appearances behaves — but expressed in code so every role is reviewable
    /// in one file.
    /// - Parameters:
    ///   - light: color used in light (and unspecified) appearances.
    ///   - dark: color used in dark appearance.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }

    /// Returns a copy of this color blended toward `other` by `fraction`
    /// (0 → unchanged, 1 → fully `other`). Used to derive shade steps inside
    /// `BrandPalette` while staying in the brand hue family.
    /// - Parameters:
    ///   - other: the color to blend toward (commonly `.white` or `.black`).
    ///   - fraction: blend amount in `0...1`.
    func mix(with other: Color, by fraction: Double) -> Color {
        let clamped = min(max(fraction, 0), 1)
        let base = UIColor(self)
        let target = UIColor(other)

        var baseRed: CGFloat = 0, baseGreen: CGFloat = 0, baseBlue: CGFloat = 0, baseAlpha: CGFloat = 0
        var targetRed: CGFloat = 0, targetGreen: CGFloat = 0, targetBlue: CGFloat = 0, targetAlpha: CGFloat = 0
        base.getRed(&baseRed, green: &baseGreen, blue: &baseBlue, alpha: &baseAlpha)
        target.getRed(&targetRed, green: &targetGreen, blue: &targetBlue, alpha: &targetAlpha)

        let blend = { (lhs: CGFloat, rhs: CGFloat) -> Double in
            Double(lhs + (rhs - lhs) * CGFloat(clamped))
        }
        return Color(
            .sRGB,
            red: blend(baseRed, targetRed),
            green: blend(baseGreen, targetGreen),
            blue: blend(baseBlue, targetBlue),
            opacity: blend(baseAlpha, targetAlpha)
        )
    }
}
