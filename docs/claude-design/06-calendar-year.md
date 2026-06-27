# Calendar — Year

The furthest zoom-out of CUE's calendar: an infinite vertical stack of year sections, each a 3×4 grid of mini-months washed with a single-accent busyness heat-map, so a year of load reads at a glance and a tap drops you into any month.

> **Fidelity note (read before generating).** This screen *exists* in the app as a UIKit scope (`YearScopeViewController` + `YearMiniMonthCell` + `YearLayout`), and it is **dot-free today** — the shipped year scope renders no event density ("Dot-free by design"). The **heat-map is the one deliberate delta** this prompt introduces: a Timepage-style single-accent intensity wash over each mini-month, fed by `GET /tasks/daily-counts`. Everything else (infinite year sections, large Fraunces year title + accent underline, 3-col mini-month grid, abbreviated month name, tiny day-number grid, today ring, progressive Jump-to-Today pill, tap-to-zoom-into-Month) mirrors the real code exactly. Honor that split: keep the real skeleton, add only the heat wash.

---

## Design system (Kraft & Ink)

Use the published **"Kraft & Ink"** system and these tokens ONLY. No new colors, fonts, gradients, pure `#FFFFFF` surfaces-on-white, or pure `#000000`.

**Color (opaque sRGB, by role — reference by name, never raw hex):**
- `--background #FFFFFF` — app canvas behind everything (the page).
- `--surface #FAF6EF` — cards/rows, faint warm paper (each mini-month tile rests on this).
- `--surface-sunken #F1EADF` — recessed strips / the heat-map's lowest **non-zero** step.
- `--primary #5A3A24` — espresso, the structural tint (year title ink, selected state).
- `--secondary #BE4A28` — rationed clay, **FILL ONLY**: today's marker, the year-title underline, the top of the heat ramp.
- `--accent-text #A53D22` — the ONLY clay allowed as **text/icon/thin rule** (AA-safe). The current month's name uses this.
- `--text-primary #2E211A` — body + headings (day numbers, year title).
- `--text-secondary #6E5C4C` — muted (off-month day numbers, legend caption).
- `--separator #D0BA98` — decorative hairlines only (~1.88:1; never a real edge).
- `--border #8C7142` — functional edges a user must locate (tile outline, today ring).
- `--on-accent #FBF5EA` — cream ink on a `primary`/`secondary` fill.
- Status (used only if a state needs it): `--success #466234` olive, `--warning #C9A24B` brass, `--danger #A8331F` brick.

**Heat-map ramp (single-accent intensity — this screen's signature data encoding).** Encode busyness as one ramp, NOT a rainbow. Light-only contrast is hard mode here, so the ramp must climb in *value* as well as saturation:
- **0 events (empty):** tile fill `--surface` (no wash) — an empty day reads as bare paper. Do NOT tint a zero day.
- **light (1–2):** `--surface-sunken` `#F1EADF`.
- **medium (3–4):** clay `--secondary` at ~22% over `--surface` → roughly `#EFD9CE`.
- **busy (5–6):** clay `--secondary` at ~45% → roughly `#E0AD93`.
- **packed (7+):** clay `--secondary` at ~72% → roughly `#CE6E4C`; day numbers on the two hottest steps flip to `--on-accent` cream for legibility.
Intensity is applied **per day cell** inside each mini-month (the day number sits on its own heat patch), so a month reads as a little weather map — not a single flat tint per month.

**Type (3 bundled families — Fraunces / Public Sans / JetBrains Mono; NEVER Inter/SF Pro):**
- `displayL` — Fraunces 34 semibold, tracking −0.4 — **the year title ("2026")**.
- `titleL` — Fraunces 22 medium, tracking −0.2 — only if an AX-large fallback needs a smaller year.
- `label` — Public Sans 13 medium, tracking 0.3 — **mini-month name eyebrow ("JAN", "FEB")**, legend labels, chip text.
- `caption` — Public Sans 12 regular — legend hint copy, empty-state line 2.
- `codeSmall` — JetBrains Mono 11 medium, tracking 0.8 — **the tiny day numbers in the mini-grid** and the per-step count keys ("0 · 1–2 · 3–4 · 5+").
- `code` — JetBrains Mono 13 regular, tracking 0.2 — any standalone date/count receipt.

**Spacing (4pt grid):** `xs 4` (mini-grid name→grid gap), `sm 8` (tile inner padding, today underline gap), `lg 16` (grid horizontal inset, column spacing, **default**), `xl 20` (mini-month row spacing; pill inset from left), `xxl 24` (section bottom breathing room; pill inset from bottom), and a fixed **36pt** gap between year sections.

**Radius (crisp cut-paper, NO squircle bubbles):** `chip 4` (rubber-stamp chips, heat day patches), `small 6` (default — buttons/fields), `medium 8` (mini-month tile), `card 10` (any framing card), `large 12` (sheets). The year title underline is a 2pt-tall, 44pt-wide bar at radius 1.

**Depth ("letterpress, not float" — blur radius 0, ALWAYS):**
- `letterpress` = 1pt `--border` stroke + hard `shadow(--text-primary 6%, y:1)` — the mini-month tile default.
- `value-cut` = 1pt `--border` + hard `shadow(--text-primary 12%, y:2)` — a pressed/focused tile or the legend card.
- `glass` = system Liquid Glass — **chrome only** (tab bar, nav bar, the floating Today pill, the search island). Re-tint warm toward kraft/clay, never Apple's cool blue-grey.

**Components on this screen:** `CueCard` (the legend/empty container), `CueChip` (none needed here — keep available), the **Jump-to-Today pill** (a warm Liquid-Glass island, NOT a `CueButton`). No `WaxSeal` and no `CueButton .decisive` on Year — this is a read-only navigation surface (see §4). `CueAvatar` not used.

---

## Frame & platform

- **Single fixed iPhone 393×852pt @3x. NOT responsive** — a native iOS 26 screen, not a web page.
- iOS **status bar** top (9:41, signal, battery); **Dynamic Island** reserved (centered pill ~125×37 in the top safe area — keep content clear of it). Top safe area ~59pt; **34pt home-indicator gutter** at the bottom; **16pt side margins**.
- **Nav chrome:** this is the **Calendar tab**, Year scope. Inline nav bar (warm Liquid Glass) carrying:
  - **Principal title:** a serif inline scope label — `Text` in Fraunces `titleM`, `--text-primary`, reading the centered year, e.g. **"2026"** (the big in-content `displayL` year titles are the section headers; the nav bar just echoes the centered year).
  - **Trailing actions (≤2):** a **Search** glass island (`magnifyingglass`) — search is a nav-bar icon, NOT a tab — and the **scope/Today control** (`calendar.circle`) which appears only while the centered year isn't the current year (mirrors `CalendarHostView`'s toolbar logic; the in-content pill is the primary Today affordance).
- **Bottom:** floating **3-tab warm Liquid-Glass tab bar** — **Today · Calendar · Settings** — with a **separated "+"** action capsule (opens the Create sheet over any tab). Calendar tab is active. Bar inset ~21pt from sides/bottom; scroll-to-shrink. The year grid scrolls *behind* the bar.
- **One-handed reach:** the **Jump-to-Today pill floats bottom-LEFT** (inset `xl 20` from the leading edge, `xxl 24` above the safe-area bottom) — thumb-zone, and clear of the "+" on the right. Tapping a mini-month is a calm full-grid target, not edge-pinned.
- Tap targets ≥44pt (each mini-month tile is ~104pt tall — comfortably so).

---

## Layout

Top → bottom. Real CUE content (a power user's actual year), no lorem.

The surface is an **infinite vertical scroll of year sections**. Each section = a large Fraunces year title + clay underline, then a **3-column × 4-row grid of 12 mini-months**. Between sections sits a fixed **36pt** gap. Render **2.5 year sections** so the infinite scroll reads (2026 fully, 2025 trailing in above, 2027 peeking below).

```
┌─────────────────────────────────────────────┐
│ 9:41        (   Dynamic Island   )    ▣ ⌁ ▮  │ status bar
├─────────────────────────────────────────────┤
│  2026                       ⌕   ◴            │ inline nav (glass): year · Search · Today
├─────────────────────────────────────────────┤
│                                               │
│  2026                                         │ ← displayL (Fraunces 34), --text-primary
│  ▬▬▬▬                                          │   44×2 clay (--secondary) underline
│                                               │
│  ┌────────┐  ┌────────┐  ┌────────┐           │
│  │ JAN    │  │ FEB    │  │ MAR    │           │  mini-month tile: --surface,
│  │ ·· ░░▒▒ │  │ ░ ▒▒░  │  │ ░░▒ ▓  │           │  medium radius 8, letterpress.
│  │ ▒░ ░·▒░ │  │ ▒░▒ ░░ │  │ ░▒▓▒░░ │           │  name = label (Public Sans 13),
│  │ ░·▒ ░░  │  │ ░ ▒░░· │  │ ▒░░ ▒· │           │  day grid = codeSmall (JB Mono 11),
│  │ ·░ ░    │  │ ░░·    │  │ ░ ▒    │           │  each day on its own heat patch.
│  └────────┘  └────────┘  └────────┘           │
│  ┌────────┐  ┌────────┐  ┌────────┐           │
│  │ APR    │  │ MAY    │  │ JUN◉   │           │  JUN = current month →
│  │ ░▒ ░░·· │  │ ░░▒ ▒░ │  │ ▒▓░ ░· │           │  name tinted --accent-text;
│  │ ▒░░·▒ ░ │  │ ░ ▒▓▒░ │  │ ░░24 ▒ │           │  "24" ringed --secondary (today).
│  │ ░░ ▒· ░ │  │ ▒░░ ·░ │  │ ▓▒░░ ▒ │           │
│  │ ░ ▒░    │  │ ·░ ░   │  │ ▒· ░   │           │
│  └────────┘  └────────┘  └────────┘           │
│  ┌────────┐  ┌────────┐  ┌────────┐           │
│  │ JUL    │  │ AUG    │  │ SEP    │           │  (rows 3 & 4: OCT NOV DEC below)
│  │ ▓▒░ ░▒░ │  │ ░ ··░░ │  │ ▒░▒ ░░ │           │
│  │ …       │  │ …      │  │ …      │           │
│  └────────┘  └────────┘  └────────┘           │
│   … OCT  NOV  DEC …                            │
│                                               │
│  ─────────────  36pt gap  ─────────────        │
│                                               │
│  2027                                         │ ← next year section peeking in
│  ▬▬▬▬                                          │
│  ┌────────┐  ┌────────┐  ┌────────┐           │
│                                               │
│  ╭──────────╮                                 │
│  │ ◴  Today │  ← glass pill, bottom-LEFT       │  warm Liquid Glass island
│  ╰──────────╯                                 │
│   ╭───────────────────────────╮               │
│   │ ⌂Today  ▣Calendar  ⚙Set  +│               │  3-tab glass bar + separated "+"
│   ╰───────────────────────────╯               │
│           ▬▬▬▬▬ home indicator                 │
└─────────────────────────────────────────────┘
```

(`·` faint/light · `░` light step · `▒` medium · `▓` busy/packed — these are the per-day heat patches inside each mini-grid, not literal glyphs.)

**Region by region:**
1. **Status bar** — system, untouched. Dynamic Island reserved.
2. **Inline nav bar (warm glass)** — Fraunces `titleM` centered "2026" (the centered year), trailing **Search** glass island + conditional **Today** (`calendar.circle`, shown only off the current year).
3. **Year title block** — `displayL` "2026" left-aligned at `lg 16` inset, with a **44×2pt clay (`--secondary`) underline** 4pt below it (the one rationed clay-as-structure mark on the section header). This is the only place clay appears at section scale.
4. **Mini-month grid** — 12 tiles, 3 columns, `lg 16` column spacing, `xl 20` row spacing, `lg 16` horizontal insets. Each tile (`medium` radius 8, `--surface`, letterpress):
   - **Name eyebrow** — `label` role, abbreviated localized month ("JAN"…"DEC"), `--text-primary`. The **current month (JUN)** tints its name `--accent-text` clay.
   - **Day-number mini-grid** — a 7-column grid of tiny `codeSmall` day numbers (1…30/31), leading blanks for the first weekday, always 6 rows tall so every tile is uniform height. Off-month/no-load numbers in `--text-secondary`; numbers sitting on the two hottest heat steps flip to `--on-accent` cream. **Today's number ("24" in JUN)** carries the `--secondary` clay value AND a thin (~0.75pt) stroked clay ring, so it survives the dense grid mid-scroll.
   - **Heat wash** — each day cell's tiny patch (radius `chip 4`) is filled per the ramp above from that day's `daily-counts` value; zero-count days stay bare `--surface`.
5. **Jump-to-Today pill** — warm Liquid-Glass island, bottom-LEFT, `calendar.circle` glyph + "Today" `label`. Always visible; progressive (recenter the year, or zoom into today's month once already on the current year).
6. **Tab bar + "+"** — 3 warm-glass tabs (Calendar active) + separated "+" capsule.

**The ONE rationed clay moment:** there is **no wax-seal** and **no decisive CTA** on Year (nothing is committed here — it's pure navigation). Clay is rationed instead to **(a) the year-title underline, (b) today's day ring, and (c) the top of the heat ramp** — a single coherent "this is where the heat/now lives" hue. Do not let clay appear as a chip fill, a button, or month-name text on anything but the current month.

---

## Data & states

Everything binds to real backend fields. Field/endpoint names verbatim.

- **Year sections** — locale-driven; `YearLayout` lays 12 mini-months in 3 cols × 4 rows; the centered year drives the nav title and Jump-to-Today. Infinite both directions.
- **Mini-month grid cells** — from `MonthGridModel.model(for: monthAnchor)`: `nameAbbreviated`, `cells: [Day?]` (with `leadingBlankCount` blanks), each `Day { number, date }`. Always 6 rows reserved for uniform tile height.
- **Heat-map intensity (the new data binding)** — `GET /tasks/daily-counts?calendarId&from&to` → `DailyCountsResponse { counts: [String: Int] }`, where keys are local `YYYY-MM-DD` and **zero-count days are omitted**. In-app this lands in `CalendarStore.dayCountsCache: [Date: Int]` keyed by `CalendarMath.startOfDay`. Each day patch picks its ramp step from `counts[day] ?? 0`.
  - **⚠ Sync-scope flag (carry into the build, not the mockup):** the shipped `ensureCountsSynced` fetches counts **per week (±1 week)** for the Day scope's strip — it does NOT yet fetch a whole year. A real year heat-map needs a wider `from`/`to` (per-visible-year, or a coarser monthly-count endpoint) wired through the same memoized `WindowSyncMeta` path. For the Claude Design render, **populate plausible full-year counts** so the wash reads; note in-build that the fetch window is a follow-up.
- **Today** — `CalendarMath.startOfMonth(.now)` flags the current month (name → `--accent-text`); `CalendarMath.startOfDay(.now)` flags today's number (clay value + ring). Today is June 24, 2026 → JUN is the accent month, "24" is ringed.
- **Tap target** — selecting a mini-month reports its `monthAnchor` + cell frame to zoom into Month, anchored on that tile.

**States to render:**
- **Default (loaded):** 2026 fully populated with a realistic load — e.g. a busy March (`▓` clusters around mid-month deadlines), a light August (mostly bare `--surface`, a few `░` days), JUN showing today. The wash varies tile-to-tile so the heat-map actually communicates.
- **Loading (first paint, counts not yet in cache):** mini-months render **immediately** with day numbers and the today ring (grid geometry needs no network) but **bare `--surface`** patches — no heat yet — plus a subtle warm shimmer/`loadingOverlay` warm-ink scrim (`--text-primary` 8%, never black) over the grid while `daily-counts` resolves. The skeleton is the real grid, so there's no empty flash.
- **Empty (a genuinely free year — e.g. scrolling to 2031):** all tiles render bare `--surface`, zero rings, and a one-line legend hint near the bottom in `caption`/`--text-secondary`: **"No tasks scheduled this year yet."** Don't fabricate a wash where there's no data.
- **Error (counts fetch failed):** grid stays usable (geometry + today), heat simply absent, and a transient warm **NotificationBanner** (severity `.warning`, brass rail) slides in: **"Couldn't load this year's load. Pull to retry."** — NOT a full-page takeover (the page is navigable without counts). Whole-screen first-load failure would use `ErrorStateView.networkFailure(retry:)`, but Year degrades gracefully instead.
- **Edge cases:**
  - **High-count saturation:** clamp the ramp at the `7+` step — a 14-event day and a 7-event day share the hottest patch (don't run an unbounded gradient that loses contrast).
  - **Recurring tasks:** counted as occurrences in `daily-counts` (the BE expands them), so a daily standup correctly thickens every weekday's heat — no special-casing in the UI.
  - **All-day tasks:** counted like any occurrence; they contribute to the day's heat the same way.
  - **Offline:** show the last cached `dayCountsCache` wash (stale-but-present) rather than blanking; the banner notes staleness only on an explicit refresh failure.
  - **Long month names / localization:** the eyebrow is already abbreviated ("SEP"); under a non-English locale keep it to the localized abbreviation, single line, never wrapping into the grid.
  - **AX / Dynamic Type XL:** if the day numbers would collide, drop the per-day numbers and keep **only the heat patches + the today ring** (the month still reads as a heat block); the name eyebrow scales and may shrink to `titleM`-relative.

---

## Interactions & motion

- **Tap a mini-month → zoom into Month.** The signature transition: a cell-anchored cross-scale (`.navigationTransition(.zoom)` semantics; in code, `CalendarZoomController`'s cross-transform). The tapped tile's frame is the anchor — the Month scope grows up *from that tile's footprint* while the Year grid counter-magnifies into it and fades. **Settle: spring, duration 0.32s, damping 0.9** (the implemented `settleDuration` / `dampingRatio`). Cream/clay don't flash; it reads as one continuous magnification.
  - *Reduce Motion:* replace the scale with a **cross-fade** between Year and the anchored Month at the same 0.32s timing — no zoom, no parallax.
- **Pinch-out / pinch-in (secondary accelerator).** A pinch on the grid drives the same Year↔Month cross-zoom interactively (`innerVisibility` 0→1), committing on release from progress + fling velocity. Pinch is the *power-user* path; **tap is the discoverable one** — every zoom is reachable without the gesture.
  - *Reduce Motion:* the pinch still commits, but the in-between frames cross-fade rather than scale.
- **Vertical scroll between years** — infinite; window grows on **scroll-settle only** (never mid-fling), with exact `contentOffset` correction on prepend so the viewport never jumps. Prefetch syncs each mini-month's counts ahead of visibility (capped buffer).
- **Jump-to-Today pill (progressive).** Tap when off the current year → smooth recenter scroll to the current year (spring, damping ~0.8, fade+scale show/hide). Tap when *already* centered on the current year → it acts as a zoom-in into **today's month** (delegates `scopeDidRequestToday`). Mirrors the implemented progressive behavior.
- **Heat-wash appearance.** When `daily-counts` resolves, fade each day patch from bare `--surface` to its step over ~200ms ease-out, staggered subtly by row so the year "develops" like a contact print rather than snapping. *Reduce Motion:* no stagger, single cross-fade.
- **Nav-bar Today control** fades in/out (`.snappy`) as the centered year crosses into/out of the current year.
- **No `WaxSeal`, no completion check, no detent sheet** originate on Year (it commits nothing). The two recurring brand signatures — the 160ms letterpress press and the seal spring — don't fire here; the **0.32s zoom spring is this screen's motion signature.**

---

## iOS specifics

- **Dynamic Type:** every role scales (`displayL` year, `label` names, `codeSmall` numbers via `UIFontMetrics`). At AX-large sizes, follow the §"Data & states" reflow: drop per-day numbers, keep heat + today ring; never clip a tile or wrap a month name into its grid.
- **Haptics (`.sensoryFeedback`):**
  - `.selection` on a mini-month tap (the moment the zoom commits) and on each scope flick.
  - `.impact` (light) when the zoom settles onto Month, and on a pinch direction-lock.
  - `.selection` when the Jump-to-Today recenter lands on the current year.
  - Respect the system haptics setting.
- **Context menu (long-press a mini-month):** "Open month", "Jump to today", and (since counts are the point here) "Show busiest day" — a quick peek that scrolls/zooms to that month's heaviest day. Secondary to the tap.
- **Swipe actions:** none — Year has no list rows to act on (read-only navigation surface). Don't invent them.
- **Pull-to-refresh** (`.refreshable`) at the top of the scroll re-pulls `daily-counts` for the visible year(s) and re-washes.
- **VoiceOver:** each mini-month is a single button element. Label speaks **name + load summary + today**, e.g. *"June, 41 tasks this month, contains today. Button. Double-tap to open month."* The current month appends *"current month."* A bare month reads *"August, no tasks scheduled."* Today's day, when surfaced, reads *"24 June, today, 3 tasks."* The year title is a heading. The Today pill: *"Jump to today."* **Never color-only** — the heat level is always voiced as a count, and today is voiced, not just ringed.
- **Reduce Transparency:** the warm Liquid-Glass chrome (tab bar, nav bar, Today pill, search island) falls back to a **solid warm kraft fill** (`--surface-elevated`/`--surface-sunken`), not Apple's default grey.
- **Contrast (hard mode, light-only):** verify the *composited* result — the lowest heat step (`--surface-sunken` on `--surface`) must still be distinguishable as "non-zero," and day numbers on the two hottest steps MUST be cream `--on-accent` (clay `#BE4A28` ≈ 3.6:1 fill demands light ink). Include a small legend so the ramp is decodable, not guessed.

---

## ✦ Claude Design prompt (paste this)

> Generate a single fixed iPhone screen (393×852pt @3x, NOT responsive — a native iOS 26 screen, not a web page) using the published **"Kraft & Ink"** design system and its tokens ONLY.
>
> **SCREEN:** Calendar — Year scope. The furthest zoom-out: an infinite vertical stack of year sections, each a 3-column × 4-row grid of 12 mini-months washed with a single-accent busyness heat-map, so a whole year of load reads at a glance and tapping a mini-month zooms into that month.
>
> **FRAME:** iOS status bar (9:41, signal, battery); Dynamic Island reserved in the top safe area; top safe area ~59pt; 34pt home-indicator gutter; 16pt side margins. Inline warm Liquid-Glass nav bar: a serif **Fraunces "2026"** title (the centered year), with trailing **Search** glass island (`magnifyingglass`) and a conditional **Today** control (`calendar.circle`, shown only when scrolled off the current year). Bottom: floating warm Liquid-Glass **3-tab** bar — **Today · Calendar · Settings** — with a **separated "+"** capsule; the **Calendar** tab is active. The grid scrolls behind the bar.
>
> **AUDIENCE:** a CUE power user surveying the shape of their year — spotting heavy months and free stretches before drilling in.
>
> **LAYOUT (top → bottom), real content (NO lorem):**
> 1. Year-title block: **"2026"** in Fraunces `displayL` (34, semibold, tracking −0.4), `--text-primary`, left-aligned at 16pt; a **44×2pt clay (`--secondary`) underline** 4pt beneath it.
> 2. A **3×4 grid of 12 mini-months** (16pt side insets, 16pt column gap, 20pt row gap). Each mini-month is a **`--surface` tile, radius 8 (`medium`), letterpress depth** (1px `--border` + hard value-cut shadow, blur 0): an abbreviated **month name** ("JAN"…"DEC") in Public Sans `label` (13) at top, over a **tiny 7-column grid of day numbers** (1…30/31) in **JetBrains Mono `codeSmall`** (11), always 6 rows tall, leading blanks for the first weekday.
> 3. **Heat-map wash:** behind each day number sits a tiny patch (radius 4) tinted by that day's task count along ONE clay ramp — **0 = bare `--surface` (no tint); 1–2 = `--surface-sunken`; 3–4 = clay 22%; 5–6 = clay 45%; 7+ = clay 72%** (day numbers on the two hottest steps flip to cream `--on-accent`). Vary the wash month-to-month: a heavy March, a near-empty August, a moderate June.
> 4. **Today (June 24, 2026):** the **JUN** tile's name tints `--accent-text` clay; the number **"24"** carries clay and a thin clay ring.
> 5. Show **2.5 year sections** (2026 full, 2025 trailing in at top, 2027 peeking at bottom) separated by a **36pt** gap, so the infinite vertical scroll reads.
> 6. **Jump-to-Today pill:** a warm Liquid-Glass island bottom-**LEFT** (20pt from the leading edge, 24pt above the bottom safe area): `calendar.circle` + "Today" in `label`.
>
> **REAL DATA BINDINGS:** mini-month grids from `MonthGridModel`; heat from `GET /tasks/daily-counts` → `{ counts: { "2026-03-12": 6, … } }` (local `YYYY-MM-DD`, zero days omitted). Today = `startOfDay(.now)`.
>
> **STATES (render the default; note the others):** Default = full 2026 with varied heat. Loading = real grid + today ring but **bare patches** under a warm-ink scrim (`--text-primary` 8%, never black) until counts resolve. Empty (free year) = all bare tiles + a `caption` line "No tasks scheduled this year yet." Error = grid stays usable, a transient warm **NotificationBanner** (warning/brass) reads "Couldn't load this year's load. Pull to retry." Include a small **legend** decoding the 0 · 1–2 · 3–4 · 5+ ramp in `codeSmall`.
>
> **MOTION:** tapping a mini-month does a cell-anchored cross-zoom into Month — **spring, 0.32s, damping 0.9** — the tile growing into the month; pinch is a secondary accelerator for the same zoom. (Reduce Motion → cross-fade at the same timing.)
>
> **NATIVE iOS:** all tap targets ≥44pt; Dynamic Type (at AX-large, drop per-day numbers, keep heat patches + today ring); `.sensoryFeedback(.selection)` on tap; long-press context menu (Open month / Jump to today / Show busiest day); pull-to-refresh re-washes; VoiceOver speaks each month as "June, 41 tasks this month, contains today, button" — heat ALWAYS voiced as a count, never color-only.
>
> **BRAND GUARDRAILS (do not violate):** Fonts are **Fraunces** (titles ≥17pt) / **Public Sans** (labels — NOT Inter, NOT SF Pro) / **JetBrains Mono** (numbers, dates) — pin them. NO Inter/SF Pro, NO purple, NO blue, NO gradients, NO glassmorphism on the mini-month tiles (glass is chrome-only — tab bar, nav bar, Today pill, search island — and warm-tinted, never cool grey), NO soft/blurred drop shadows (letterpress only: 1px `--border` + hard value-cut, blur 0), NO pure `#FFFFFF` tiles on the white page, NO pure `#000000`, NO crayon-box rainbow — encode busyness as **ONE clay intensity ramp**, and a zero day stays **bare paper**, never tinted. Crisp 4–12px cut-paper corners, never 16–20px squircle bubbles. **Ration the clay accent:** it appears ONLY as the year-title underline, today's day ring, and the top of the heat ramp — **no wax seal and no decisive CTA on this screen** (it commits nothing; it navigates). Don't say "modern/clean/sleek/beautiful." Native iOS patterns throughout.
