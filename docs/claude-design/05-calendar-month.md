# Calendar — Month

A zoom-out month grid that shows each day's real event titles with density-aware previews, so the user can scan a whole month at a glance and tap any day to zoom into it. Visual base: **Kraft & Ink** (use the published CUE design system; invent nothing).

---

## Design system (Kraft & Ink)

Literal restatement of the tokens this screen uses, copied from `01-DESIGN-SYSTEM.md`. **Use these only — do not invent palette, fonts, or shadows.**

**Color (opaque sRGB, by role):**
- `--background #FFFFFF` — app canvas behind everything.
- `--surface #FAF6EF` — cards / rows (faint warm paper). The month grid sits directly on the white page; cards are for the optional density-mode control.
- `--surface-sunken #F1EADF` — the pinned weekday-legend strip, the SELECTED day chip, and the day's title-chip fills.
- `--primary #5A3A24` (espresso) — structural tint: day numbers, the density-ramp accent, event-indicator dots, the Today-pill label/icon.
- `--secondary #BE4A28` (clay) — **FILL ONLY, rationed to ONCE per screen**: the TODAY day-number chip. Nothing else on this screen is clay.
- `--accent-text #A53D22` — the only clay allowed as text/icon/thin-rule (AA). Not used as a second accent here; reserved if a clay micro-label is ever needed.
- `--on-accent #FBF5EA` (cream) — ink on the clay TODAY chip and on any espresso fill.
- `--text-primary #2E211A` — day numbers, title-chip text, month titles.
- `--text-secondary #6E5C4C` — weekday legend symbols, the "+N more" overflow row, out-of-month / muted text.
- `--separator #D0BA98` — decorative hairline under the weekday legend ONLY (never a real edge).
- `--border #8C7142` — functional edges: the SELECTED chip ring, the density-mode card outline.
- `--success #466234` (olive) — completed occurrences (struck/checked title chip). Status lives on a SHAPE channel, not by stealing the accent.
- `--warning #C9A24B` (brass) — reserved; not used on this screen.

**Typography (3 bundled families — never Inter / SF Pro):**
- **Fraunces** (display, titles ≥17pt): `title-L` 22 medium (−0.2) = per-section month title ("June", "July 2027").
- **Public Sans** (body/labels — NOT Inter): `caption` 12 regular = day title chips; `label` 13 medium (+0.3) = density-mode chip text.
- **JetBrains Mono** (receipt voice — dates/counts): `code-small` 11 medium (+0.8) = day numbers, the weekday legend symbols ("M T W T F S S"), and the "+N" overflow count.

**Spacing (4pt grid):** `xxs 2` (chip-to-chip inside a day cell), `xs 4` (inter-column gap in the week row), `sm 8` (inter-row gap; legend bottom inset), `md 12` (grid side inset), `lg 16` (default), `xl 20` (Today-pill leading inset), `xxl 24` (section bottom breathing room).

**Radius (cut-paper, never squircle bubbles):** `tight 2` = day title chips; `small 6` = density-mode card/chips; the TODAY/SELECTED day-number chip is a **24×24 circle** (the one circle on the grid). No 16–20pt bubbles.

**Depth ("letterpress, not float"):** the grid itself is flat on the white page. The optional density-mode card uses `.letterpress` (1pt `--border` + hard value-cut shadow `--text-primary` 6% y:1, **blur 0**). The Today pill is **Liquid Glass** (chrome only), warm-tinted, with a warm value-shadow (`--text-primary` 10%, y:2) — never a cold black float. **No soft drop shadows anywhere.**

**Components used:** `CueCard` (density-mode control container), `CueChip` (density-mode segmented control: selected = espresso `--primary` fill + cream, unselected = `--surface` + `--border`), the floating **Today pill** (warm Liquid-Glass capsule). **No WaxSeal on this screen** — the wax-seal commit moments (complete a task, save an event) belong to the Day scope and the Create sheet, not the month overview. The one rationed clay moment here is the **TODAY day-number chip**.

---

## Frame & platform

- **Single fixed iPhone frame, 393×852pt @3x. NOT responsive** — a native iOS screen, not a web page.
- iOS status bar (time left, battery/Wi-Fi right); **Dynamic Island reserved** at top center; top safe area ~59pt; **34pt home-indicator gutter** at the bottom; **16pt side margins** (the grid itself uses a 12pt inner inset).
- **Nav chrome:** this is the **Calendar tab** at Month scope. A native iOS large-title-collapsing nav bar would normally sit up top, but in CUE the month scope is an edge-to-edge scrolling surface — the **per-section Fraunces month title scrolls inline** as a section header and a **pinned weekday legend** (`surface-sunken` strip + hairline) stays at the top of the scroll. Nav-bar trailing actions (≤2): a **Search** glass island (`magnifyingglass`) and the scope/zoom affordance — Search is a nav-bar icon, **never a tab**.
- **Bottom:** the floating **3-tab warm Liquid-Glass tab bar** — **Today / Calendar / Settings** — with a **separated "+"** action capsule to its right that opens the Create sheet over any tab. Default landing tab is Today; here the **Calendar** tab is active.
- **One-handed reach:** the **Today pill floats bottom-leading** (left thumb zone, ~20pt inset, above the tab bar). Tapping a day to zoom is a large 44pt+ target anywhere in the grid; the thumb never has to stretch to the top.

---

## Layout

Top → bottom, with realistic CUE content (real-sounding tasks/events/groups, no lorem):

```
┌─────────────────────────────────────────────┐
│ ●●●   9:41              Dynamic Island   ▾ 􀙇 │  status bar
├─────────────────────────────────────────────┤
│ Calendar              [ Compact ▾ ]  􀊫  ⚲    │  scope + density + search (nav island)
├─────────────────────────────────────────────┤
│  M    T    W    T    F    S    S             │  PINNED weekday legend (mono, sunken strip)
│ ───────────────────────────────────────────  │  hairline (separator)
├─────────────────────────────────────────────┤
│  June                                        │  Fraunces title-L, inline section header
│                                              │
│              1    2    3    4    5           │  week row 1 (leading blanks under M–S)
│                        Standup               │   day cells: number + title chips + "+N"
│                                              │
│  6    7    8    9    10   11   12            │
│            Dentist  Sprint                   │
│            9:00     review                   │
│                                              │
│  13   14   15   16   17   18   19            │
│       Gym   ▸Pay    Mom's   Flight           │
│             rent    bday    BER→LIS          │
│             Groce…  +2                        │
│                                              │
│  20   21   22   23  (24)  25   26            │  (24) = TODAY: clay-fill circle chip
│            Review  1:1   Lunch  Yoga         │
│            PR      Anna  w/Sam               │
│                    +3                         │
│                                              │
│  27   28   29   30                           │
│       Invoice                                │
│       Acme                                   │
│                                              │
│  July                                        │  next section continues infinitely ↓
│  …                                           │
│                                              │
│  ╭───────────╮                               │
│  │ ↩  Today  │  ← floating glass pill        │  bottom-leading, above tab bar
│  ╰───────────╯                               │
├─────────────────────────────────────────────┤
│   ╭─────────────────────────────╮   ╭─────╮  │
│   │  ☀ Today   📅 Calendar  ⚙︎ │   │  +  │  │  3-tab glass bar + separated "+"
│   ╰─────────────────────────────╯   ╰─────╯  │
└─────────────────────────────────────────────┘
            (34pt home-indicator gutter)
```

1. **Pinned weekday legend** — a `surface-sunken` strip spanning full width, seven locale-ordered symbols in **JetBrains Mono `code-small`** (`M T W T F S S`), `text-secondary`, centered in 7 equal columns, with a 0.5pt `--separator` hairline along its bottom. **Pinned** to the top of the scroll so the column meaning never leaves the screen.

2. **Per-section month title** — **Fraunces `title-L`** in `text-primary`, left-aligned, e.g. **"June"** within the current year, **"July 2027"** when the year differs. Scrolls inline with its section (not pinned), sitting above that month's grid.

3. **The 7-column day grid** — six fixed week rows per month (always 42 cells so every section is the same height), 12pt side inset, 4pt inter-column / 8pt inter-row gaps, each day cell **64pt tall**. Each day cell, top→bottom:
   - **Day number** — JetBrains Mono `code-small`, left-aligned in a 24pt slot. Default: bare number, `text-primary`. **SELECTED**: `surface-sunken` circle + 1pt `--border` ring + `text-primary` (quiet, findable, spends no accent). **TODAY**: filled **clay `--secondary` circle** + cream `--on-accent` number, no border — **the one rationed clay moment on this screen**. Today wins if also selected.
   - **Density preview** (cap **2–3** items) — left-aligned `caption` title chips on a `surface-sunken` / `tight 2` radius fill, **tinted by `TaskGroup.color`** (the design target — see Data & states), truncating-tail. Then a **"+N more"** overflow row in JetBrains Mono `code-small`, `text-secondary`, when the day has more than the cap.

   Real content used above (verbatim, real CUE-style):
   - Jun 3 — **Standup** (group "Work", espresso)
   - Jun 8 — **Dentist 9:00**, **Sprint review** (Work)
   - Jun 15 — **Pay rent** (recurring ▸, group "Bills"), **Groceries** (group "Errands"), **+2**
   - Jun 17 — **Flight BER→LIS** (all-day, group "Travel")
   - Jun 18 — **Mom's birthday** (all-day, group "Family")
   - Jun 24 (**TODAY**) — **1:1 Anna**, **Lunch w/Sam**, **+3** (Work)
   - Jun 21 — **Review PR**, Jun 25 — **Lunch**, Jun 28 — **Invoice Acme**, Jun 7 — **Dentist**, Jun 14 — **Gym**, Jun 22 — **Yoga**

4. **Density-mode control** (top-right of the scope bar) — a small `CueCard`-backed segmented control of three `CueChip`s: **Compact** (dots only — espresso indicator dots, the densest scan), **Stacked** (the default shown above: capped title chips + "+N"), **Details** (taller rows, more titles before overflow). Selected chip = espresso `--primary` fill + cream; the others `--surface` + `--border`. **Density is encoded as intensity of ONE accent** (espresso), never a rainbow of dots.

5. **Floating Today pill** — bottom-leading warm Liquid-Glass capsule, `arrow.uturn.backward` glyph + "Today" in `--primary` (`label` role), lifted by a warm value-shadow. **Progressive behavior:** when the centered month is NOT the current month it recenters on the current month; when it already IS the current month, tapping it **zooms one level into today's Day scope**.

6. **Bottom chrome** — the 3-tab warm Liquid-Glass tab bar (Today / Calendar / Settings) with the separated "+" capsule. Calendar tab active.

**The single rationed clay/wax moment:** the **TODAY day-number chip** (clay fill + cream number). There is **no wax seal** on this screen.

---

## Data & states

Every element binds to the real backend feed and SwiftData read-side adapter (`CalendarDataAdapter.occurrencesByDay(from:to:)`, fed by the per-month sync).

- **Day numbers / grid geometry** — `CalendarMath`: locale week start, `leadingBlankCount(forMonth:)` for the leading blanks, fixed 6-row (42-cell) sections; `isToday(_)` drives the clay TODAY chip; SELECTED = `startOfDay` equals `store.selectedDate`.
- **Day title chips & "+N"** — `titlesByDay: [Date: [String]]`, keyed by `CalendarMath.startOfDay`, built from `OccurrenceVM.title` for occurrences in the windowed range `[monthBounds(first).from, monthBounds(last).to)`, sorted ascending by `startAt`. Cap = first 2–3 titles; overflow = `titles.count − cap` → `"+N"`.
- **Density / busyness** — two sources: `GET /tasks/daily-counts` → `{ counts: { "2026-06-24": 5, … } }` (zero-count days omitted) for the dot/indicator count, and `GET /tasks` occurrences for the actual titles. Counts drive `indicatorsByDay: [Date: Int]`. **Compact mode** renders up to ~4 espresso indicator dots; **Stacked/Details** render titles. Encode "busier day" as **more/darker espresso intensity**, NOT multiple hues.
- **Color = group membership** — chips tint by **`TaskGroup.color`** (hex e.g. `#E27921` for "Errands", validated via `Color(hex:)` with a graceful fallback to `--surface-sunken` when the string is malformed or the task is ungrouped). `Task` itself carries no color; it is derived from its `groupId → TaskGroup.color`, falling back to `Calendar.color`. *(Implementation note: the live `MonthDayGridCell` currently fills chips with `surface-sunken`/`text-primary`; group-color tinting is the design target this prompt specifies.)*
- **Zoom anchor** — tapping a day sets `store.selectedDate` and reports the tapped cell frame so the zoom controller anchors the month→Day cross-scale on it.

**States:**
- **Loading (first paint / unsynced month)** — the grid scaffold (numbers, legend, blanks) renders immediately; title chips appear as each month syncs (per-section `ensureMonthSynced`). Show a subtle **warm-scrim shimmer on un-synced day cells**, not a full-screen spinner — the calendar is never blank.
- **Empty (a month with zero occurrences)** — numbers + legend only, no chips, no dots. No empty-state illustration mid-grid (the grid IS the content); the day cells simply read clean. Optional faint `text-secondary` whisper only if an entire visible window is empty.
- **Error (sync/network failure)** — keep the last-synced grid visible (offline-tolerant); surface a transient **`NotificationBanner`** (warning/brass, Liquid Glass) — "Couldn't refresh June" with a retry — never a blocking full-screen error over a populated calendar.
- **Offline** — render from the on-device SwiftData cache (evicted windows re-fetch on re-scroll); the banner notes stale data; no destructive clearing.
- **Edge cases:**
  - **Recurring** — prefix a small `arrow.triangle.2.circlepath`-style mark or a leading `▸` on the chip (shape channel), e.g. "▸ Pay rent". `OccurrenceVM.isRecurring`.
  - **All-day** — chip with no time prefix, e.g. "Mom's birthday", "Flight BER→LIS"; sorts first within the day.
  - **Completed** — `OccurrenceVM.completedAt != nil`: chip text in **olive `--success`** with a strikethrough (status on the shape/value channel, not by stealing the clay accent).
  - **Overflow** — cap honored strictly; "+N more" in mono `code-small`; the cell never grows past 64pt or clips numbers.
  - **Long titles** — single line, truncate-tail ("Sprint review with…"); never wrap past the cell.
  - **Multi-day spans** (e.g. a trip) — show the title on the start day with a continuation hint; don't draw web-style bars across cells in v1.

---

## Interactions & motion

- **Tap a day → zoom into Day scope.** `.navigationTransition(.zoom)` anchored on the tapped cell (month→day cross-scale): spring settle **0.32, damping 0.9**, scale + smoothstep cross-fade anchored on the cell frame. Sets `store.selectedDate` first. **Reduce Motion → straight cross-fade** (no scale), same destination.
- **Pinch-out → zoom to Year; pinch-in on a cell → zoom to Day.** Pinch is the *secondary* accelerator; **tap is the discoverable path** (every gesture has a visible fallback). Same 0.32/0.9 settle.
- **Vertical scroll = infinite months.** Sections prepend/append on settle (never mid-fling) with exact `contentOffset` correction (every section is a constant height) so the viewport never jumps. `.refreshable` pull at the top re-syncs the visible window.
- **Today pill** spring **0.28, damping ~0.86** for the recenter scroll; fade+scale show/hide spring damping 0.8. Progressive: recenter, else zoom-in.
- **Density-mode switch** — `.snappy` capsule/chip swap when toggling Compact / Stacked / Details; chips re-layout with a quick `.easeOut(0.16)` fill/ink swap (the `CueChip` signature).
- **Selection** — tapping briefly shows the SELECTED chip ring before the zoom commits.
- **Reduce-Motion fallbacks (per cue):** zoom → cross-fade; pill show/hide → instant opacity; density switch → instant; prepend offset-correction is non-animated already.

The two recurring motion signatures elsewhere (the **160ms ease-out** press and the **single wax-seal spring**) are intentionally **absent from the grid body** — the month overview is a calm scanning surface.

---

## iOS specifics

- **Dynamic Type** — every text style is relative (`code-small`, `caption`, `label`, `title-L` scale with the user's size). At AX sizes: day cells keep the number, **reduce the visible title cap to 1 + "+N"**, and let "+N" absorb the rest rather than clipping or growing the row unboundedly. Never truncate the day number.
- **Haptics (`.sensoryFeedback`):** `.selection` on a day tap (scope flick into Day) and on a density-mode change; `.impact(.soft)` when the Today pill recenters/snaps; respect the system haptic setting.
- **Context menu** (long-press a day) — quick actions without zooming: **"New event on Jun 24"** (opens Create sheet pre-dated), **"Open day"**, **"Jump here"**. Surfaced as `accessibilityActions` too.
- **Swipe actions** — not on grid cells (they're zoom targets); reserved for the Day/agenda list. The month grid is tap/long-press/pinch only.
- **VoiceOver** — each day cell is a single `.button` element speaking **"June 24, Wednesday, today, 3 events: 1:1 Anna, Lunch w/Sam, and 1 more"** (date + weekday + today/selected state + count + titles); blanks are not accessibility elements. The pinned legend is decorative/skipped after first read. The Today pill is labeled "Today". **Never color-only meaning** — recurring/all-day/completed all carry a shape or text cue. **Composited contrast** of any title-chip text over its group-color fill must clear ≥4.5:1; if a group color is too light, render the chip text in `text-primary` on a tinted-at-low-alpha fill rather than colored text.

---

## ✦ Claude Design prompt (paste this)

> Generate a single fixed iPhone screen (393×852pt @3x, **NOT responsive** — a native iOS view, not a web page) using the published **CUE "Kraft & Ink"** design system and its tokens ONLY. No new colors, fonts, gradients, or pure #FFFFFF/#000000 surfaces.
>
> **Screen: Calendar — Month.** A zoom-out month grid showing each day's real event titles with density-aware previews; tap a day to zoom in.
>
> **Frame & chrome.** iOS status bar (9:41, battery/Wi-Fi), Dynamic Island reserved, top safe area ~59pt, 34pt home-indicator gutter, 16pt side margins. Top: a thin scope bar with the word "Calendar", a small **density-mode control** on the right (three `CueChip`s: Compact / Stacked / Details, "Stacked" selected), and a **Search** nav-bar glass icon (magnifyingglass) — Search is an icon, never a tab. Below it a **pinned weekday legend** strip on `--surface-sunken` with a 0.5pt `--separator` hairline: seven symbols "M T W T F S S" in **JetBrains Mono** 11pt `--text-secondary`. Bottom: a floating **warm Liquid-Glass 3-tab bar — Today / Calendar / Settings — with a SEPARATED "+" capsule** to its right; the **Calendar** tab is active.
>
> **Body — infinite vertical month grid.** Per-section month title in **Fraunces 22 medium** `--text-primary` ("June"; "July 2027" when the year differs), left-aligned, scrolling inline. Under it a 7-column grid, six week rows, each day cell 64pt tall, 12pt side inset, 4pt column / 8pt row gaps. Each day cell, top→bottom: a left-aligned day **number** in **JetBrains Mono** 11pt; then up to **2–3 event title chips** in **Public Sans** 12pt on a low-radius (2pt) fill **tinted by the task's group color**, truncating-tail; then a **"+N more"** row in JetBrains Mono 11pt `--text-secondary` when the day overflows.
>
> **The TODAY cell (June 24) is the ONE rationed accent:** its day-number sits in a filled **clay `--secondary` 24pt circle** with a cream `--on-accent` number — the single clay moment on the screen, no border. A **SELECTED** day uses a quiet `--surface-sunken` circle + 1pt `--border` ring (no clay). Every other number is bare `--text-primary`.
>
> **Real content (verbatim — no lorem, no "Event 1"):** Jun 3 "Standup"; Jun 8 "Dentist 9:00" + "Sprint review"; Jun 15 "▸ Pay rent" + "Groceries" + "+2"; Jun 17 "Flight BER→LIS" (all-day); Jun 18 "Mom's birthday" (all-day); **Jun 24 (TODAY)** "1:1 Anna" + "Lunch w/Sam" + "+3"; Jun 21 "Review PR"; Jun 25 "Lunch"; Jun 28 "Invoice Acme". Group colors: Work (espresso-leaning), Bills, Errands, Travel, Family — tint chips by group, but keep busyness encoded as **intensity of ONE accent**, not a rainbow. Recurring items show a leading "▸" shape cue; completed items render in olive `--success` with a strikethrough.
>
> **Floating Today pill** — bottom-leading warm Liquid-Glass capsule, `arrow.uturn.backward` + "Today" in `--primary` (Public Sans 13), warm value-shadow (never a cold black float), above the tab bar in the left thumb zone.
>
> **Depth & detail.** Letterpress only — the optional density card uses a 1pt `--border` + hard value-cut shadow (blur 0). The grid itself is flat on the white page. Liquid Glass is warm-tinted and used ONLY for the tab bar, the Today pill, and the Search island — never on the grid. All tap targets ≥44pt. JetBrains Mono is the receipt voice (numbers, legend, "+N"); Fraunces is titles only; Public Sans is body/chips.
>
> **Anti-AI-slop guardrails (honor exactly):** NO Inter / SF Pro / Helvetica — Fraunces + Public Sans + JetBrains Mono only. NO purple, NO blue accents, NO gradients, NO glassmorphism on the grid or content cards, NO soft blurred drop shadows (only hard blur-0 value-cuts), NO pure #FFFFFF cards floating on white, NO pure #000000. NO generic evenly-spaced bento layout. NO 16–20pt squircle bubbles — crisp 2–10pt cut-paper corners; the only circle is the 24pt day-number chip. Honor Kraft & Ink exactly: clay `--secondary` is FILL-ONLY and appears **once** (the TODAY chip), espresso `--primary` stays structural, olive=done, density = intensity of one accent (never a lone monochrome dot, never multiple hues). Native iOS patterns: pinned legend, inline section titles, infinite vertical scroll, `.zoom` scope transition on tap, floating glass tab bar with a separated "+". Don't use the words "modern/clean/sleek/beautiful".
