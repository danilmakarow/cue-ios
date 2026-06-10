//
//  Theme.swift
//  cue
//
//  The single source of truth for Cue's color system.
//
//  ─────────────────────────────────────────────────────────────────────────
//  "The Traveler" — a warm desert-meets-dusk palette (5 source colors)
//  ─────────────────────────────────────────────────────────────────────────
//      #CDD0DB  CLOUD   pale lavender-grey   →  cool neutral / background base
//      #9197AA  AZUL    muted slate blue     →  calm cool grounding tone
//      #F7B557  MIMOSA  warm golden amber    →  highlights, calls-to-attention
//      #E27921  ORANGE  terracotta orange    →  the vibrant hero / primary
//      #C1521E  APEROL  deep burnt sienna    →  darkest, strong contrast
//
//  The rest of the app never references hex or raw palette colors — it speaks in
//  *roles* (`theme.background`, `theme.primary`, …) read from the environment.
//
//  Two switchable options, each fully designed for light AND dark:
//    • Desert — warm-led. Sand canvas, terracotta-orange primary, mimosa accent.
//    • Dusk   — cool-led. Lavender-grey canvas, slate-blue primary, mimosa spark.
//
//  Dark mode is *designed*, not inverted: Desert dark is a warm near-black, Dusk
//  dark a cool blue-black, each with a brightened accent. Per the brand, plain
//  white / black are avoided — neutrals are tinted toward the option's identity.
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

    /// Picker label as a `LocalizedStringKey`, resolved by SwiftUI against the
    /// current `\.locale` so the picker re-localizes live on a language change.
    var titleKey: LocalizedStringKey {
        switch self {
        case .system: return "theme.appearance.system"
        case .light: return "theme.appearance.light"
        case .dark: return "theme.appearance.dark"
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

// MARK: - Traveler palette (raw source colors)

/// The five raw "Traveler" colors. *Implementation detail* — feature code should
/// never reach in here; read the semantic `ThemeColors` roles from the
/// environment (`@Environment(\.theme)`) instead. These exist so the brand mark
/// and the two palette options can compose from one source of truth.
enum TravelerColor {
    static let cloud = Color(hex: 0xCDD0DB)  // pale lavender-grey
    static let azul = Color(hex: 0x9197AA)   // muted slate blue
    static let mimosa = Color(hex: 0xF7B557) // warm golden amber
    static let orange = Color(hex: 0xE27921) // terracotta orange (the hero)
    static let aperol = Color(hex: 0xC1521E) // deep burnt sienna
}

// MARK: - Semantic color roles

/// A fully-resolved set of intent-named color roles for one palette option.
///
/// Each role is a *dynamic* light/dark color, so a single value renders correctly
/// in both appearances automatically (driven by `.preferredColorScheme` / the
/// OS). The only thing that varies at runtime is *which option* is in force —
/// that is injected once at the app root via `EnvironmentValues.theme` and read
/// downstream with `@Environment(\.theme)`.
///
/// Roles:
/// - **background** — the app canvas behind everything.
/// - **surface / surfaceElevated** — cards, grouped rows, sheets on top.
/// - **primary / primaryPressed** — the hero color for key actions and the tint.
/// - **secondary** — the warm highlight (mimosa) for subtle fills and selection.
/// - **accent** — alias of `primary`; mirrors the system `Color.accentColor`.
/// - **onAccent** — ink (text / icons) placed on top of a `primary` fill.
/// - **textPrimary / textSecondary** — body and supporting text.
/// - **separator** — hairlines and dividers.
struct ThemeColors: Sendable {
    let background: Color
    let surface: Color
    let surfaceElevated: Color
    let primary: Color
    let primaryPressed: Color
    let secondary: Color
    let onAccent: Color
    let textPrimary: Color
    let textSecondary: Color
    let separator: Color

    /// Semantic alias of `primary`, for call sites that think in terms of the
    /// system accent tint.
    var accent: Color { primary }
}

// MARK: - Palette options

/// The user-selectable color options. Replaces the old free accent-color picker:
/// instead of an arbitrary hue, the user chooses one of two cohesive, fully
/// designed palettes built from "The Traveler".
///
/// Stored as a raw string so it round-trips through `UserDefaults`.
enum AppPalette: String, CaseIterable, Identifiable, Sendable {
    /// Warm-led: sand canvas, terracotta-orange primary, mimosa accent. The
    /// vibrant, energetic identity. The default.
    case desert
    /// Cool-led: lavender-grey canvas, slate-blue primary, mimosa as the warm
    /// spark. The calm, blue-hour identity.
    case dusk

    var id: String { rawValue }

    /// Localized option name for the picker (e.g. "Desert").
    var titleKey: LocalizedStringKey {
        switch self {
        case .desert: return "theme.palette.desert"
        case .dusk: return "theme.palette.dusk"
        }
    }

    /// Localized one-line description shown under the option name.
    var subtitleKey: LocalizedStringKey {
        switch self {
        case .desert: return "theme.palette.desert.subtitle"
        case .dusk: return "theme.palette.dusk.subtitle"
        }
    }

    /// Three representative light-mode colors for the picker swatch:
    /// canvas, primary, and secondary highlight.
    var swatch: (canvas: Color, primary: Color, secondary: Color) {
        switch self {
        case .desert:
            return (Color(hex: 0xF3EDE4), Color(hex: 0xBA4D17), TravelerColor.mimosa)
        case .dusk:
            return (Color(hex: 0xE9EBF1), Color(hex: 0x586280), TravelerColor.mimosa)
        }
    }

    /// The resolved semantic colors for this option. Each role is a dynamic
    /// light/dark color, so the same `ThemeColors` value renders in both
    /// appearances; only the option selection changes it.
    var colors: ThemeColors {
        switch self {
        case .desert: return Self.desertColors
        case .dusk: return Self.duskColors
        }
    }

    // MARK: Resolved tables

    /// Desert — warm-led. Light: warm sand canvas + terracotta hero. Dark: warm
    /// near-black with a brightened orange so the accent stays vivid.
    ///
    /// The light primary is a *deepened* terracotta (`#BA4D17`) rather than the
    /// raw ORANGE `#E27921`: the bright orange is a mid-luminance "dead zone" hue
    /// that can't clear WCAG 3:1 as a tint on the pale canvas nor carry AA ink, so
    /// it would make every accent glyph/label inaccessible in the default theme.
    /// The vivid `#E27921` still leads the app icon and the dark-mode accent.
    private static let desertColors = ThemeColors(
        background: Color(light: 0xF3EDE4, dark: 0x17120D),
        surface: Color(light: 0xFBF7F0, dark: 0x211A13),
        surfaceElevated: Color(light: 0xFFFDF9, dark: 0x2C241B),
        primary: Color(light: 0xBA4D17, dark: 0xEE8B3B),
        primaryPressed: Color(light: 0x9C3D12, dark: 0xE27921),
        secondary: Color(light: 0xF7B557, dark: 0xF7B557),
        onAccent: Color(light: 0xFFF7EC, dark: 0x2A190B),
        textPrimary: Color(light: 0x2C2118, dark: 0xF4ECE1),
        textSecondary: Color(light: 0x7A6657, dark: 0xB8A693),
        separator: Color(light: 0xE6DBCB, dark: 0x3A3127)
    )

    /// Dusk — cool-led. Light: lavender-grey canvas + deepened slate-blue hero,
    /// mimosa as the warm spark. Dark: cool blue-black with a light periwinkle
    /// accent so the cool tone reads on the dark canvas.
    private static let duskColors = ThemeColors(
        background: Color(light: 0xE9EBF1, dark: 0x13151B),
        surface: Color(light: 0xF4F5F9, dark: 0x1C1F27),
        surfaceElevated: Color(light: 0xFCFCFE, dark: 0x252934),
        primary: Color(light: 0x586280, dark: 0x97A0C2),
        primaryPressed: Color(light: 0x434C66, dark: 0x7B85AB),
        secondary: Color(light: 0xF7B557, dark: 0xF7B557),
        onAccent: Color(light: 0xF5F6FA, dark: 0x14161D),
        textPrimary: Color(light: 0x21242E, dark: 0xECEEF5),
        textSecondary: Color(light: 0x5F6678, dark: 0xA2A8BA),
        separator: Color(light: 0xD7DAE3, dark: 0x2E323D)
    )
}

// MARK: - Theme environment

extension EnvironmentValues {
    /// The active semantic colors for the current palette option. Injected once
    /// at the app root from `ThemeSettings.palette.colors`; defaults to Desert so
    /// previews and detached views still resolve.
    @Entry var theme: ThemeColors = AppPalette.desert.colors
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
        static let palette = "theme.palette"
    }

    private let userDefaults: UserDefaults

    // MARK: Public

    /// Current appearance preference. Writing persists to `UserDefaults`.
    var appearance: AppearanceMode {
        didSet {
            userDefaults.set(appearance.rawValue, forKey: Keys.appearance)
        }
    }

    /// Current palette option. Writing persists to `UserDefaults`.
    var palette: AppPalette {
        didSet {
            userDefaults.set(palette.rawValue, forKey: Keys.palette)
        }
    }

    // MARK: Init

    /// Loads persisted preferences, falling back to defaults (`.system`, `.desert`).
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let appearanceRaw = userDefaults.string(forKey: Keys.appearance)
            ?? AppearanceMode.system.rawValue
        self.appearance = AppearanceMode(rawValue: appearanceRaw) ?? .system

        let paletteRaw = userDefaults.string(forKey: Keys.palette)
            ?? AppPalette.desert.rawValue
        self.palette = AppPalette(rawValue: paletteRaw) ?? .desert
    }
}

// MARK: - Color utilities

extension Color {
    /// Builds a `Color` from a packed 24-bit RGB hex literal (e.g. `0xE27921`).
    /// - Parameter hex: `0xRRGGBB`. The alpha component is always opaque.
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }

    /// Builds a `Color` from a CSS hex string (`#RRGGBB` or `RRGGBB`). Returns
    /// `nil` for malformed input. Used to render group colors persisted as hex
    /// strings by the backend.
    init?(hex string: String) {
        var cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned = String(cleaned.dropFirst()) }
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            return nil
        }
        self.init(hex: value)
    }

    /// Builds a dynamic color that resolves to `light` in light mode and `dark`
    /// in dark mode, mirroring how an asset-catalog color with "Any/Dark"
    /// appearances behaves — but expressed in code so every role is reviewable
    /// in one file.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }

    /// Convenience over `init(light:dark:)` that takes packed hex literals, so the
    /// palette tables read as compact `0xRRGGBB` pairs.
    init(light: UInt32, dark: UInt32) {
        self.init(light: Color(hex: light), dark: Color(hex: dark))
    }
}
