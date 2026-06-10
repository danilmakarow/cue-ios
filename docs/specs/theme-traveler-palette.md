# Spec: "The Traveler" color theme + magnifying-glass brand mark

Status: Implemented (2026-06-08)

## Context

Cue previously shipped a four-color warm-paper/blue palette with a *free accent-color
picker* (10 hues) and a calendar-and-clock brand mark. We are replacing the entire
color identity with **"The Traveler"** — a warm desert-meets-dusk palette — and the
logo with a **magnifying glass** (the app icon, reused in-app).

Source palette:

| Name | Hex | Character |
|---|---|---|
| CLOUD | `#CDD0DB` | pale lavender-grey — cool neutral base |
| AZUL | `#9197AA` | muted slate blue — calm cool grounding tone |
| MIMOSA | `#F7B557` | warm golden amber — highlights / calls-to-attention |
| ORANGE | `#E27921` | terracotta — the vibrant hero |
| APEROL | `#C1521E` | deep burnt sienna — darkest, strong contrast |

## Goals

- One brand identity, no user-chosen arbitrary accent hue.
- Two cohesive, switchable palette **options**, each fully designed for **light AND
  dark** (4 color sets total).
- No plain white / black bases — neutrals are brand-tinted.
- The whole app re-themes from a single source (root tint + injected `theme`).

## Non-goals

- Per-screen theming or high-contrast / increased-contrast variants (future).
- Animating the palette transition (instantaneous swap is fine).

## Color analysis → role mapping

Key constraint: on a **light** canvas only **ORANGE**, **APEROL**, and a **deepened
AZUL** have enough contrast to act as a foreground *primary* (tint for icons / links /
small text). MIMOSA and CLOUD are too light — they only work as *fills* with dark text
on them. That yields two genuinely distinct, faithful options:

### Option A — **Desert** (warm-led, default)
The "vibrant heart." Warm sand canvas, **ORANGE** primary, **APEROL** pressed,
**MIMOSA** secondary highlight. Energetic.

### Option B — **Dusk** (cool-led)
The "calm, blue-hour" identity. Lavender-grey (CLOUD) canvas, **deepened-AZUL slate**
primary, **MIMOSA** as the warm spark. Restful, with gold accents.

### Resolved sets (light / dark)

| Role | Desert L | Desert D | Dusk L | Dusk D |
|---|---|---|---|---|
| background | `#F3EDE4` | `#17120D` | `#E9EBF1` | `#13151B` |
| surface | `#FBF7F0` | `#211A13` | `#F4F5F9` | `#1C1F27` |
| surfaceElevated | `#FFFDF9` | `#2C241B` | `#FCFCFE` | `#252934` |
| primary | `#BA4D17` | `#EE8B3B` | `#586280` | `#97A0C2` |
| primaryPressed | `#9C3D12` | `#E27921` | `#434C66` | `#7B85AB` |
| secondary | `#F7B557` | `#F7B557` | `#F7B557` | `#F7B557` |
| onAccent | `#FFF7EC` | `#2A190B` | `#F5F6FA` | `#14161D` |
| textPrimary | `#2C2118` | `#F4ECE1` | `#21242E` | `#ECEEF5` |
| textSecondary | `#7A6657` | `#B8A693` | `#5F6678` | `#A2A8BA` |
| separator | `#E6DBCB` | `#3A3127` | `#D7DAE3` | `#2E323D` |

Dark mode is *designed*, not inverted: Desert dark is a warm near-black, Dusk dark a
cool blue-black, each with a brightened accent so the hero stays vivid.

### Accessibility (WCAG)

All four sets clear WCAG AA after a contrast review: body text ≥ 4.5:1 on its
background, the primary tint ≥ 3:1 (non-text) on background/surface, and `onAccent`
ink ≥ 4.5:1 on the primary fill. Two values were deepened for this:

- **Desert-light `primary`** `#E27921` → **`#BA4D17`**, **`primaryPressed`** `#C1521E`
  → **`#9C3D12`**. Raw ORANGE `#E27921` is a mid-luminance hue that fails both the
  3:1 tint bar (2.58:1 on the pale canvas) and AA text contrast either ink colour;
  the deepened terracotta clears 4.34:1 (tint) and 4.75:1 (`onAccent`). The vivid
  `#E27921` is retained in the app icon and as the Desert **dark** accent.
- **Dusk-light `textSecondary`** `#6B7184` → **`#5F6678`** (4.08:1 → 4.82:1).

## Architecture

- **`ThemeColors`** — a `struct` of resolved semantic roles. Each role is a dynamic
  `Color(light:dark:)`, so a single value renders in both appearances; only the
  *option* varies at runtime.
- **`AppPalette`** (`.desert` / `.dusk`) — owns the two resolved `ThemeColors` tables,
  the picker swatch, and localized title/subtitle.
- **`EnvironmentValues.theme`** (`@Entry`, defaults to Desert) — injected once at the
  app root from `ThemeSettings.palette.colors`. Read with `@Environment(\.theme)`.
- **`ThemeSettings`** — persists `appearance` (system/light/dark) and `palette` to
  `UserDefaults` (`theme.appearance`, `theme.palette`).
- The root applies `.tint(palette.colors.primary)`, so every `Color.accentColor` /
  `.tint` call site across the app follows the option automatically — most of the app
  needed no edits.

The old static `Color.app…` tokens and `AppAccentColor` enum are removed (they could
not reflect a runtime option choice and would silently drift).

## Brand mark / app icon

`BrandMark` + `Scripts/GenerateAppIcon.swift` now render a **white magnifying glass**
on the Traveler gradient (APEROL → ORANGE → MIMOSA → teal `#5197AA`, top-left →
bottom-right). Geometry mirrors the source SVG (120pt viewBox): lens centre (55, 53),
radius 25; handle (66, 64) → (87, 87); strokes 9pt; tile corner 27. The icon is
full-bleed + opaque (iOS masks the corners); the in-app mark is a rounded gradient tile.

Regenerate the icon after geometry/color changes:

```bash
swift Scripts/GenerateAppIcon.swift \
  cue/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Alternatives considered

- **Custom `UITraitDefinition` for the palette** (keep static `Color.app…` tokens that
  switch on a custom trait): rejected — SwiftUI does not propagate app-defined UIKit
  traits into the rendering `UITraitCollection`, so it would not switch live in a pure
  SwiftUI tree. Environment injection is the idiomatic path.
- **Asset-catalog color sets per option**: rejected — asset catalogs switch on
  light/dark/contrast only, not an arbitrary runtime option.
- **MIMOSA or CLOUD as a primary**: rejected on contrast (fail as foreground tints on
  light canvases); MIMOSA is kept as `secondary` (a fill with dark text).
