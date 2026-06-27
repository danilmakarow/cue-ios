# CUE — "Kraft & Ink" Design System (shared spec for every Claude Design prompt)

> **Single source of truth for visuals.** Every per-screen Claude Design prompt in this project
> MUST reference this system by name and use these tokens ONLY. The values below are extracted
> **verbatim from the implemented iOS app** (`/Users/danil/personal-projects/cue-ios/cue/DesignSystem/`),
> not from the (stale) `docs/specs/design-tokens.md`. Where code and any spec doc disagreed,
> **the code won**. Do not introduce new colors, fonts, gradients, or pure white/black surfaces.

**Identity in one line:** espresso ink on a clean white page, with one rationed terracotta
"wax seal" accent. Crisp cut-paper edges, letterpress depth (border + value-step, never soft
float). Light-only. Four token axes — Color, Typography, Spacing, Radius — plus Depth as the
elevation token. The wax seal is the brand's gesture: "make it stick."

---

## 0. READY-TO-PASTE DESIGN-SYSTEM BLOCK FOR CLAUDE DESIGN

Paste this block once when creating/seeding the Claude Design system for the CUE project (or
prepend it to any screen prompt as the system contract). It is authored in the canonical
`DESIGN.md` 9-section structure so the agent self-corrects on uncovered cases. CSS variables
mirror the Swift tokens 1:1.

```markdown
# CUE "Kraft & Ink" — DESIGN.md

## 1. Visual Theme & Atmosphere
Editorial, warm, paper-first. Espresso-brown ink on a clean white page. One rationed terracotta
"wax seal" accent — used at most ONCE per screen for the single most important commit moment.
Letterpress depth: a 1px functional border + a hard 1–2px value-cut offset, NEVER a soft blurred
drop shadow. Crisp "cut-paper" corners (4–12px), never 16–20px squircle bubbles. Light mode ONLY.
Mood: a typesetter's notebook, not a SaaS dashboard. No gradients, no glassmorphism on content,
no purple, no neon, no bento grids, no pure #FFFFFF cards floating on white, no pure #000000.

## 2. Color Palette & Roles (CSS variables — opaque sRGB, mirror of Swift `ThemeColors`)
--background:        #FFFFFF; /* app canvas behind everything */
--surface:           #FAF6EF; /* cards, rows — faint warm paper */
--surface-elevated:  #FEFCF8; /* top sheets / modals / elevated surfaces */
--surface-sunken:    #F1EADF; /* recessed strips (header bands), table zebra */
--primary:           #5A3A24; /* espresso hero — key actions, the structural tint */
--primary-pressed:   #43291A; /* pressed state of primary */
--secondary:         #BE4A28; /* rationed clay accent — FILL ONLY (CTA fills, wax seal, TODAY) */
--accent-text:       #A53D22; /* the ONLY clay allowed as TEXT / icons / thin rules (AA-safe) */
--on-accent:         #FBF5EA; /* cream ink placed on a primary/secondary fill */
--text-primary:      #2E211A; /* body + headings (near-black warm) */
--text-secondary:    #6E5C4C; /* supporting / muted text */
--separator:         #D0BA98; /* DECORATIVE hairlines ONLY (faint ~1.88:1, never a real edge) */
--border:            #8C7142; /* FUNCTIONAL edges a user must locate (inputs, card outlines) */
--success:           #466234; /* olive — completed / agreed states */
--warning:           #C9A24B; /* brass — pending / draft. FILL ONLY; place INK on it, never cream */
--danger:            #A8331F; /* brick — destructive */
--info:              #5A3A24; /* espresso (same hex as primary) — structural/info */
/* RULE: --secondary (terracotta) is the one-hot moment — the TODAY/now marker and the wax seal
   and the single decisive CTA. NEVER use it for multiple chips or as decoration. Olive=done,
   brass=pending, espresso=structure. Color presence, not a rainbow. */
/* RULE: clay as TEXT must use --accent-text (#A53D22). The fill clay (#BE4A28) is ~3.6:1 — FILL ONLY. */
/* RULE: selected chips/toggles fill with --primary (espresso), NOT clay, so they never compete
   with the seal / decisive CTA. */

## 3. Typography (3 bundled families; substitute via Google Fonts in web preview)
Display/headings: "Fraunces" (bundled in app). Web fallback: Google Font "Fraunces".
Body/labels:      "Public Sans" (bundled — explicitly NOT Inter/SF Pro). Web fallback: "Public Sans".
Code/receipts:    "JetBrains Mono" (bundled). Web fallback: "JetBrains Mono".
Type ramp (pt = px in preview; tracking in px; weights as noted):
  display-L  Fraunces 34 semibold, tracking -0.4  — screen hero, app name
  display-M  Fraunces 27 semibold, tracking -0.4  — secondary hero
  title-L    Fraunces 22 medium,   tracking -0.2  — section title
  title-M    Fraunces 18 medium,   tracking -0.2  — card / row title
  headline   Fraunces 17 medium                   — emphasised lead line
  body       Public Sans 16 regular               — default body copy
  body-emph  Public Sans 16 semibold              — emphasised body; BUTTON LABELS
  callout    Public Sans 15 regular               — supporting copy
  label      Public Sans 13 medium, tracking 0.3  — field labels / eyebrows; CHIP TEXT
  caption    Public Sans 12 regular               — captions, footnotes
  code       JetBrains Mono 13 regular, tracking 0.2 — IDs, dates, amounts, stamps, eyebrows
  code-small JetBrains Mono 11 medium, tracking 0.8 — micro-labels
RULE: Fraunces is the editorial voice — use it for titles >=17pt; NEVER for dense UI labels/body.
RULE: receipt-voice (dates, counts, times, IDs) uses JetBrains Mono. Display reads tighter
(negative tracking); receipts read wider (positive tracking).

## 4. Component Stylings
Buttons: full-width, radius 6px, vertical padding 12 / horizontal 16, label = body-emph.
  Press = 1px DOWNWARD offset (letterpress depress) — no scale, no glow, no shadow. 160ms ease-out.
  .primary = --primary fill, --on-accent label. .decisive = --secondary fill (the ONE hot CTA,
  <=1 per screen). .secondary = clear fill + 1px --border + --primary label. .destructive =
  --danger fill + cream. .ghost = clear + --accent-text label.
Cards: fill --surface, radius 10px, depth = letterpress (1px --border overlay + hard value-cut
  shadow y:1 at --text-primary 6% opacity, blur radius 0). Optional header = --surface-sunken strip
  with a 1px --separator bottom rule.
Chips: 4px "rubber-stamp" rectangle, NEVER a pill, NEVER a pill-with-a-dot. Selection by fill+ink,
  no indicator dot. Unselected = --surface fill + --text-secondary + 1px --border. Selected =
  --primary (espresso) fill + --on-accent text + no border. Text = label role.
Avatar: circle, always ringed by a 1.5px --primary stroke; placeholder = --surface-sunken +
  person.fill glyph in --text-secondary.
Wax seal (signature mark): an irregular hand-pressed blob (NOT a clean circle), ~16 vertices with
  fixed jitter. Unstamped = dashed empty "seal-well" (1.5px --border, dash 4/4, 90% opacity).
  Stamped = --secondary clay fill + --primary-pressed 40% rim stroke (multiply) + centered cream
  glyph. Reserved for the TWO commit moments: completing a task + saving a new event. Also the
  app logo (BrandMark: clay seal + cream Fraunces "C").
Notification banner: INTENTIONALLY Liquid Glass (frosted), radius 8px, 4px severity rail + icon +
  title (body-emph) + message (callout). Severity→role: info=--info, success=--success,
  warning=--warning, error=--danger.

## 5. Layout Principles (4pt spacing grid)
--space-xxs:2  --space-xs:4  --space-sm:8  --space-md:12  --space-lg:16 (default gap / card inner)
--space-xl:20  --space-xxl:24 (between cards) --space-xxxl:32 --space-huge:48 (hero/empty-state)
16px side margins on phone. Generous whitespace; let the paper breathe.

## 6. Depth & Elevation ("letterpress, not float")
NO soft uniform drop shadows anywhere. Two and only two shadow treatments, both blur-radius 0:
  letterpress = 1px --border + shadow(--text-primary 6%, y:1)  — card default.
  value-cut   = 1px --border + shadow(--text-primary 12%, y:2) — crisp stacked-paper offset.
System Liquid Glass (frosted) is used ONLY for chrome: tab bar, nav bar, floating Today pill,
notification banner. Re-tint the glass WARM toward the kraft/clay palette — never Apple's default
cool blue-grey.

## 7. Do's & Don'ts
DO use the white page as canvas; cards are faint warm paper (--surface), not whiter than the page.
DO ration the clay --secondary: one wax-seal / one decisive CTA / the TODAY marker per screen.
DO use real data — real task titles, real dates, real EN/UK strings — never "Task 1" / lorem.
DO encode density/busyness as intensity ramps of ONE accent (clay or espresso), not a rainbow.
DO use letterpress depth (border + hard value-cut), and crisp 4–12px corners.
DON'T introduce pure #FFFFFF surfaces-on-white, pure #000000, blue accents, gradients, or
  glassmorphism on content cards.
DON'T let Inter/Helvetica/SF Pro be the display face — pin Fraunces.
DON'T make the chip a pill; DON'T multiply the accent; DON'T add soft blurred drop shadows.
DON'T say "modern/clean/sleek/beautiful" — those summon the generic AI aesthetic.

## 8. Responsive Behavior
SINGLE FIXED iPhone frame, 393×852pt @3x. NOT responsive — this is a native iOS screen, not a web
page. iOS status bar (time + battery), Dynamic Island reserved, top safe area ~59pt, 34pt
home-indicator gutter. Floating Liquid-Glass tab bar inset ~21pt from sides/bottom. All tap targets
>=44pt. Text scales with Dynamic Type (use relative type styles, never fixed sizes in app).

## 9. Agent Prompt Guide
Reference tokens by NAME (--surface, --wax-seal=--secondary, Fraunces) — never raw hex — so the
palette can't drift. Reference components by NAME (CueButton .decisive, CueCard, CueChip, WaxSeal).
Generate one screen at a time, then "apply across the flow" for consistency. Fix details via
inline comments, not full regenerations (regen drifts to defaults). Always show the empty/loading/
error variant the screen needs. The wax seal appears at most once per screen, on the primary commit.
```

---

## 1. Color tokens (EXACT — from `Theme.swift` `kraftInkColors`)

Every value is opaque sRGB `Color(hex: 0x…)`. Feature code reads semantic roles from
`@Environment(\.theme)`, never hex.

| Role | Hex | Use / rule |
|---|---|---|
| `background` | `#FFFFFF` | app canvas behind everything |
| `surface` | `#FAF6EF` | cards, rows (faint warm paper) |
| `surfaceElevated` | `#FEFCF8` | top sheets / modals / elevated surfaces |
| `surfaceSunken` | `#F1EADF` | recessed strips (header bands), table zebra |
| `primary` | `#5A3A24` | espresso hero — key actions, the structural tint |
| `primaryPressed` | `#43291A` | pressed state of primary |
| `secondary` | `#BE4A28` | rationed clay accent — **FILL ONLY** (CTA fills, wax seal, TODAY marker) |
| `accentText` | `#A53D22` | the ONLY clay allowed as **text** / icons / thin rules (deepened, AA-safe) |
| `onAccent` | `#FBF5EA` | cream ink on a `primary`/`secondary` fill |
| `textPrimary` | `#2E211A` | body + headings |
| `textSecondary` | `#6E5C4C` | supporting / muted text |
| `separator` | `#D0BA98` | **decorative hairlines ONLY** (~1.88:1 on white) |
| `border` | `#8C7142` | **functional edges** a user must locate (inputs, card outlines) |
| `success` | `#466234` | olive — completed / agreed |
| `warning` | `#C9A24B` | brass — pending / draft (**FILL ONLY**; place INK on it, never cream) |
| `danger` | `#A8331F` | brick — destructive |
| `info` | `#5A3A24` | espresso (same hex as `primary`) — structural/info |
| `accent` (computed) | = `primary` | alias mirroring `Color.accentColor`; `AccentColor.colorset` = `#5A3A24` |

**Raw palette anchors** (header names, for reference): PAGE `#FFFFFF`, SHEET `#FAF6EF`,
RISER `#FEFCF8`, TRAY `#F1EADF`, ESPRESSO `#5A3A24`, INK `#2E211A`, CLAY `#BE4A28`,
OLIVE `#466234`, BRICK `#A8331F`, BRASS `#C9A24B`.

**"More-accent" discipline (hard rule):** terracotta `secondary` is the one-hot moment — the
calendar TODAY/now marker, the wax seal, the single decisive CTA. Olive `success` = completed;
brass `warning` = pending/draft; espresso `primary` stays structural. Color presence, not a rainbow.

**Accessibility (measured in-code, WCAG 2.1, lowest figure on `surfaceSunken`):**
- ink `#2E211A` text: 13.03–15.57:1 — **AAA**
- muted `#6E5C4C` text: 5.33–6.37:1 — **AA**
- espresso `#5A3A24` (primary/info) text: 8.51–10.17:1 — **AAA**
- clay-as-text `accentText #A53D22`: 5.34–6.38:1 — **AA** (seal fill `secondary #BE4A28` ≈ 3.6:1 → **FILL ONLY**)
- olive `#466234` text: 5.75–6.87:1 — **AA**; brick `#A8331F` text: 5.56–6.65:1 — **AA**
- cream `onAccent #FBF5EA`: on primary 9.37:1 · on primaryPressed 12.32 · on seal `#BE4A28` 4.61 (AA) · on success 6.33 · on danger 6.13
- `border #8C7142`: 3.86–4.61:1 (clears 3:1 non-text minimum); `separator #D0BA98`: ~1.58–1.88:1 (faint ornament, never an edge)
- brass `warning #C9A24B`: ink on it ≈ 6.49:1; cream on it ≈ 2.21:1 → **place INK only**

**Light-only:** the app pins `.light` at root. Dark machinery exists (`Color(light:dark:)`,
`AppearanceMode`, `AppPalette.kraftInk`) but is unused. When dark ships, swap the table to
`Color(light:dark:)` pairs — nothing else changes.

**Color utilities:** `Color(hex: UInt32)` packed `0xRRGGBB` opaque · `Color(hex: String)?` CSS
`#RRGGBB` returning nil on malformed (used for backend-supplied group/calendar colors) ·
`Color(light:dark:)` (currently unused).

**Legacy — DO NOT USE:** `TravelerColor` (cloud `#CDD0DB`, azul `#9197AA`, mimosa `#F7B557`,
orange `#E27921`, aperol `#C1521E`) is retained only for `BrandMark` history. Kraft & Ink replaced
the old "Traveler" Desert/Dusk options.

---

## 2. Typography (EXACT — from `Tokens/Typography.swift`)

Three bundled families, registered in `Config/Info.plist` `UIAppFonts`:

| Voice | Family constant | Actual font | Job |
|---|---|---|---|
| Display / headings | `serifFamily = "Fraunces"` | Fraunces (Regular/Medium/SemiBold) | the human "typeset" voice |
| Body / labels | `bodyFamily = "Public Sans"` | Public Sans — **NOT Inter/SF Pro** | plain-spoken, legible (Cyrillic via per-glyph system fallback) |
| Code / receipts | `monoFamily = "JetBrains Mono"` | JetBrains Mono | IDs, dates, amounts, stamps, eyebrows (full Cyrillic) |

Bundled `.ttf` in `cue/Resources/Fonts/`: Fraunces-Regular/Medium/SemiBold, PublicSans-Regular/
Medium/SemiBold, JetBrainsMono-Regular/Medium.

### The full type ramp — `TextRole` (applied via `.cueText(.role)`)
Sizes are points; all scale with Dynamic Type via `relativeTo:`. No explicit line-heights — line
height is the font/Dynamic-Type default per `Font.TextStyle`. Color stays separate (`.foregroundStyle`).

| Role | Family | Size pt | Weight | `relativeTo` | Tracking pt | Used for |
|---|---|---|---|---|---|---|
| `displayL` | Fraunces | 34 | semibold | `.largeTitle` | −0.4 | screen hero, app name |
| `displayM` | Fraunces | 27 | semibold | `.title` | −0.4 | secondary hero |
| `titleL` | Fraunces | 22 | medium | `.title2` | −0.2 | section title |
| `titleM` | Fraunces | 18 | medium | `.title3` | −0.2 | card / row title |
| `headline` | Fraunces | 17 | medium | `.headline` | 0 | emphasised lead line |
| `body` | Public Sans | 16 | regular | `.body` | 0 | default body copy |
| `bodyEmphasis` | Public Sans | 16 | semibold | `.body` | 0 | emphasised body; **button labels** |
| `callout` | Public Sans | 15 | regular | `.callout` | 0 | supporting copy |
| `label` | Public Sans | 13 | medium | `.footnote` | 0.3 | field labels / eyebrows; **chip text** |
| `caption` | Public Sans | 12 | regular | `.caption` | 0 | captions, footnotes |
| `code` | JetBrains Mono | 13 | regular | `.footnote` | 0.2 | receipt voice — IDs, dates, amounts, stamps |
| `codeSmall` | JetBrains Mono | 11 | medium | `.caption2` | 0.8 | micro-labels |

Tracking rule: display reads tighter (negative), receipts read wider (positive).

**UIKit projection (`CalendarTheme`):** rebuilds the same colors as `UIColor` and the same 12 type
roles as `UIFont`, scaled with `UIFontMetrics`. Mapping: SwiftUI `displayM relativeTo .title` →
UIKit `.title1`; `caption relativeTo .caption` → UIKit `.caption1`.

---

## 3. Spacing scale (EXACT — `Tokens/Spacing.swift`, 4pt grid)

| Token | pt | Use |
|---|---|---|
| `xxs` | 2 | hairline gaps (glyph hugging label) |
| `xs` | 4 | very tight inline gaps |
| `sm` | 8 | within-control padding, chip insets |
| `md` | 12 | label-to-field, compact stacks |
| `lg` | 16 | **default gap**; card inner padding |
| `xl` | 20 | between fields, roomy card padding |
| `xxl` | 24 | between cards, section padding |
| `xxxl` | 32 | between major sections |
| `huge` | 48 | hero / empty-state breathing room |

(UIKit `CalendarTheme` exposes a subset: `spacingXS 4, spacingSM 8, spacingMD 12, spacingLG 16, spacingXL 20`.)

---

## 4. Radius scale (EXACT — `Tokens/Radius.swift`)

Philosophy: crisp "cut paper" edges — NO 16–20pt squircle bubbles. Depth comes from border +
value-step. Capsules reserved for genuinely segmented toggles only.

| Token | pt | Use |
|---|---|---|
| `none` | 0 | square hairline-bordered edges |
| `tight` | 2 | barely-rounded micro-controls |
| `chip` | 4 | chips — hard "rubber-stamp" corner, never a pill (one step tighter than buttons) |
| `small` | 6 | **default** "cut paper" radius — buttons, fields, overlays |
| `medium` | 8 | softer containers — icon tiles, grouped rows, notification banner |
| `card` | 10 | cards — crisp cut sheet, not a bubble |
| `large` | 12 | large surfaces — sheets, prominent cards |

(UIKit `CalendarTheme`: `radiusSmall 6, radiusMedium 8, radiusLarge 12`; calendar-only metrics
`hourHeight 36`, `timelineTopPadding 10`.)

---

## 5. Depth / elevation (EXACT — `Tokens/Depth.swift`)

Rule: **"letterpress, not float."** Depth = value-step + functional border, NOT soft drop shadows.
Applied via `.cueDepth(_:radius:)` (default `radius = 6`). Shadows use **blur radius 0** (hard offset).

| `Depth` case | Treatment (exact) |
|---|---|
| `.flat` | no elevation |
| `.letterpress` | **card default.** 1pt `strokeBorder(border)` + `shadow(textPrimary 0.06, radius:0, y:1)` — faint warm value-cut beneath |
| `.valueCut` | 1pt `strokeBorder(border)` + `shadow(textPrimary 0.12, radius:0, y:2)` — crisp stacked-paper offset, no blur |
| `.glass` | system Liquid Glass: `.glassEffect(.regular, in: .rect(cornerRadius: radius))` — chrome only |

**No soft uniform drop shadows anywhere by design.** Only the two hard `radius: 0` value-cuts.

---

## 6. Components — public API + visual behavior

### CueButton — `.buttonStyle(.cue(_ variant:))`
Label `.cueText(.bodyEmphasis)`, full-width, padding vertical 12 / horizontal 16, radius 6
(`.continuous`). Press = **1pt downward offset** (no scale/glow/shadow). `.easeOut(0.16)`.
Disabled → opacity 0.5.

| Variant | Fill | Label | Border | Pressed |
|---|---|---|---|---|
| `.primary` | `primary` espresso | `onAccent` cream | none | fill → `primaryPressed` |
| `.decisive` | `secondary` clay seal | `onAccent` cream | none | `primaryPressed` multiply overlay @0.22 ("ink soaking in"). **The ONE rationed hot CTA, ≤ once per screen** |
| `.secondary` | clear | `primary` espresso | 1pt `border` | fill → `surfaceSunken` |
| `.destructive` | `danger` brick | `onAccent` cream | none | opacity → 0.85 |
| `.ghost` | clear | `accentText` clay | none | opacity → 0.6 |

### CueCard — `CueCard<Header, Content>`
`init(padding: 16, radius: 10, depth: .letterpress, background: nil, header:, content:)`. Fill =
`background ?? surface`, clipped to radius (`.continuous`), then `.cueDepth`. Optional `header`
renders a `surfaceSunken` strip (vertical padding 12) with a 1pt `separator` bottom rule.

### CueChip — `CueChip(_ title:, systemImage:?, isSelected:, action:)`
4pt "rubber-stamp" rectangle (never a pill, never pill-with-dot). Selection by **fill + ink**, no
dot. Text `.cueText(.label)`, optional leading SF Symbol. Padding vertical 8 / horizontal 12.
`.easeOut(0.16)`.
- **Unselected:** `surface` fill, `textSecondary` text, 1pt `border`.
- **Selected:** `primary` (espresso — deliberately NOT clay, so it never competes with the seal),
  `onAccent` text, no border.

### CueAvatar — `CueAvatar(image:?, size: 56)`
Circular, `.scaledToFill` clipped; placeholder = `surfaceSunken` + `person.fill`
(`textSecondary`, `size*0.42`). Always ringed by a **1.5pt `primary`** stroke circle.

### WaxSeal / WaxSealShape — the signature mark
`WaxSeal(isStamped:, size: 56, systemImage: "checkmark")`.
- `WaxSealShape` = deterministic irregular blob (16 vertices, fixed ±~5% jitter, quad-curve
  smoothed). **No per-frame randomness** — hand-pressed wax, not a clean circle.
- **Unstamped:** dashed "seal-well" — `WaxSealShape().stroke(border, lineWidth: 1.5, dash: [4,4])` @0.9.
- **Stamped:** `secondary` clay fill + `primaryPressed.opacity(0.4)` 1.5pt stroke `.multiply` +
  centered SF Symbol (`size*0.38`, semibold, `onAccent` cream).
- **Animation:** `.spring(response: 0.42, dampingFraction: 0.62)` — scale 0.4→1, opacity 0→1,
  rotation −8°→0°. `.accessibilityHidden(true)`.
- **Usage (rationed):** the app's TWO commit moments — completing a task, saving a new event.

### BrandMark — `BrandMark(size:, style: .tinted)`
The logo = a clay wax seal with a cream Fraunces "C" monogram (same `WaxSealShape`). **Brand colors
fixed across themes** (the one sanctioned brand literal): clay `#BE4A28`, clayRim `#8A2F18`,
cream `#FBF5EA`. `.tinted` = clay fill + rim + inner cream ring @0.74 scale + cream monogram.
`.monochrome(Color)` = outline + monogram in one color. Monogram = Fraunces "C" at `size*0.46`
semibold.

### ErrorStateView — `ErrorStateView(title:, message:, systemImage: "wifi.exclamationmark", retry:?)`
Full-page error on `ContentUnavailableView`. Retry shown only when `retry != nil`. Convenience
`.networkFailure(retry:)`. **FLAG:** uses system `.borderedProminent`, not `CueButton` — a known DS
gap. For whole-screen first-load failures; transient failures go to `NotificationStore` banners.

### LoadingStateView (+ siblings)
- `LoadingStateView(label:?)` — centered `ProgressView().controlSize(.large).tint(primary)` +
  optional `.cueText(.callout)` in `textSecondary`.
- `InlineLoadingRow(label:)` — small spinner + `.cueText(.caption)` for list footers/pagination.
- `.loadingOverlay(_ isLoading:, label:?)` — **warm-ink scrim** `textPrimary.opacity(0.08)` (not
  black) + glass-backed spinner (`.glassEffect(.regular, in: .rect(cornerRadius: 20))`). `.snappy`.

### NotificationBanner — `NotificationBanner(notification:, isExpanded:, onToggleExpand:, onDismiss:)`
Radius 8. **INTENTIONALLY Liquid Glass** (`.glassEffect(.regular, in: .rect(cornerRadius: 8))`) —
chrome, distinct from letterpress cards. Leading 4pt `Capsule` severity rail + icon + title/message
column + close. Title `.bodyEmphasis`/`textPrimary`; message `.callout`/`textSecondary`; detail
`.code`/`textSecondary`. Expand affordance uses `accentText` (sanctioned clay-as-text). Border =
`severityColor.opacity(0.3)`.

| Severity | Icon | Color role |
|---|---|---|
| `.info` | `info.circle.fill` | `info` (espresso) |
| `.success` | `checkmark.circle.fill` | `success` (olive) |
| `.warning` | `exclamationmark.triangle.fill` | `warning` (brass) |
| `.error` | `xmark.octagon.fill` | `danger` (brick) |

`AppNotification`: `.info`/`.success` default auto-dismiss (4s); `.warning`/`.error` permanent;
expandable iff `detail != nil`.

---

## 7. Motion / animation (already defined)

| Where | Curve | Detail |
|---|---|---|
| CueButton press | `.easeOut(0.16)` | 1pt letterpress depress (offset y) |
| CueChip selection | `.easeOut(0.16)` | fill/ink swap |
| WaxSeal stamp | `.spring(0.42, 0.62)` | scale 0.4→1, opacity 0→1, rotation −8°→0° |
| NotificationBanner expand | `.snappy` | detail reveal + chevron rotate 0↔180° |
| loadingOverlay | `.snappy` (+ `.opacity`) | show/hide blocking spinner |
| Calendar pinch cross-zoom | spring settle 0.32, damping 0.9 | scale + smoothstep cross-fade, anchored |
| Week-strip pill | spring 0.28, damping 0.86 | per-frame pill + offset tracking from pager offset |
| Jump-to-Today pill | spring, damping 0.8 | fade + scale show/hide |
| ViewModeSwitcher | `.snappy` | capsule slide on timeline/list toggle |

The **160ms ease-out** and the **single seal spring** are the two recurring signatures.

---

## 8. Known discrepancies (code is authoritative)

1. **Canvas color:** spec doc says kraft-tan `#F2E8D8`; **implemented is WHITE** (`#FFFFFF`). Use code.
2. **Fonts:** doc says SF Pro / SF Mono; **code bundles Public Sans / JetBrains Mono** (2026-06-21). Use code.
3. **Radius:** doc omits `chip 4` and `card 10`; both exist in code. Use code.
4. **`info` == `primary`** (`#5A3A24`) — intentional, not independently tunable today.
5. **ErrorStateView** uses system `.borderedProminent`, not `CueButton` — a DS gap.
6. **Reduced-motion:** `WaxSeal.swift` applies the spring unconditionally — `prefers-reduced-motion`
   honoring is aspirational; **specify a cross-fade fallback** in any prompt that relies on it.
7. **Line heights** are not explicit tokens — derive from `Font.TextStyle` defaults if needed.

**Source files (all absolute):**
`/Users/danil/personal-projects/cue-ios/cue/DesignSystem/Theme.swift` ·
`…/DesignSystem/Tokens/{Typography,Spacing,Radius,Depth}.swift` ·
`…/DesignSystem/Components/{CueButton,CueCard,CueChip,CueAvatar,WaxSeal,ErrorStateView,LoadingStateView}.swift` ·
`…/DesignSystem/{BrandMark,AppNavigation}.swift` ·
`…/DesignSystem/Notifications/{AppNotification,NotificationBanner}.swift` ·
`…/Features/Calendar/UIKit/CalendarTheme.swift` (UIKit projection) ·
`…/Resources/Fonts/` (.ttf) · `…/Config/Info.plist` (`UIAppFonts`).
