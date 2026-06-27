# Calendar — Day

The innermost calendar scope: one day at a time, paged horizontally, shown either as an hour timeline or a to-do list, with tasks completed in place by pressing a wax seal.

---

## Design system (Kraft & Ink)

> Literal restatement of the tokens this screen uses, copied from `01-DESIGN-SYSTEM.md`. Use these ONLY — do not invent palette, fonts, or shadows. Reference tokens by role, never by raw hex.

**Color (opaque sRGB, light-only):**
- `--background #FFFFFF` — app canvas behind everything.
- `--surface #FAF6EF` — cards / agenda rows (faint warm paper).
- `--surface-sunken #F1EADF` — recessed strips, the view-mode switcher track, the count-badge chip.
- `--primary #5A3A24` — espresso. Structural tint: timeline event blocks, the open-task agenda spine, the selected week-strip pill, the selected view-mode segment, principal nav title.
- `--primary-pressed #43291A` — pressed espresso / seal rim.
- `--secondary #BE4A28` — **rationed clay, FILL ONLY.** The one-hot moment: the stamped wax seal, the now-line + its dot, the TODAY dot in the week strip. Never as text, never on more than this.
- `--accent-text #A53D22` — the only clay allowed as text / thin rules (AA-safe). Not used as a fill here.
- `--on-accent #FBF5EA` — cream ink on a primary/secondary fill.
- `--text-primary #2E211A` — body + headings (near-black warm).
- `--text-secondary #6E5C4C` — supporting / muted text, time ranges, hour labels.
- `--separator #D0BA98` — decorative hairlines ONLY (hour rules, half-hour ticks). Never a real edge.
- `--border #8C7142` — functional edges (card outline, unstamped seal-well, count badge has none).
- `--success #466234` — olive. Completed-task agenda spine.
- `--danger #A8331F` — brick. Destructive (delete swipe).

Discipline: terracotta `--secondary` is the single hottest mark per screen — here it is the **wax-seal stamp** (and, structurally, the now-line, which is "the clay = now/today" marker, not a competing CTA). Olive = done, espresso = structure. Color presence, not a rainbow.

**Typography (3 bundled families; web preview substitutes via Google Fonts):**
- Display/headings: **Fraunces** (NOT SF Pro). `titleL` = 22 medium, tracking −0.2 (day section heading "Schedule Today" / "Today's Tasks"); `titleM` = 18 medium, tracking −0.2 (agenda card title, nav date title, week-strip day number).
- Body/labels: **Public Sans** (NOT Inter). `body` 16 reg; `callout` 15 reg (notes, empty-state description); `label` 13 medium tracking 0.3 (timeline block title, chip text).
- Code/receipts: **JetBrains Mono**. `code` 13 reg tracking 0.2 (agenda time range "9:00 AM – 10:30 AM"); `codeSmall` 11 medium tracking 0.8 (hour labels "08.00", weekday letters "MO", count badge, month label).

**Spacing (4pt grid):** `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 (default / side margins / card inner) · xl 20 · xxl 24 · xxxl 32`.

**Radius (cut-paper, never squircle):** `chip 4 · small 6 (default — agenda card, timeline block, week pill, count badge) · medium 8 · card 10 · large 12`. Seal toggle is a 34pt circle; timeline now-dot/seal stamp render as the irregular `WaxSealShape`.

**Depth ("letterpress, not float"):** two hard, blur-radius-0 treatments only. `.letterpress` = 1pt `--border` stroke + `shadow(--text-primary 6%, y:1)` — the agenda card default. No soft drop shadows, no glassmorphism on content. System Liquid Glass is chrome only (tab bar, nav bar, the day's floating Jump-to-Today pill).

**Components used:** `WaxSeal` (the agenda-row completion stamp — the rationed moment), `CueChip`-style week-strip tiles + view-mode segments (espresso fill when selected, never clay), the agenda paper card (port of `CueCard` letterpress), the floating Jump-to-Today pill (warm Liquid Glass). No `CueButton`, `CueAvatar`, or `NotificationBanner` on this screen.

---

## Frame & platform

- **Single fixed iPhone frame, 393×852pt @3x. NOT responsive** — a native iOS 26 screen, not a web page.
- iOS status bar (time left, battery/signal right); **Dynamic Island reserved** at top center; top safe area ~59pt; **34pt home-indicator gutter** at the bottom; 16pt (`lg`) side margins.
- **Nav chrome (inline, drill-down depth):** the day scope lives inside the Calendar tab's `NavigationStack` with `navigationBarTitleDisplayMode(.inline)`. The nav bar carries three real affordances, all in warm Liquid Glass:
  - **Principal (center):** the day date as **Fraunces `titleM`**, format `Wed, Jun 24` (weekday-abbrev · day · month-abbrev), in `--text-primary`.
  - **Trailing 1 (only when off today):** an "open today" glass icon button — SF Symbol `calendar.circle`, VoiceOver "Go to today".
  - **Trailing 2 (always):** the **Timeline ⇄ List view-mode switcher** — a small `--surface-sunken` segmented capsule with two icon segments (`calendar.day.timeline.left`, `list.bullet`); the selected segment fills **espresso `--primary`** with a cream glyph, the other is `--text-secondary`. (Selection is espresso, not clay — it must not compete with the seal.)
- **Bottom:** the app's floating **3-tab warm Liquid Glass tab bar** — Today / Calendar / Settings — with a **separated "+"** action item trailing it that opens the Create sheet over this tab. Calendar is the active tab. Search is NOT a tab; it is the nav-bar glass island reachable here and on Today. The day content scrolls *behind* the tab bar (bottom safe area ignored).
- **Floating Jump-to-Today pill:** a small warm Liquid Glass pill anchored bottom-leading (`xl` inset from the left, `xxl` above the safe area), **shown only when the selected day ≠ today**. It clears as you land on today.
- **One-handed reach:** the seal toggle (the primary in-place action) sits on the trailing edge of each agenda row in the lower thumb zone; horizontal day-paging works anywhere on the page; the switcher and Today control are top-right (reachable but secondary).

---

## Layout

Top → bottom, with realistic CUE content. Selected day = **Wed, Jun 24** (today). Real group colors come from `TaskGroup.color`.

```
┌─────────────────────────────────────────────┐
│  ●●●  9:41                       ▂▄ 􀷃 100% │  status bar + Dynamic Island
│                                               │
│        ‹      Wed, Jun 24      ⊙   [▤|☰]     │  nav: date (Fraunces titleM) · today · switcher
│                                               │
│  MON  TUE  WED  THU  FRI  SAT  SUN            │  WEEK STRIP (height 80)
│  22   23  ┌24┐  25   26   27   28            │  espresso pill behind selected day
│   2    ·  │ 5 │  3    ·    1    ·            │  count badge (sunken) / today•clay / empty
│          └───┘                               │
│                                               │
│  Schedule Today                               │  Fraunces titleL heading
│  ▔▔▔▔                                         │  44×2 clay rule under it
│                                               │
│  ┌─ ALL-DAY ──────────────────────────────┐  │  all-day band (isAllDay) — sunken strip
│  │ ▎ Sprint review prep      (Work)        │  │  espresso chip, group-tinted edge
│  └──────────────────────────────────────────┘ │
│                                               │
│  08.00 ┊─────────────────────────────────    │  TIMELINE (hour grid, sep hairlines)
│        ┊                                       │
│  ┌─────────────────────────────────────────┐ │
│  │ Standup                                  │ │  espresso block 9:00–9:30 (Work #4C6B8A)
│  10.00 ┊─────────────────────────────────    │
│  ┌──────────────┐ ┌──────────────────────┐  │  overlapping → side-by-side columns
│  │ Dentist ✓   │ │ Design crit          │  │  Dentist done (faded, strike); crit live
│  12.00 ┊─────────────────────────────────    │
│        ┊                                       │
│ ━━━━━━━●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │  NOW-LINE (clay) + dot @ 13:24
│  14.00 ┊─────────────────────────────────    │
│  ┌─────────────────────────────────────────┐ │
│  │ Call with Anya — Q3 budget          ○   │ │  task block w/ cream completion ring
│  16.00 ┊─────────────────────────────────    │
│                                               │
│              ┌───────────────┐                │
│              │ ⊙ Today       │                │  floating Jump-to-Today (hidden on today)
│              └───────────────┘                │
│   ◐ Today        ▦ Calendar      ⚙ Settings  +│  floating warm glass tab bar + separated +
└─────────────────────────────────────────────┘
```

**Region by region:**

1. **Week strip** (height 80, full-bleed). Seven day tiles for the selected day's locale week, each stacking: day number (Fraunces `titleM`), weekday letter (JetBrains Mono `codeSmall`, uppercase, e.g. `WED`), and a fixed 14pt bottom slot showing — in priority order — a month label (for days >3 days out), a **count badge** (`--surface-sunken` chip, espresso-ink mono count, e.g. `5` on Wed, `2` on Mon, `3` on Thu), or the **clay TODAY dot** (only when the day has zero tasks; on days-with-tasks the count badge wins and clay is not spent). A single **espresso `--primary` pill** (radius `small`) sits *behind* the selected tile (Wed 24), recoloring its number/weekday to cream — it is a solid printed mark, deliberately not glass on white. Swiping the day pages slides this pill tile-to-tile in lockstep.

2. **Day heading** — Fraunces `titleL` in `--text-primary`. Timeline mode: **"Schedule Today"** (today) / **"Schedule on Thu, Jun 25"** (other days). List mode: **"Today's Tasks"** / **"Tasks on Thu, Jun 25"**. Under it, a **44×2pt clay rule** (`--secondary`) — the one decorative clay accent allowed, a tiny printed underline, `lg` left margin.

3. **All-day band** (when any occurrence has `isAllDay = true`) — a slim `--surface-sunken` strip directly under the heading, above hour 0 / above the first list row, labeled `ALL-DAY` in `codeSmall`/`--text-secondary`. Holds compact pills (espresso fill, cream `label` text, a 4pt group-colored leading edge), e.g. **"Sprint review prep" (Work)**. Collapses entirely when no all-day items.

4. **Day body** — one of two modes (the switcher toggles):
   - **Timeline** (default): a vertically-scrolling 0–24h grid, **36pt per hour**, 10pt top padding. Full-width hour rules + half-hour ticks in `--separator` (faint, decorative). A 44pt leading **time column** with two-hourly mono labels (`08.00`, `10.00`, …). Event blocks are **espresso `--primary`** rounded rectangles (radius `small`) positioned by `occurrenceStart → occurrenceEnd`, cream `label` title (2 lines max), min height 28pt; overlapping events split into side-by-side columns. Tasks (`requiresCompletion`) show a small cream completion ring (`circle` → `checkmark.circle.fill`) top-right inside the block. Completed blocks drop to 45% opacity with a strikethrough title. On **today only**, a **clay now-line** spans the full width at the current time with a clay dot in the gutter, refreshed each minute. Initial scroll centers the current hour (today) or 08:00 (other days).
   - **List**: a vertical stack of **agenda paper cards** (`--surface`, radius `small`, **letterpress** depth: 1pt `--border` + hard y:1 value-cut), `sm` inter-card gap, `lg` side insets, `xxl` bottom inset (clears the tab bar). Each card: a 4pt leading **spine** — espresso `--primary` while open, **olive `--success`** once done — then a column of Fraunces `titleM` title (strikethrough when done), a JetBrains Mono `code` time range ("9:00 AM – 10:30 AM"), and up to 3 lines of `--text-secondary` `callout` notes. **For tasks (`requiresCompletion`)**, the trailing edge carries the **`WaxSeal`** (34pt): an unstamped dashed `--border` "seal-well" when open, a **clay `--secondary` stamp with a cream check** when done. Pure events have no seal. Completed cards sit at 62% opacity and sort to the bottom (incomplete chronological first).

5. **THE rationed wax-seal moment:** completing a task = **pressing its seal**. In **List mode** this is the literal `WaxSeal` stamping clay; in **Timeline mode** it is the terse cream ring filling. Either way, completion is the single clay/seal commit on this screen. The now-line/today-dot clay is structural (the "now" marker), not a second CTA — keep clay to these and nothing else.

---

## Data & states

Bind every element to real backend fields (`OccurrenceDTO`, `TaskGroup`, daily-counts, the completion endpoint).

**Bindings:**
- **Day feed** = `GET /tasks?calendarId&from&to&includeCompleted&includeTodos` → `OccurrenceDTO[]`, bucketed by `startOfDay`. Each block/row reads `occurrenceStart`, `occurrenceEnd`, `title`, `notes`, `isAllDay`, `requiresCompletion`, `completedAt`, `isRecurring`. Block geometry = `occurrenceStart → occurrenceEnd` (falls back to `start + 1h` when no end).
- **Color** = `TaskGroup.color` (hex, e.g. Work `#4C6B8A`, Personal `#7A8450`, Health `#A24B5A`), surfaced as the agenda card spine's group accent / the all-day pill's leading edge / a thin group tint. Espresso stays the block's base fill; the group color is the *membership* channel, never the whole block (color = identity, status = shape/opacity).
- **Week-strip count badge** = `GET /tasks/daily-counts` → `{ counts: { "2026-06-24": 5, "2026-06-22": 2, … } }` (zero-count days omitted → those show the today-dot or nothing). `≥100` renders as `•••`.
- **TODAY dot** = `CalendarMath.isToday`; clay, only on zero-count days (count badge otherwise wins).
- **Now-line** = current time, today's page only.
- **Completion (the seal)** = `PATCH /tasks/:id/completion { isCompleted, occurrenceStart }`. Address the backend by `seriesId` (URL) + **`originalStart`** for recurring instances (the stable exception key — NOT the display `occurrenceStart`). Optimistic: stamp immediately, reconcile on response; keep the stamp pinned until the PATCH resolves so a background delta can't un-check it.
- **Recurring** = `isRecurring` — surface a subtle recurrence glyph (`arrow.triangle.2.circlepath`) after the title in `--text-secondary`; the row is otherwise identical.

**States to render:**
- **Default (today, Timeline):** the populated day above — Standup 9:00–9:30 (Work), Dentist 10:00–10:30 done (faded + strike), Design crit 10:30–11:30 (Personal) overlapping it side-by-side, "Call with Anya — Q3 budget" 14:00 task with open ring, all-day "Sprint review prep" (Work) in the band, clay now-line at 13:24.
- **Default (List):** same data as agenda cards — open tasks chronological with dashed seal-wells, "Dentist" sealed (clay stamp, olive spine, 62% opacity) sunk to the bottom.
- **Empty day:** no `OccurrenceDTO` for the date. Centered `circle.dashed` glyph in `--text-secondary` + Fraunces `titleM` **"No tasks"** + `callout`/`--text-secondary` **"Nothing scheduled for this day."** Week strip + heading + clay rule still render. No clay, no seal.
- **Loading (first fetch):** warm-ink scrim (`--text-primary` 8%, *not* black) over the day body with a glass-backed `--primary`-tinted spinner; the week strip and heading stay visible. Paging to an un-synced day shows this briefly on that page only.
- **Error (day fetch failed, offline):** full-body `ContentUnavailableView`-style state — `wifi.exclamationmark` glyph, "Can't load this day", "Check your connection and try again", + a retry control. Transient toggle failures surface as a top notification banner (warm glass), not a full-page error; the optimistic stamp reverts.
- **Offline / optimistic:** seal stamps and rings respond instantly from local SwiftData; the PATCH queues. A failed PATCH reverts the stamp and shows a warning banner.
- **Edge — recurring:** show the recurrence glyph; completing seals only *this* occurrence (keyed by `originalStart`); a sealed recurring instance does not seal the series.
- **Edge — all-day:** rendered in the band, never on the hour grid; multiple all-day items wrap or scroll within the band; the band collapses when empty.
- **Edge — overflow:** a very dense day (count `8+`) scrolls the timeline naturally; overlapping clusters keep splitting into columns (3+ columns shrink but stay ≥ a tappable min width). The strip badge caps at `•••` for `≥100`.
- **Edge — long titles:** timeline block titles truncate to 2 lines; agenda card titles wrap fully (multi-line), the seal staying pinned top-trailing; notes cap at 3 lines.

---

## Interactions & motion

Every gesture has a visible fallback; every animation has a Reduce-Motion fallback.

- **Swipe between days** (horizontal pager, full-page): the day body pages ±1 day; inset the live-drag start from the very left edge so the system back-swipe survives. As you drag, the week-strip espresso pill and the strip's own week-page offset slide in lockstep with the finger (one geometry function of pager offset — they cannot desync). On settle, the new day commits and the strip pill springs to the landed tile. **Spring: response ~0.28, damping 0.86.** Fallback: tap any week-strip day tile to jump there.
- **Tap a week-strip day:** selects + pages there; pill springs across (same 0.28/0.86 spring). Crossing a week boundary slides the whole strip by exactly the dragged fraction.
- **Toggle Timeline ⇄ List** (the switcher): the day body cross-swaps; the selected segment's espresso capsule slides under the icon. **`.snappy`.** Heading text + which affordance (ring vs seal) updates with it. Reduce Motion → instant capsule move + cross-fade body.
- **Complete a task — THE wax-seal moment:** pressing the seal (List) plays the signature stamp — `WaxSealShape` scales **0.4 → 1**, opacity **0 → 1**, rotation **−8° → 0°**, clay fill in, cream check appearing. **`.spring(response: 0.42, dampingFraction: 0.62)`** (~450ms felt). The card's spine cross-fades espresso → olive, title strikes through, card eases to 62% opacity, then re-sorts to the bottom. Timeline mode: the cream ring fills `circle → checkmark.circle.fill`, block fades to 45% + strikes through. **Reduce Motion → cross-fade the stamped seal in over ~150ms (no scale/rotation), no re-sort animation** (the design system flags the seal spring as unconditional in code; specify this cross-fade fallback explicitly).
- **Jump-to-Today pill:** appears (fade + scale, spring damping 0.8) when off today; tap recenters to today's page (animated paging + pill spring) and the pill hides. When already on today, tapping it asks the host to zoom one level out toward today (cross-scope). Reduce Motion → instant page set + fade.
- **Tap an event/agenda body:** pushes Task Detail (standard nav push). Reduce Motion → cross-fade push.
- **Pull-to-refresh** on the day body → re-fetches the visible day + week counts.
- **Now-line:** advances silently each minute on today's page (no animation needed).

---

## iOS specifics

- **Dynamic Type:** all roles scale via relative text styles (`titleL .title2`, `titleM .title3`, `code .footnote`, `codeSmall .caption2`, etc.). At AX sizes: agenda card titles wrap (never clip); timeline block titles truncate at 2 lines with the time still legible; the week-strip number/letter scale within the 80pt strip; the all-day band grows to fit. Never clip a title.
- **Haptics (`.sensoryFeedback`):** `.selection` on day-page settle + week-tile tap + view-mode toggle; `.success` on a completed seal/ring; `.impact` (light) when the Jump-to-Today pill is tapped. Respect the system haptics setting.
- **Swipe actions (List mode rows):** leading-swipe = **complete** (calm — reveals the seal/olive, success haptic), trailing-full-swipe = **delete series** (brick `--danger`). These mirror the tap-the-seal and context-menu paths.
- **Context menu (long-press a row/block):** Complete / Edit / Skip this occurrence (`POST /tasks/:id/skip { occurrenceStart }`) / Delete series — the gesture-free fallback for every action.
- **VoiceOver:**
  - Week-strip tile: "June 24, Wednesday, today, 5 tasks" (date · weekday · today flag · count); selected tile adds the `.selected` trait. Days with no count omit the count clause.
  - Agenda/timeline row: label = the task title; the seal/ring is a separate button labeled "Mark as done" / "Mark as not done"; recurring rows append "repeating".
  - Heading reads "Schedule Today" / "Today's Tasks" as a header.
  - Now-line is decorative (`accessibilityHidden`); the seal *shape* is hidden, its button is not.
  - Switcher: two buttons "Timeline" / "List", the active one `.selected`. Today control: "Go to today".
- **Reduce Transparency:** the warm glass tab bar, nav bar, and Jump-to-Today pill fall back to a solid warm Kraft fill (no frost). The week pill is already a solid espresso fill on white by design.
- **Contrast:** verify composited cream-on-espresso block titles and the count badge ink stay ≥ 4.5:1; the clay now-line is a non-text mark (clears 3:1).

---

## ✦ Claude Design prompt (paste this)

```
Design a single iOS screen: the CUE planner's "Calendar — Day" scope. Use the published
"Kraft & Ink" design system and ITS tokens ONLY — no new colors, fonts, gradients, or pure
white/black surfaces. This is the innermost calendar zoom: one day, paged horizontally,
shown as either an hour timeline or a to-do list, with tasks completed in place by a wax seal.

FRAME: Single fixed iPhone 393×852pt @3x. NOT responsive — a native iOS 26 screen, not a web
page. iOS status bar (time left; battery/signal right); Dynamic Island reserved at top center;
top safe area ~59pt; 34pt home-indicator gutter; 16pt side margins.

NAV CHROME (inline, warm Liquid Glass): center principal title = the day date in Fraunces
titleM, format "Wed, Jun 24", in --text-primary. Trailing: a Timeline⇄List view-mode switcher
(small --surface-sunken segmented capsule, two icon segments: a timeline glyph and a
list-bullet glyph; the SELECTED segment fills espresso --primary with a cream glyph, the other
is --text-secondary). Plus, only when off today, an "open today" glass icon button
(calendar.circle).

LAYOUT, top → bottom:
1. WEEK STRIP (height ~80, full-bleed). Seven day tiles for the selected day's week, each
   stacking: day number (Fraunces titleM), weekday letter (JetBrains Mono codeSmall uppercase,
   e.g. WED), and a 14pt bottom slot showing — by priority — a count badge (a --surface-sunken
   chip with espresso mono count), or a clay TODAY dot (only on zero-task days), or nothing.
   A SOLID espresso --primary pill (radius 6) sits behind the SELECTED tile, recoloring its
   number/letter to cream. It is a printed mark, NOT glass-on-white. Real counts: Mon 22 → 2,
   Wed 24 (selected, today) → 5, Thu 25 → 3, Sat 27 → 1; Tue/Fri/Sun → none.
2. DAY HEADING: Fraunces titleL "Schedule Today" (timeline) / "Today's Tasks" (list), in
   --text-primary, with a 44×2pt clay --secondary rule underneath (left-aligned). This tiny
   clay underline is the ONLY decorative clay on the screen.
3. ALL-DAY BAND (only if all-day items exist): a slim --surface-sunken strip labeled "ALL-DAY"
   (codeSmall, --text-secondary) holding compact espresso pills with a 4pt group-colored
   leading edge + cream label text — e.g. "Sprint review prep" (Work, #4C6B8A).
4. DAY BODY — show TIMELINE mode as the hero:
   - A 0–24h vertical grid, 36pt per hour. Full-width hour rules + half-hour ticks in
     --separator (faint, decorative). A 44pt leading time column with two-hourly JetBrains Mono
     labels: 08.00, 10.00, 12.00, 14.00, 16.00.
   - Event blocks = espresso --primary rounded rectangles (radius 6) positioned by start→end,
     cream Public Sans label title (max 2 lines), min height 28. Overlapping events split into
     side-by-side columns. Tasks show a small cream completion ring (an open circle) top-right
     inside the block; a COMPLETED block is 45% opacity with a strikethrough title and a filled
     cream check.
   - A CLAY now-line spans the full width at 13:24 with a clay dot in the time gutter (today
     only).
   Real content: "Standup" 9:00–9:30 (Work); "Dentist" 10:00–10:30 DONE (faded, struck);
   "Design crit" 10:30–11:30 (Personal #7A8450) overlapping Dentist side-by-side; "Call with
   Anya — Q3 budget" 14:00–14:30, an open task with a completion ring.
   Also render a SECOND artboard of the SAME day in LIST mode: vertical agenda paper cards
   (--surface, radius 6, LETTERPRESS depth = 1pt --border + a hard y:1 value-cut, NO soft
   shadow), each with a 4pt leading spine (espresso when open, OLIVE --success when done), a
   Fraunces titleM title (struck through when done), a JetBrains Mono code time range
   ("9:00 AM – 10:30 AM"), and up to 3 lines of --text-secondary callout notes. For TASKS, the
   trailing edge carries a WAX SEAL (34pt): an UNSTAMPED dashed --border "seal-well" when open,
   a CLAY --secondary stamp with a cream check when done. Pure events have no seal. Completed
   cards are 62% opacity and sorted to the bottom. Show "Dentist" sealed (clay stamp, olive
   spine, faded, struck, at the bottom) and the others open with dashed seal-wells.
5. A floating warm Liquid Glass "Jump to Today" pill bottom-leading (hidden on today — render it
   only in the off-today variant).

THE ONE WAX-SEAL MOMENT: completing a task. List = the clay WaxSeal stamping; Timeline = the
cream ring filling. Clay --secondary appears ONLY on: the stamped seal, the now-line + its dot,
the zero-task TODAY dot, and the 44×2pt heading rule. Nothing else clay.

BOTTOM: the app's floating 3-tab warm Liquid Glass tab bar — Today / Calendar (active) /
Settings — with a SEPARATED "+" action item trailing it. Day content scrolls behind the bar.

STATES to also render: (a) EMPTY day — centered circle.dashed glyph in --text-secondary,
Fraunces titleM "No tasks", callout "Nothing scheduled for this day."; week strip + heading +
clay rule still present, no clay, no seal. (b) LOADING — warm-ink scrim (--text-primary 8%, NOT
black) over the body with a --primary-tinted glass-backed spinner, strip + heading visible.

REAL DATA SHAPES (use verbatim, NO lorem, NO "Event 1"): occurrences come from
OccurrenceDTO blocks sized occurrenceStart→occurrenceEnd; color from TaskGroup.color
(Work #4C6B8A, Personal #7A8450, Health #A24B5A); the all-day band from isAllDay; the week
count badges from /tasks/daily-counts ({ "2026-06-24": 5, ... }); completion via the wax seal
(PATCH /tasks/:id/completion). Tasks (requiresCompletion) get the seal/ring; pure events don't.

NATIVE iOS PATTERNS: inline nav title; horizontal day paging (week pill tracks it); swipe
actions on list rows (leading = complete, trailing-full = delete in brick --danger); long-press
context menu (Complete / Edit / Skip / Delete); pull-to-refresh; all tap targets ≥44pt; Dynamic
Type (titles wrap or truncate, never clip).

ANTI-AI-SLOP GUARDRAILS (hard): Fraunces for titles ≥17pt ONLY — NO Inter, NO SF Pro, NO
Helvetica. Public Sans for body; JetBrains Mono for times/counts/hour labels. LETTERPRESS depth
only (1px --border + a hard blur-0 value-cut) — NO soft/blurred drop shadows, NO glassmorphism
on content cards (glass is chrome-only: tab bar, nav bar, Jump-to-Today pill, warm-tinted not
cool blue). NO gradients. NO blue/purple/neon accents. NO pure #FFFFFF cards on white, NO pure
#000000. Crisp cut-paper corners (4–10px), never 16–20px squircle bubbles. Selected week tile
and selected switcher segment fill espresso --primary, NEVER clay — clay is spent only on the
single wax-seal moment + the structural now/today markers. Day-load shown as one neutral count
badge, not a rainbow of colored dots. Honor the Kraft & Ink system exactly; do not invent a
palette or fonts. Render real CUE tasks, not placeholders.
```
