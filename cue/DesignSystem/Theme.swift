//
//  Theme.swift
//  cue
//
//  The single source of truth for Cue's color system.
//
//  ─────────────────────────────────────────────────────────────────────────
//  "CUE — Clean" — ink on a white page, near-black + olive accents (mono look)
//  ─────────────────────────────────────────────────────────────────────────
//      #FFFFFF  PAGE     pure white canvas    →  app background AND cards (white)
//      #FFFFFF  GROUPED  pure white canvas    →  area behind grouped white cards
//      #F0EEEB  FILL     neutral gray fill    →  inputs, search bars, tracks, selected pills
//      #1A1A1A  INK-BLACK near-black          →  primary / brand / now-line / decisive CTA
//      #466234  OLIVE    earthy green         →  today / done / ON / positive
//      #1F1E1C  INK      warm near-black       →  text, headings, structural info
//      #A8331F BRICK (destructive) · #C9A24B BRASS (pending — ink on it)
//
//  (Clay #BE4A28 RETIRED as the brand color — primary/accent/secondary/waxSeal/
//  now-line/CTA are now near-black #1A1A1A, pressed #000000. Olive `success`
//  #466234 is unchanged and remains the today/done/ON/positive accent.)
//
//  Migrated FROM "Kraft & Ink" (espresso/warm-paper/letterpress, one rationed
//  clay seal). Now: pure-white surfaces, SOFT floating shadows (see Depth), and
//  GENEROUS balanced clay+olive accents. Selection rule: neutral selection = GRAY
//  fill; semantic emphasis = accent (today/done/ON = olive, brand/now = clay).
//  NOTE: the `kraftInk` palette symbol name is retained to avoid ripple; its
//  VALUES are now Clean (rename to `clean` is a deferred Phase-5 cleanup).
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
/// - **primary / primaryPressed** — the near-black hero for key actions and the tint.
/// - **secondary** — the near-black accent (CTA fills, the wax seal, thin accent
///   marks). Shares the `primary` ink; usable as fill or text.
/// - **accent** — alias of `primary`; mirrors the system `Color.accentColor`.
/// - **accentText** — near-black, safe to use as small text / icons / rules.
/// - **onAccent** — white ink placed on top of a `primary` or `secondary` fill.
/// - **textPrimary / textSecondary** — body and supporting text.
/// - **separator** — decorative hairlines (ornament only).
/// - **border** — functional edges a user must locate (inputs, card outlines).
/// - **success / warning / danger / info** — earthy semantic roles (olive /
///   brass-fill / brick / espresso). `warning` is a fill only — brass-as-text fails.
struct ThemeColors: Sendable, Equatable {
    let background: Color
    /// Grouped-list canvas behind white cards — pure white (`#FFFFFF`); cards read
    /// via their 1px border + soft shadow.
    let surfaceGrouped: Color
    let surface: Color
    let surfaceElevated: Color
    /// Neutral gray fill — inputs, search bars, segmented tracks, header strips (`#F0EEEB`).
    let surfaceSunken: Color
    /// Neutral selected / hover row fill (`#ECE9E6`). Distinct from accent selection.
    let fillSelected: Color
    let primary: Color
    let primaryPressed: Color
    let secondary: Color
    let accentText: Color
    /// Neutral light gray wash — selected chips, accent backgrounds (`#F2F1EF`).
    let accentSoft: Color
    let onAccent: Color
    let textPrimary: Color
    let textSecondary: Color
    /// Muted/placeholder/weekday-letter text (`#9C9893`).
    let textTertiary: Color
    let separator: Color
    let border: Color
    let success: Color
    /// Light olive wash — positive/today-accent backgrounds (`#E9EFE2`).
    let successSoft: Color
    /// Fresh, brighter green reserved for the "today" marker — distinct from the
    /// earthier olive `success` (`#466234`) so a today border reads as its own
    /// green next to a selected fill. Used for the week-strip today border + caption.
    let todayAccent: Color
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
    /// CUE — Clean — white workspace, warm-ink text, generous clay + olive
    /// accents, soft floating elevation. The sole identity. (Symbol name
    /// `kraftInk` retained to avoid ripple; rename to `clean` is a Phase-5 cleanup.)
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
            return (Color(hex: 0xFFFFFF), Color(hex: 0x1A1A1A), Color(hex: 0x466234))
        }
    }

    /// The resolved semantic colors for this option.
    var colors: ThemeColors {
        switch self {
        case .kraftInk: return Self.kraftInkColors
        }
    }

    // MARK: Resolved tables

    /// CUE — Clean: ink on a white page, near-black + olive accents. Single static
    /// colors (dark deferred; the app pins `.light`). When dark ships, swap each
    /// to `Color(light:dark:)`.
    ///
    /// Surfaces are pure white `#FFFFFF` (background AND cards); the grouped-list
    /// canvas behind cards is `surfaceGrouped` `#FFFFFF` (cards read via border +
    /// soft shadow); `surfaceSunken` `#F0EEEB` is the neutral gray component fill
    /// (inputs, tracks, selected pills). Depth comes from SOFT floating shadows
    /// (see `Depth`), not a value-step + border.
    ///
    /// Accessibility (sRGB / WCAG 2.1, on white `#FFFFFF`):
    /// - ink `#1F1E1C` text ≈ 16.1:1 (AAA); secondary `#6B6864` ≈ 5.5:1 (AA);
    ///   tertiary `#9C9893` ≈ 2.9:1 (placeholder/decorative only, not body text).
    /// - near-black `primary`/`secondary`/`accentText` `#1A1A1A` ≈ 15.3:1 (AAA) —
    ///   safe as both FILL and text; `primaryPressed` `#000000`. `onAccent` is white.
    /// - olive `success` `#466234` text ≈ 6.9:1 (AA); brick `danger` `#A8331F`
    ///   ≈ 6.6:1 (AA). Brass `warning` `#C9A24B` is a FILL — place dark INK on it.
    /// - `border` `#E6E3E0` functional edge and `separator` `#EFEDEA` decorative
    ///   hairline are intentionally light, leaning on the soft shadow for depth.
    ///
    /// Accent discipline (now generous, not rationed): near-black `primary` = brand /
    /// now-line / decisive CTA; olive `success` = today / done / ON / positive;
    /// neutral GRAY (`surfaceSunken`/`fillSelected`) = non-semantic selection.
    private static let kraftInkColors = ThemeColors(
        background: Color(hex: 0xFFFFFF),
        surfaceGrouped: Color(hex: 0xFFFFFF),
        surface: Color(hex: 0xFFFFFF),
        surfaceElevated: Color(hex: 0xFFFFFF),
        surfaceSunken: Color(hex: 0xF0EEEB),
        fillSelected: Color(hex: 0xECE9E6),
        primary: Color(hex: 0x1A1A1A),
        primaryPressed: Color(hex: 0x000000),
        secondary: Color(hex: 0x1A1A1A),
        accentText: Color(hex: 0x1A1A1A),
        accentSoft: Color(hex: 0xF2F1EF),
        onAccent: Color(hex: 0xFFFFFF),
        textPrimary: Color(hex: 0x1F1E1C),
        textSecondary: Color(hex: 0x6B6864),
        textTertiary: Color(hex: 0x9C9893),
        separator: Color(hex: 0xEFEDEA),
        border: Color(hex: 0xE6E3E0),
        success: Color(hex: 0x466234),
        successSoft: Color(hex: 0xE9EFE2),
        todayAccent: Color(hex: 0x4C9A5A),
        warning: Color(hex: 0xC9A24B),
        danger: Color(hex: 0xA8331F),
        info: Color(hex: 0x1F1E1C)
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
