# 0003 — design-token-system

- **Status**: Accepted
- **Date**: 2026-06-19
- **Deciders**: Danil

## Context

Cue's color system was already mature: a semantic `ThemeColors` struct injected once at the root via `@Environment(\.theme)` and read in the leaves (the SwiftUI equivalent of a single React `ThemeProvider` + `useContext`). Swapping the palette re-themed the whole tree.

Color was the *only* mature axis, though. An audit (2026-06-19) found:

- **No typography, spacing, radius, or depth tokens.** ~8 raw `.system(size:)` font calls, ~15 distinct hardcoded padding/spacing literals, 8 distinct corner-radius literals, and depth expressed three incompatible ways (soft drop shadows / flat opacity fills / ad-hoc glass).
- **~13 feature files bypassed the color system** with hardcoded `.red`/`.blue`/`.orange`/`.black` (worst: `NotificationSeverity.tint` returning system colors).
- No reusable surface/button/chip primitives — every screen hand-rolled them.

Theme changes are an expected, recurring activity for this app, so "change the theme in one place" is a first-class requirement — not just for color, but for type, spacing, radius, and depth. Separately, the product is adopting a new visual identity, **Kraft & Ink** (a warm kraft-paper / espresso-ink / clay-wax-seal palette; see [design-tokens spec](../specs/design-tokens.md)).

## Decision

We adopt a **four-axis design-token layer consumed by a small set of reusable primitives**, and features compose exclusively from those — never raw literals:

1. **Color** — `ThemeColors` (extended with `surfaceSunken`, functional `border`, `accentText`, and `success`/`warning`/`danger`/`info`), injected via `@Environment(\.theme)`. Unchanged plumbing; new roles.
2. **Spacing** — `Spacing` (4pt-grid scale: `xs`…`huge`).
3. **Radius** — `Radius` (default `small` = 6pt "cut paper").
4. **Typography** — `TextRole` + `.cueText(_:)`, with Dynamic Type.
5. **Depth** — `Depth` + `.cueDepth(_:)` encoding "letterpress, not float".

Primitives built on the tokens: `CueCard`, `CueButton` (`.cue(.primary/.secondary/.destructive/.ghost)`), `CueChip`, `CueEventCard`, `CueAvatar`, and the `WaxSeal` signature mark.

Four product decisions ride along (recorded here so future-us can re-evaluate):

- **(a) Light-only for now.** Kraft & Ink ships light; the root pins `.light`. Dark is deferred behind the same token layer (`Color(light:dark:)` is retained for the day it ships).
- **(b) Single palette.** Kraft & Ink *replaces* the previous "Traveler" Desert/Dusk options. The `AppPalette` enum is kept (one case) so re-adding a palette later is a one-case change.
- **(c) Hybrid fonts.** Bundle **Fraunces** (serif display/headings — the bespoke, human voice); use system **SF Pro** (body) and **SF Mono** (code). Routed through `TextRole`, so any face is a one-file swap.
- **(d) Wax seal, scoped.** One irregular hand-drawn clay seal, reserved for exactly two commit moments: completing a task and saving a new event.

## Consequences

- ✅ A theme change (color, type, spacing, radius, depth) is a one-place edit.
- ✅ New screens get consistency for free by composing primitives; the "generic AI look" is designed out at the token level (named serif, rationed accent, letterpress depth, cut-paper radii).
- ✅ Enforceable with a grep guardrail (no `Color.red`/`.system(`/raw `cornerRadius` in `Features/`).
- ⚠️ One-time migration cost: ~13 color sites + ~19 screens swept onto tokens/primitives.
- ⚠️ Dark mode is deferred — a known gap, intentionally.
- ⚠️ `Canvas`/`GraphicsContext` (mini-month grids, brand mark) can't read `@Environment`; theme colors must be resolved outside and passed in.
- ⚠️ The calendar's hot path (`MonthDayCell`) is perf-sensitive; tokenization must keep a single theme read per cell and leave layout constants static.

## Alternatives considered

### Asset-catalog colors (`.xcassets`) instead of code tokens

Attractive: designer-editable, OS-native dark resolution. Lost because the existing in-code `Color(light:dark:)` table is reviewable in one file and diffable in PRs, and we'd still need code tokens for type/spacing/radius/depth — splitting the system across two homes.

### Keep ad-hoc per-screen styling

Zero upfront cost. Lost because it is the cause of the problem: inconsistency, the recurring hardcoded-color leaks, and the generic look. It also makes the *recurring* theme-change requirement expensive forever.

### Keep multiple palettes (add Kraft & Ink as a 3rd option)

Preserves user choice. Lost because it dilutes a deliberately opinionated identity ("the ONE accent") and triples the styling/QA matrix (3 palettes × light/dark). The enum is retained so this is cheap to revisit.

### Bundle all three fonts / use native substitutes only

All-custom (Fraunces + Public Sans + JetBrains Mono) maximizes fidelity but adds app size, licensing, and Dynamic-Type wiring for near-imperceptible body/mono gains. Native-only loses the bespoke serif that most fights the AI look. The hybrid captures the serif's character at minimal cost, and the token layer keeps the rest swappable.

## References

- [Design tokens & Kraft & Ink spec](../specs/design-tokens.md)
- [ADR 0001 — SwiftUI not UIKit](0001-swiftui-not-uikit.md)
- Superseded palette: [theme-traveler-palette](../specs/theme-traveler-palette.md)
- WCAG 2.1 contrast (AA 4.5:1 text / 3:1 non-text) — gating the palette.
