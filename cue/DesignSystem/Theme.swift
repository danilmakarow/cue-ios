//
//  Theme.swift
//  cue
//
//  The single source of truth for Cue's color system.
//
//  ─────────────────────────────────────────────────────────────────────────
//  "Kraft & Ink on white" — espresso ink on a clean white page
//  ─────────────────────────────────────────────────────────────────────────
//      #FFFFFF  PAGE     pure white canvas    →  the page behind everything
//      #FAF6EF  SHEET    faint warm paper     →  cards, panels (lift by value + 1px edge)
//      #FEFCF8  RISER    near-white sheet     →  top sheets / elevated surfaces
//      #F1EADF  TRAY     muted recessed tan   →  header strips, table zebra
//      #5A3A24  ESPRESSO warm brown ink       →  the hero / primary / tint
//      #2E211A  INK      near-black warm       →  text and headings
//      #BE4A28  CLAY     warmed terracotta    →  the ONE rationed accent / TODAY seal
//      #466234  OLIVE / #A8331F BRICK / #C9A24B BRASS — earthy status colors
//
//  This is a deliberate variation of the canonical Kraft & Ink spec: its canvas
//  was kraft tan #F2E8D8; here the canvas is WHITE and the paper warmth is
//  carried by the INK and ACCENTS instead. The surface ramp is retuned because
//  "lighter than the canvas" inverts on white — surfaces now lift by faint
//  warmth + a 1px functional edge (letterpress), not by going lighter.
//
//  The rest of the app never references hex or raw palette colors — it speaks in
//  *roles* (`theme.background`, `theme.primary`, …) read from the environment.
//
//  Kraft & Ink is the sole, opinionated identity (it replaced the earlier
//  "Traveler" Desert/Dusk options). Dark mode is deferred — the app pins the
//  light appearance for now — so each role is a single static color; when dark
//  ships, swap the table to `Color(light:dark:)` pairs and nothing else changes.
//
//  Color is one of four token axes; see Tokens/{Spacing,Radius,Typography,Depth}
//  and docs/specs/design-tokens.md for the full system.
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

// MARK: - Traveler palette (legacy raw source colors)

/// The five raw "Traveler" colors. *Legacy* — retained only because the brand
/// mark (`BrandMark`) still composes from them; it will be reworked to Kraft &
/// Ink separately. Feature code must never reach in here — read the semantic
/// `ThemeColors` roles from the environment (`@Environment(\.theme)`) instead.
enum TravelerColor {
    static let cloud = Color(hex: 0xCDD0DB)  // pale lavender-grey
    static let azul = Color(hex: 0x9197AA)   // muted slate blue
    static let mimosa = Color(hex: 0xF7B557) // warm golden amber
    static let orange = Color(hex: 0xE27921) // terracotta orange (the hero)
    static let aperol = Color(hex: 0xC1521E) // deep burnt sienna
}

// MARK: - Semantic color roles

/// A fully-resolved set of intent-named color roles for the active palette.
///
/// A single value is injected once at the app root via `EnvironmentValues.theme`
/// and read downstream with `@Environment(\.theme)` — the React analogy is one
/// `ThemeContext.Provider` at the root and `useContext(Theme)` in the leaves.
///
/// Surfaces (by value): `background` (canvas) → `surface` (cards) →
/// `surfaceElevated` (top sheets, lighter) and `surfaceSunken` (recessed
/// strips, darker). Depth comes from these value-steps plus `border`, not from
/// soft shadows — see `Depth`.
///
/// Roles:
/// - **background** — the app canvas behind everything.
/// - **surface / surfaceElevated / surfaceSunken** — cards, raised sheets, and
///   recessed strips (header bands, table zebra), respectively.
/// - **primary / primaryPressed** — the espresso hero for key actions and the tint.
/// - **secondary** — the rationed clay accent (CTA fills, the wax seal, thin
///   accent marks). A *fill* color; for clay-as-text use `accentText`.
/// - **accent** — alias of `primary`; mirrors the system `Color.accentColor`.
/// - **accentText** — the deepened clay safe to use as small text / icons / rules.
/// - **onAccent** — cream ink placed on top of a `primary` or `secondary` fill.
/// - **textPrimary / textSecondary** — body and supporting text.
/// - **separator** — decorative hairlines (ornament only).
/// - **border** — functional edges a user must locate (inputs, card outlines).
/// - **success / warning / danger / info** — earthy semantic roles (olive /
///   brass-fill / brick / espresso). `warning` is a fill only — brass-as-text fails.
struct ThemeColors: Sendable, Equatable {
    let background: Color
    let surface: Color
    let surfaceElevated: Color
    let surfaceSunken: Color
    let primary: Color
    let primaryPressed: Color
    let secondary: Color
    let accentText: Color
    let onAccent: Color
    let textPrimary: Color
    let textSecondary: Color
    let separator: Color
    let border: Color
    let success: Color
    let warning: Color
    let danger: Color
    let info: Color

    /// Semantic alias of `primary`, for call sites that think in terms of the
    /// system accent tint.
    var accent: Color { primary }
}

// MARK: - Palette options

/// The selectable color options. Kraft & Ink is currently the only one; the
/// enum is retained (rather than collapsed to a struct) so re-introducing a
/// second palette later is a one-case addition with no plumbing changes.
///
/// Stored as a raw string so it round-trips through `UserDefaults`.
enum AppPalette: String, CaseIterable, Identifiable, Sendable {
    /// Kraft & Ink — warm kraft-paper workspace, espresso ink, one rationed clay
    /// wax-seal accent. The sole identity.
    case kraftInk

    var id: String { rawValue }

    /// Localized option name for the picker.
    var titleKey: LocalizedStringKey {
        switch self {
        case .kraftInk: return "theme.palette.kraftInk"
        }
    }

    /// Localized one-line description shown under the option name.
    var subtitleKey: LocalizedStringKey {
        switch self {
        case .kraftInk: return "theme.palette.kraftInk.subtitle"
        }
    }

    /// Three representative colors for the picker swatch: canvas, primary, accent.
    var swatch: (canvas: Color, primary: Color, secondary: Color) {
        switch self {
        case .kraftInk:
            return (Color(hex: 0xFFFFFF), Color(hex: 0x5A3A24), Color(hex: 0xBE4A28))
        }
    }

    /// The resolved semantic colors for this option.
    var colors: ThemeColors {
        switch self {
        case .kraftInk: return Self.kraftInkColors
        }
    }

    // MARK: Resolved tables

    /// Kraft & Ink on white — espresso ink on a clean white page. Single static
    /// colors (dark deferred; the app pins `.light`). When dark ships, swap each
    /// to `Color(light:dark:)`.
    ///
    /// Surface ramp (retuned for a white canvas — you cannot go lighter than
    /// white, so surfaces lift by faint warmth + a 1px functional edge, not by
    /// going lighter): white `#FFFFFF` page → `surface` `#FAF6EF` (faint warm
    /// paper) → `surfaceElevated` `#FEFCF8` (near-white top sheet) →
    /// `surfaceSunken` `#F1EADF` (muted recessed tan, descendant of the old kraft).
    ///
    /// Accessibility (measured, sRGB / WCAG 2.1 — re-verified on the white canvas
    /// and on every surface tone; lowest figure per role shown is on `sunken`):
    /// - ink `#2E211A` text: white 15.57:1, surface 14.45, elevated 15.20, sunken 13.03 — AAA.
    /// - muted `#6E5C4C` text: white 6.37:1, surface 5.91, elevated 6.21, sunken 5.33 — AA.
    /// - espresso `#5A3A24` (primary/info) text: white 10.17:1, sunken 8.51 — AAA.
    /// - clay-as-text `accentText` `#A53D22`: white 6.38:1, sunken 5.34 — AA. (The
    ///   seal fill `secondary` `#BE4A28` is ~3.6:1 on white — FILL ONLY, never text.)
    /// - success olive `#466234` text: white 6.87:1, sunken 5.75 — AA.
    /// - danger brick `#A8331F` text: white 6.65:1, sunken 5.56 — AA.
    /// - cream `onAccent` `#FBF5EA` on fills: on primary 9.37:1, on primaryPressed
    ///   12.32, on seal `#BE4A28` 4.61 (AA), on success 6.33, on danger 6.13.
    /// - `border` `#8C7142` functional edge: 4.61:1 on white, 3.86 on sunken
    ///   (clears the 3:1 non-text minimum on every surface).
    /// - `separator` `#D0BA98` is decorative ornament only: ~1.88:1 on white,
    ///   ~1.58 on sunken — faintly visible, intentionally below the functional
    ///   `border` so it never reads as an edge. (Bumped darker from the spec's
    ///   `#D8C4A6`, which nearly vanished on white at ~1.70:1.)
    /// - brass `warning` `#C9A24B` is a FILL only: ink `#2E211A` on it ≈ 6.49:1;
    ///   cream on it ≈ 2.21:1 — so place INK (never cream, never text-as-brass) on it.
    ///
    /// More-accent discipline: the rationed terracotta `secondary` is the
    /// calendar's one-hot moment — the TODAY / now marker. Olive `success` carries
    /// completed/agreed states, brass `warning` carries pending/draft-like states,
    /// espresso `primary` stays structural. Color presence, not a rainbow.
    private static let kraftInkColors = ThemeColors(
        background: Color(hex: 0xFFFFFF),
        surface: Color(hex: 0xFAF6EF),
        surfaceElevated: Color(hex: 0xFEFCF8),
        surfaceSunken: Color(hex: 0xF1EADF),
        primary: Color(hex: 0x5A3A24),
        primaryPressed: Color(hex: 0x43291A),
        secondary: Color(hex: 0xBE4A28),
        accentText: Color(hex: 0xA53D22),
        onAccent: Color(hex: 0xFBF5EA),
        textPrimary: Color(hex: 0x2E211A),
        textSecondary: Color(hex: 0x6E5C4C),
        separator: Color(hex: 0xD0BA98),
        border: Color(hex: 0x8C7142),
        success: Color(hex: 0x466234),
        warning: Color(hex: 0xC9A24B),
        danger: Color(hex: 0xA8331F),
        info: Color(hex: 0x5A3A24)
    )
}

// MARK: - Theme environment

extension EnvironmentValues {
    /// The active semantic colors for the current palette option. Injected once
    /// at the app root from `ThemeSettings.palette.colors`; defaults to Kraft &
    /// Ink so previews and detached views still resolve.
    @Entry var theme: ThemeColors = AppPalette.kraftInk.colors
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
    /// (Dark mode is deferred; the app currently pins `.light` at the root.)
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

    /// Loads persisted preferences, falling back to defaults (`.system`, `.kraftInk`).
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let appearanceRaw = userDefaults.string(forKey: Keys.appearance)
            ?? AppearanceMode.system.rawValue
        self.appearance = AppearanceMode(rawValue: appearanceRaw) ?? .system

        let paletteRaw = userDefaults.string(forKey: Keys.palette)
            ?? AppPalette.kraftInk.rawValue
        self.palette = AppPalette(rawValue: paletteRaw) ?? .kraftInk
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
    /// in one file. (Currently unused by Kraft & Ink, which is light-only;
    /// retained for when a dark palette ships.)
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
