# Scope zoom & navigation (cross-cutting)

Define the year↔month↔day zoom model, the scope-preserving Today control, and the visible affordance controls (zoom segmented control, Today pill) that give every gesture a tappable fallback — so the calendar reads as one continuous magnifiable surface, never three disconnected screens.

> This file is BOTH a behavior/motion spec AND the affordance UI it documents. The Claude Design prompt at the bottom renders the **Calendar tab in Month scope with the affordance controls visible** (the zoom segmented control + the floating Today pill + a mid-zoom "ghost" of the transition). The transition mechanics themselves are documented in prose + the motion table so the founder can hand both to engineering.

---

## Design system (Kraft & Ink)

Use the published **Kraft & Ink** system and these tokens ONLY. No new colors, fonts, gradients, glassmorphism on content, pure `#FFFFFF` surfaces-on-white, or pure `#000000`.

**Color (opaque sRGB, by role):**
- `--background #FFFFFF` — app canvas behind everything.
- `--surface #FAF6EF` — cards, rows, day cells (faint warm paper).
- `--surface-elevated #FEFCF8` — sheets / elevated.
- `--surface-sunken #F1EADF` — recessed strips (segmented-control track, header bands, zebra).
- `--primary #5A3A24` (espresso) — structural tint; key actions; **selected segment fill**; Today-pill ink.
- `--primary-pressed #43291A` — pressed primary.
- `--secondary #BE4A28` (clay) — **FILL ONLY**, rationed: the TODAY/now marker, the wax seal, the single decisive CTA. The one-hot moment.
- `--accent-text #A53D22` — the ONLY clay allowed as **text / icons / thin rules** (AA-safe).
- `--on-accent #FBF5EA` (cream) — ink on a primary/secondary fill.
- `--text-primary #2E211A` — body + headings. `--text-secondary #6E5C4C` — muted.
- `--separator #D0BA98` — decorative hairlines ONLY (never a real edge).
- `--border #8C7142` — functional edges (cards, inputs, segmented-control outline).
- `--success #466234` olive (done) · `--warning #C9A24B` brass (pending, INK on it) · `--danger #A8331F` brick (destructive).

**Fonts (3 bundled — NEVER Inter / SF Pro):**
- **Fraunces** (display ≥17pt): `displayL 34 semibold (−0.4)`, `titleL 22 medium (−0.2)`, `titleM 18 medium (−0.2)`, `headline 17 medium`. Month/year titles, scope hero.
- **Public Sans** (body/labels): `body 16`, `bodyEmphasis 16 semibold` (button labels), `callout 15`, `label 13 medium (+0.3)` (chip text, segment labels), `caption 12`.
- **JetBrains Mono** (receipt voice — dates, counts, day numbers, weekday eyebrows): `code 13 (+0.2)`, `codeSmall 11 medium (+0.8)`.

**Spacing (4pt grid):** `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 (default / card inner) · xl 20 · xxl 24 (between cards) · xxxl 32 · huge 48`. 16pt side margins.

**Radii (cut-paper, NO 16–20pt squircles):** `chip 4 · small 6 (default — buttons, fields) · medium 8 · card 10 · large 12`. Capsules reserved for genuine segmented toggles only (the scope control and the Today pill ARE capsules — they're segmented chrome).

**Depth — "letterpress, not float" (blur radius 0 always):**
- `letterpress` = 1pt `--border` stroke + hard value-cut shadow `--text-primary @6%, y:1` — card default.
- `value-cut` = 1pt `--border` + `--text-primary @12%, y:2` — crisp stacked-paper offset.
- `glass` = system Liquid Glass, **chrome only** (tab bar, nav bar, the floating Today pill), re-tinted **warm** toward kraft/clay — never Apple cool blue.

**Components (by name):** `CueCard`, `CueButton(.primary / .decisive / .secondary / .ghost)`, `CueChip` (4pt rubber-stamp rect, never a pill; selected = espresso `--primary` fill + cream, never clay), `CueAvatar`, `WaxSeal` (irregular hand-pressed clay blob; the two commit moments). The scope segmented control and the Today pill are bespoke **glass capsules** (chrome), distinct from the letterpress cards.

---

## Frame & platform

- **Single fixed iPhone frame, 393×852pt @3x. NOT responsive** — a native iOS 26 screen, not a web page.
- iOS status bar (time left, battery/signal right); **Dynamic Island reserved** at top center. Top safe area ~59pt; **34pt home-indicator gutter**; 16pt side margins; every tap target ≥44pt.
- **Nav chrome:** inline nav bar (drill-down style) with a **Fraunces principal date title** (`titleM`, e.g. "Wed 24 Jun") centered, and two trailing actions: the **Today control** (`calendar.circle` glyph, shown only while off-today) and the **timeline/list `ViewModeSwitcher`** (day scope only). Bottom: the 3-tab warm Liquid-Glass tab bar — **Today · Calendar · Settings** — with the **separated "+"** action and a **search glass-island** icon; the Calendar tab is active here.
- **Scope zoom is in-place within the Calendar tab** — NOT a `NavigationStack` push and NOT three routes. Year/Month/Day are zoom levels of one surface; the cross-zoom is the navigation.
- **One-handed reach:** the floating **Today pill** sits bottom-leading (above the tab bar, ~`xxl`/24pt up from the safe area, ~`xl`/20pt in from the left edge) — thumb-reachable; the destructive/secondary affordances stay out of the accidental-tap zone.

---

## Layout

Top-to-bottom, Calendar tab in **Month scope** (the scope where both affordance controls and the zoom relationship read clearest), mid-interaction so the transition is legible:

```
┌─────────────────────────────────────────────┐
│ ●  9:41        ◀ Dynamic Island ▶      ▤ ▦ ⚡ │  status bar
├─────────────────────────────────────────────┤
│  ‹                June 2026               ⌕  │  inline nav bar:
│         (Fraunces titleM, centered)          │  search glass-island trailing
├─────────────────────────────────────────────┤
│   ┌─────────────────────────────────────┐    │  SCOPE SEGMENTED CONTROL
│   │  Year  │   Month   │    Day          │    │  glass capsule, sunken track;
│   └─────────────────────────────────────┘    │  "Month" selected = espresso fill
│                                              │
│   Mo  Tu  We  Th  Fr  Sa  Su                 │  weekday eyebrow (JetBrains Mono
│   ─────────────────────────────────────      │  codeSmall, --text-secondary)
│    1   2   3   4   5   6   7                  │
│        ·   ··  ·                             │  day cells: number (mono) +
│    8   9  10  11  12  13  14                 │  density = espresso intensity ramp
│   ··  ·       ···  ·   ··                    │  (1–2pt under-number bar), NOT dots
│   15  16  17  18  19  20  21                 │
│    ·   ··  ·   ·       ···                   │
│ ┌──22──┐ ╲                                   │  ── ZOOM GHOST ──
│ │ 24   │  ╲   tapped cell (24) lifts &        │  the tapped day cell scales up,
│ │ ●●●● │   ╲  scales toward fullscreen Day,    │  clay TODAY ring on "24";
│ └──────┘    ╲ month counter-magnifies + fades │  faint Day-scope timeline bleeds
│   29  30  ·· ·                               │  through underneath at low alpha
│                                              │
│  ╭──────────╮                                │  FLOATING TODAY PILL
│  │ ↩  Today │   ← glass capsule, espresso ink │  (warm Liquid Glass, bottom-leading)
│  ╰──────────╯                                │
│                                              │
│    ◉ Today      📅 Calendar      ⚙ Settings   │  warm glass tab bar
│              ╭───╮                            │  separated "+" action
│              │ + │                            │
│              ╰───╯                            │
└─────────────────────────────────────────────┘
        34pt home-indicator gutter
```

**Realistic CUE content to surface in the grid** (real-sounding tasks/events, no lorem):
- **24 Jun (today)** — clay `--secondary` TODAY ring on the number; density bar at high intensity. Cells carry titles only at Month "Details" density; here Compact density shows the under-number intensity bar. Today's load: "Standup • Q3 roadmap review • Dentist 16:30 • Call Mum".
- Nearby days seeded with plausible group-colored load: **18 Jun** "Sprint planning" (espresso work group), **20 Jun** "Yoga 07:00 / Groceries / Dad's birthday 🎂" (3 events → highest intensity bar), **27 Jun** "Flight to Berlin 06:15" (all-day travel marker).
- The **zoom ghost** anchors on tapped cell **24** — its agenda ("Standup 09:30, Q3 roadmap review 11:00, Dentist 16:30") faintly bleeds through the half-grown Day scope.

**The ONE rationed clay moment on this screen:** the **TODAY marker** (the clay ring on day 24) — that is the screen's single `--secondary` use. There is **NO wax seal here** (no commit action on a navigation/zoom surface), and **NO decisive CTA**. The scope control's selected segment and the Today pill's ink are **espresso `--primary`**, deliberately, so they never compete with the one clay marker. (The wax seal lives on completion/save surfaces — pages 04/08 — not on zoom.)

---

## Data & states

Every affordance binds to the real calendar surface and backend feed:

- **Scope state** — the active `CalendarScopeKind` (`year 0 / month 1 / day 2`). The segmented control reflects and sets it; `zoomedIn`/`zoomedOut` define the adjacency (year→month→day). Selected segment = espresso fill.
- **Selected unit** — `store.selectedDate` (a day anchor; each scope centers on its own unit type via `center(on:)` — `startOfDay` / `startOfMonth` / `startOfYear`). The nav-bar title formats it `weekday day month` (e.g. "Wed 24 Jun").
- **Density per day** — `GET /tasks/daily-counts → { counts: { "2026-06-24": 4, … } }` (zero-count days omitted). Render busyness as a **single-accent intensity ramp** (espresso `--primary` at 4 steps: 1 / 2 / 3 / 4+ events → progressively darker/taller under-number bar), NOT a rainbow and NOT a lone monochrome dot.
- **Occurrence feed (the zoom-ghost agenda)** — `OccurrenceDTO { occurrenceStart, occurrenceEnd, title, isAllDay, requiresCompletion, completedAt, isRecurring, groupId }` from `GET /tasks?calendarId&from&to`. Block color derives from `TaskGroup.color` (e.g. `#E27921`) — Task itself has no color.
- **Today control** — visible only while `!CalendarMath.isToday(store.selectedDate)`; hidden on today. **Scope-preserving:** `jump(to: .now)` recenters the **active** scope on today **at the current zoom level** — a Today tap in Year recenters the year grid in place; it does NOT hard-reset to Day. When already on today, a second invocation is **progressive Today** (`scopeDidRequestToday`): zoom **one level in** toward today's unit.

**States:**
- **Empty** — a month/year with zero counts: cells render the number only, no intensity bar; year heat-map shows the lightest "0 events" tint distinct from "1 event" (validate the two are visually separable in light-only palette — a faint `--separator` outline vs a `--primary @12%` fill). Copy if a whole scope is empty after load: "Nothing scheduled" (`callout`, `--text-secondary`).
- **Loading** — counts/feed in flight: cells show numbers immediately (instant scaffold), intensity bars fade in when `daily-counts` resolves (`LoadingStateView` warm-scrim only if the whole surface is cold). Never block the zoom on data.
- **Error** — `daily-counts`/`tasks` fetch fails: keep the last-synced intensity, surface a transient **NotificationBanner** (`.error` brick rail, "Couldn't refresh — showing last synced"), retry on `.refreshable`. A cold first-load failure → `ErrorStateView.networkFailure(retry:)`.
- **Offline** — render from the SwiftData cache; intensity = last synced counts; banner ".warning Offline — last synced 14:02" (brass, INK on it).
- **Edge cases:**
  - **Recurring** (`isRecurring`) — counted once per occurrence in `daily-counts`; the ghost agenda shows a small recurring badge.
  - **All-day** (`isAllDay`) — contributes to the day's intensity; in the ghost it sits in the all-day band, not the timeline.
  - **Overflow** — at Month "Details" density a day with >2–3 titles shows "+N more" (`code`, `--accent-text`); at Compact density overflow is absorbed into the top intensity step (4+).
  - **Long titles** — truncate with tail ellipsis at one line in cells; the ghost agenda truncates at two.
  - **Mid-transition data change** — a refresh landing during a zoom must not reflow the anchor cell; counts apply after the transition settles (the controller freezes scroll for the duration).

---

## Interactions & motion

The signature of this screen is the **cell-anchored cross-zoom** between adjacent scopes. Every gesture has a **tappable visible fallback**.

**Gestures & their fallbacks:**
- **Zoom IN** — *gesture:* pinch-OUT (spread) anchored on a cell; *tap fallback:* **tap a day/month cell** (the discoverable path) → animated zoom-in anchored on that cell. *Control fallback:* tap the **next inner segment** in the scope control (Year→Month→Day).
- **Zoom OUT** — *gesture:* pinch-IN, or a downward pull/rubber-band; *control fallback:* tap the **outer segment** (Day→Month→Year). The segmented control is the always-visible equivalent of every pinch.
- **Direction lock** — a pinch only commits to a direction once magnification clears a ~0.04 noise threshold; below that, the scope keeps scrolling (the gesture arbiter permits pinch + scroll simultaneously until lock, then freezes scroll).
- **Today control** — *tap* the nav-bar `calendar.circle` (off-today only) → scope-preserving recenter; *second tap on today* → progressive zoom one level in. The floating **Today pill** (`↩ Today`) is the day-scope's own recenter affordance.
- **Day paging** (in Day scope) — horizontal swipe, inset from the left edge to protect the system back-swipe; snap-to-day on release.

**Animations (durations / easing) — each with a Reduce-Motion fallback:**

| Moment | Curve / duration | Detail | Reduce-Motion fallback |
|---|---|---|---|
| **Cross-zoom settle** (`.navigationTransition(.zoom)` analog) | spring, settle **0.32s**, damping **0.9** | Inner scope scales from its **anchor-cell footprint** (`collapsedScale = max(cell.w / size.w, 0.06)`) to full + fades in (smoothstep 0.15→0.45); outer scope counter-magnifies into the same cell (`min(size.w/cell.w, 3.5)`) + fades out (smoothstep 0.3→0.75). Reads as **one continuous magnification**, anchored on the tapped/pinched cell. | **Cross-fade only** (opacity 0→1, no scale) at the same 0.32s. The DS notes reduced-motion honoring is currently aspirational on `WaxSeal`; here it MUST be specified — drop the scale/parallax, keep the cross-fade. |
| **Interactive pinch** | tracks finger 1:1 | magnification maps to `innerVisibility 0…1`; on release **commit-or-cancel** from rest progress (zoom-in commits >0.45, zoom-out commits <0.55) + fling velocity (>1.0/s force-commits). Interruptible/retargetable mid-animation. | n/a (direct manipulation) — but the cross-fade replaces the scale on the settle. |
| **Rubber-band reverse** | spring | an over-pinched or under-pulled gesture that doesn't meet commit threshold springs **back** to the origin scope (cancel path) at the same damping 0.9. | cross-fade back. |
| **Today pill show/hide** | spring, damping **0.8**, 0.3s | fade + scale 0.85→1 on appear (when leaving today), reverse on land. Hidden, not removed (no reflow). | fade only. |
| **Scope segment slide** | `.snappy` | selected-fill capsule slides between segments; mirrors `ViewModeSwitcher`. | instant fill swap. |
| **Snap-to-day** (Day pager) | spring | page settles to the nearest day on release. | instant settle. |

**Haptics (`.sensoryFeedback`) — intended, per platform brief; wire on the gesture milestones:**
- `.selection` on each **scope flick / segment change** (the "snap into the next zoom level" tick).
- `.selection` on **snap-to-day** in the Day pager.
- `.impact` on **detent / commit** of a zoom (the moment direction locks and commits).
- Respect the system haptic setting; never fire during the interactive (pre-commit) phase.

> Engineering note (faithful to current code): the cross-zoom, gesture arbitration, scope-preserving `jump(to:)`, and progressive Today are **implemented** in the UIKit container (`CalendarZoomController` / `ZoomGestureArbiter` / `CalendarContainerViewController`). `.sensoryFeedback` haptics and the explicit Reduce-Motion cross-fade are **specified-but-not-yet-wired** — this doc is their spec. The motion constants above (0.32 / 0.9, collapsed-scale 0.06, magnification cap 3.5, thresholds 0.04 / 0.45 / 0.55 / 1.0) are the real in-code values.

---

## iOS specifics

- **Dynamic Type** — relative text styles only (Fraunces titles `relativeTo .title2/.title3`; mono counts `relativeTo .footnote/.caption2`). At AX sizes, day-cell numbers stay legible and intensity bars keep their step; the scope-control labels truncate-with-min-width before clipping. Never clip a cell number.
- **Haptics** — `.sensoryFeedback(.selection, trigger: scopeKind)` and `(.selection, trigger: selectedDate)` on day snap; `.impact` on zoom commit. Honor Settings → Sounds & Haptics.
- **Context menus** — long-press a day cell → `contextMenu` (View day · Add event on this day · Jump here). Long-press the Today pill → "Jump to today (keep \(scopeName))".
- **Swipe actions** — N/A on the grid itself; the agenda rows inside the Day scope carry leading=complete (calm `--success`) / trailing-full=delete (`--danger`). Out of scope for this navigation surface.
- **VoiceOver** — every cell speaks **date + weekday + count + state**: e.g. "June 24, Wednesday, today, 4 events. Double-tap to open day." The scope control is one element: "Calendar scope, Month selected, adjustable — swipe up for Day, down for Year." The Today control: "Go to today, keeps Month view." Selected day/scope carry `.isSelected`. **Never color-only** — the TODAY clay ring is paired with the spoken "today" and a 1.5pt ring shape so it survives Reduce Transparency / color-blindness. The zoom transition announces the landed scope ("Day view, June 24") via `.accessibilityElement` post-settle; the animation itself is `.accessibilityHidden`.
- **Reduce Transparency** — the glass scope control / Today pill / tab bar fall back to a **solid warm `--surface-sunken` fill** with a 1pt `--border`, not Apple's frosted blur.

---

## ✦ Claude Design prompt (paste this)

```
SCREEN: Calendar — Scope zoom & affordances (Month scope, mid-zoom).
Render a single fixed iPhone 393×852pt @3x native iOS 26 screen — NOT responsive,
NOT a web page. Use the published "Kraft & Ink" design system and its named tokens
ONLY. No new colors, fonts, or gradients.

JOB: Show the Calendar tab in MONTH scope with the always-visible zoom affordance
controls, captured mid-transition as the user zooms INTO a day — so the year↔month↔day
"one continuous magnifiable surface" model is legible at a glance.

FRAME & CHROME (top → bottom):
1. iOS status bar: 9:41 left, battery/signal right, Dynamic Island reserved center.
2. Inline nav bar: Fraunces title "June 2026" (titleM, --text-primary) centered; a
   search glass-island icon (magnifyingglass, --primary) trailing.
3. SCOPE SEGMENTED CONTROL — a warm Liquid-Glass capsule on a --surface-sunken track,
   1pt --border. Three segments: "Year · Month · Day" (Public Sans label, 13pt). The
   "Month" segment is SELECTED = espresso --primary fill with --on-accent cream label;
   the other two are --text-secondary. This is the visible tap-fallback for pinch.
4. MONTH GRID on --background: a weekday eyebrow row (Mo Tu We Th Fr Sa Su) in JetBrains
   Mono (--text-secondary), a 1pt --separator rule, then a 7-column grid of day cells.
   Each cell = --surface paper, cut-paper radius 6, day number in JetBrains Mono. Encode
   busyness as a SINGLE-ACCENT espresso intensity ramp: a 1–2pt bar UNDER the number that
   grows darker/taller with event count (1 / 2 / 3 / 4+ events) — NOT colored dots, NOT a
   rainbow, NOT a lone monochrome dot.
   - Day 24 = TODAY: a clay --secondary 1.5pt RING around the number (this is the screen's
     ONE rationed clay moment), highest-intensity bar.
   - Seed real load: 18 Jun "Sprint planning", 20 Jun three events (Yoga / Groceries /
     Dad's birthday → top intensity), 27 Jun "Flight to Berlin 06:15".
5. ZOOM GHOST (the transition, frozen ~55% through): the tapped cell "24" is SCALING UP
   and lifting out of the grid toward fullscreen; the month grid behind it is slightly
   counter-magnified and fading; a faint Day-scope timeline ("Standup 09:30 · Q3 roadmap
   review 11:00 · Dentist 16:30") bleeds through underneath at low opacity. It must read
   as ONE magnification anchored on cell 24, not two stacked screens.
6. FLOATING TODAY PILL — bottom-leading, above the tab bar (~24pt up, ~20pt in from left):
   a warm Liquid-Glass capsule, "↩ Today" with an arrow.uturn.backward glyph + label in
   espresso --primary ink, lifted by a warm value-shadow (NOT a cold black float).
7. Bottom: 3-tab warm Liquid-Glass tab bar — Today / Calendar (active) / Settings — with a
   SEPARATED "+" action capsule. 34pt home-indicator gutter below.

COMPONENTS (by name): the scope control + Today pill are bespoke glass capsules (chrome);
day cells are letterpress CueCard-style paper tiles. NO WaxSeal and NO decisive CTA on this
screen (navigation surface — no commit action).

TYPE: Fraunces for the month title; JetBrains Mono for day numbers, weekday eyebrow, and the
ghost agenda times; Public Sans for the segment labels and Today pill. Fraunces only ≥17pt.

DEPTH: letterpress only — 1pt --border + hard value-cut shadow, BLUR RADIUS 0. The glass
capsules (scope control, Today pill, tab bar) are the ONLY frosted surfaces, re-tinted WARM
toward kraft/clay — never Apple cool blue.

STATE: render the default mid-zoom. Also note (as small side variants if space allows): an
empty month (numbers only, no intensity bars) and the Today pill hidden when on today.

ANTI-SLOP GUARDRAILS (hard):
- NO Inter / Helvetica / SF Pro — Fraunces + Public Sans + JetBrains Mono only.
- NO purple, NO blue accents, NO gradients, NO glassmorphism on the grid/cells, NO neon.
- NO generic evenly-spaced bento grid of equal cards; this is a real iOS calendar grid.
- NO pure #FFFFFF cards floating on white, NO pure #000000, NO soft blurred drop shadows.
- Honor Kraft & Ink EXACTLY: espresso carries structure; clay --secondary appears at most
  ONCE (the TODAY ring); selected segments fill espresso --primary, never clay; busyness is
  intensity of ONE accent, never a rainbow of dots.
- Native iOS patterns: inline nav bar, segmented control, floating glass tab bar, ≥44pt tap
  targets, 16pt margins, 34pt home gutter, Dynamic Island reserved.
- Don't say "modern / clean / sleek / beautiful" — render a typesetter's notebook, not a
  SaaS dashboard.
```
