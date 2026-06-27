# Design tokens & the "Kraft & Ink" theme

- **Status**: Implemented (foundation) · screen migration in progress
- **Last updated**: 2026-06-19
- **Owner**: Danil
- **Related ADRs**: [0003 — design-token-system](../adr/0003-design-token-system.md)
- **Supersedes**: [theme-traveler-palette](theme-traveler-palette.md)

## Context

Theme changes are a recurring activity in Cue, so styling must be a one-place edit. Color already worked that way (`ThemeColors` via `@Environment(\.theme)`), but type, spacing, radius, and depth were scattered magic numbers, and ~13 files leaked hardcoded system colors. This spec defines the token layer that closes that gap and the **Kraft & Ink** identity built on it. See [ADR 0003](../adr/0003-design-token-system.md) for the decision and rejected alternatives.

> **Mental model (for a React engineer):** `ThemeColors` is the theme context value; `Spacing`/`Radius`/`Typography`/`Depth` are the rest of the `theme` object (`theme.space`, `theme.radii`, `theme.fonts`); the `Cue*` components are the design-system primitives (`<Card>`, `<Button>`). Screens import these, never raw values.

## Goals

- Changing any styling axis (color, type, spacing, radius, depth) is a single-file edit.
- Every screen is assembled from a small set of reusable primitives.
- The result looks human-made and bespoke, never generic — by encoding that at the token level.
- New code can't silently reintroduce hardcoded style (grep guardrail).

## Non-goals

- Dark mode (deferred; the app pins `.light` — the layer is ready for it).
- A user-facing palette picker (single palette by decision; the `AppPalette` enum stays for future).
- Re-theming the iOS 26 Liquid Glass system chrome's material (we set its tint, not its blur).

## The token layers

All under `cue/DesignSystem/` — `Tokens/` for the axes, `Components/` for the primitives.

### Color — `ThemeColors` (Theme.swift)

Injected once in `cueApp.swift` (`.environment(\.theme, …)` + `.tint(primary)`); read with `@Environment(\.theme) private var theme`.

| Role | Kraft & Ink | Use |
|---|---|---|
| `background` | `#F2E8D8` kraft | app canvas |
| `surface` | `#FBF5EA` sheet | cards, rows |
| `surfaceElevated` | `#FEFBF3` | top sheets/modals |
| `surfaceSunken` | `#EADBC4` tray | recessed strips, zebra |
| `primary` / `primaryPressed` | `#5A3A24` / `#43291A` espresso | hero, tint, buttons |
| `secondary` | `#BE4A28` clay | the rationed accent — seal/CTA/thin marks (a **fill**) |
| `accentText` | `#A53D22` | the only clay allowed as **text**/thin rules |
| `onAccent` | `#FBF5EA` cream | text on a primary/secondary fill |
| `textPrimary` / `textSecondary` | `#2E211A` / `#6E5C4C` | body / supporting |
| `separator` | `#D8C4A6` | decorative hairlines only |
| `border` | `#8C7142` | functional edges (inputs, card outlines) |
| `success` / `warning` / `danger` / `info` | `#466234` olive / `#C9A24B` brass / `#A8331F` brick / `#5A3A24` | semantic |

**Accessibility gates (measured):** ink on kraft ≈ 12.8:1; espresso on kraft ≈ 8.4:1; muted on kraft ≈ 5.3:1; cream on clay ≈ 5.0:1 (AA). **`secondary` (clay) and `warning` (brass) are fills** — clay-as-text uses `accentText`; brass-as-text is forbidden (fails contrast).

### Spacing — `Spacing` (4pt grid)

`xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32 · huge 48`. Usage: `VStack(spacing: Spacing.md)`, `.padding(.horizontal, Spacing.lg)`.

### Radius — `Radius`

`none 0 · tight 2 · small 6 (default) · medium 8 · large 12`. Kraft & Ink standardizes on `small` (cut-paper); true pills use `Capsule()`.

### Typography — `TextRole` + `.cueText(_:)`

Three voices: **Fraunces** (`displayL/displayM/titleL/titleM/headline`), **SF Pro** (`body/bodyEmphasis/callout/label/caption`), **SF Mono** (`code/codeSmall`). Scales with Dynamic Type (`relativeTo:`). Usage: `Text("Today").cueText(.titleL).foregroundStyle(theme.textPrimary)`. Fraunces is bundled (`Resources/Fonts/Fraunces.ttf`, registered in `Config/Info.plist` `UIAppFonts`); swap the face in one place via `Typography.serifFamily`.

### Depth — `Depth` + `.cueDepth(_:)`

"Letterpress, not float." `.flat` · `.letterpress` (1pt functional border + faint warm value-cut — the card default) · `.valueCut` (crisp hard offset) · `.glass` (explicit Liquid Glass passthrough for chrome). No uniform soft drop shadows.

## Primitives (`DesignSystem/Components/`)

- **`CueCard`** — surface fill + radius + `.letterpress`. The `<Card>`.
- **`CueButton`** via `.buttonStyle(.cue(.primary/.secondary/.destructive/.ghost))` — espresso / bordered / brick / clay-text.
- **`CueChip`** — one selectable pill (selected = espresso fill + cream; unselected = surface + border). Unifies the former duration/weekday/option chips.
- **`CueEventCard`** — the single event-card look shared by the timeline + list day modes.
- **`CueAvatar`** — circle image/initials + warm border.
- **`WaxSeal`** / `WaxSealShape` — the signature: an irregular Canvas-drawn clay seal (never a clean circle), springing in on commit. Reserved for completing a task and saving a new event.

## Edge cases

- **Dynamic Type**: serif roles use `relativeTo:`; verify large accessibility sizes don't clip.
- **`Canvas` color**: mini-month grids and the brand mark resolve theme colors *outside* the draw closure and pass them in (Canvas can't read `@Environment`).
- **Calendar perf**: `MonthDayCell` is rendered constantly on scroll — single theme read, keep cells `Equatable`, keep layout constants static (not token lookups).
- **VoiceOver / reduced motion**: the wax-seal animation respects `prefers-reduced-motion`.

## Avoid (the guardrail)

Never in feature code: `.system(size:)` fonts (use `TextRole`); raw `Color.red/.blue/.orange/.black` (use roles); raw `cornerRadius` literals (use `Radius`); uniform soft drop shadows (use `Depth`); clay/brass as small text; blue/purple/gradients; squircle bubbles. A grep lint flags these in `Features/`.

## Rollout

Foundation shipped (tokens, primitives, palette, fonts, notification remap — build green). Screen migration proceeds tokenize-in-place, building after each file: shared components → calendar day surfaces → month/year (perf-careful) → forms → settings/telegram/groups → auth/loading → brand mark + icon → warm copy pass.

## Open questions

- [ ] When does dark mode ship? (designed warm-dark table, role by role.)
- [ ] Promote `Spacing`/`Radius`/`Typography`/`Depth` into a SwiftPM `DesignSystem` target once it stabilizes?

## References

- [ADR 0003](../adr/0003-design-token-system.md) · [theme-traveler-palette (superseded)](theme-traveler-palette.md)
- Kraft & Ink starter pack: `~/personal-projects/letssign-design-starter/` (origin of the palette).
