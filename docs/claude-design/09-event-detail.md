# Event / Occurrence detail

One occurrence, inspected — leading with its single most-likely action (mark done), with edit / skip-this / delete-series within reach. A sheet over the calendar, in the Cron mould.

> Status in code: **exists** (`cue/Features/Calendar/TaskDetail/TaskDetailScreen.swift`, pushed today). This prompt designs the **intended** screen: same fields, same endpoints, but (a) re-cast as a **sheet** at `.medium`, (b) **leads with a Complete action** (today the app only completes via the day-card wax seal; the detail screen offers only Skip/Delete/Edit — closing that gap is the point), (c) surfaces **group color** (today the agenda spine uses espresso/olive structural color, not group color — this screen introduces the group hue), and (d) adds a **graceful AI context** strip that degrades cleanly. Mirror real field names and behaviors below.

---

## Design system (Kraft & Ink)

Use the published **"Kraft & Ink"** system and its tokens ONLY — no invented palette, fonts, gradients, or pure white/black surfaces. Reference everything by name.

**Color (opaque sRGB; semantic roles, never raw hex in app):**
- `--background #FFFFFF` — app canvas behind everything.
- `--surface #FAF6EF` — cards / rows (faint warm paper).
- `--surface-elevated #FEFCF8` — this **sheet's** fill (it's a top modal).
- `--surface-sunken #F1EADF` — recessed strips (the time/recurrence "ledger" band), grabber zone.
- `--primary #5A3A24` (espresso) — structural tint, key action fill, icons, the card spine.
- `--primary-pressed #43291A` — pressed primary.
- `--secondary #BE4A28` (clay) — **FILL ONLY**; the one rationed wax-seal "make it stick" moment. Here: the **Complete** decisive CTA fill + its wax seal. Used at most ONCE.
- `--accent-text #A53D22` — the ONLY clay allowed as **text / icons / thin rules** (AA-safe); used for the `.ghost` Edit label and the "this vs all" inline link.
- `--on-accent #FBF5EA` (cream) — ink on a primary/secondary fill.
- `--text-primary #2E211A` — body + headings.
- `--text-secondary #6E5C4C` — supporting / muted text.
- `--separator #D0BA98` — **decorative hairlines ONLY** (~1.88:1).
- `--border #8C7142` — **functional edges** (card outline, seal-well).
- `--success #466234` (olive) — completed / done state (the spine + check once sealed).
- `--warning #C9A24B` (brass) — pending / the inline "couldn't load recurrence" notice. **Place INK on it, never cream.**
- `--danger #A8331F` (brick) — Delete series (destructive).
- The **group color** (e.g. `#E27921`) is backend-supplied per `TaskGroup.color` — render it as a small swatch/dot + as the **card spine**, NOT as terracotta. It is data, not the rationed accent.

**More-accent discipline (hard rule):** terracotta `--secondary` is the one-hot moment — here, **Complete + its wax seal**, once. Olive = done, brass = pending, espresso = structure, group color = membership. Color presence, not a rainbow.

**Typography (3 bundled families — substitute via Google Fonts in web preview):**
- Display/headings: **Fraunces** (≥17pt only — NEVER dense labels).
- Body/labels: **Public Sans** (explicitly NOT Inter / SF Pro).
- Code/receipts: **JetBrains Mono** (dates, times, the time range — receipt voice).
- Ramp used here: `titleL` Fraunces 22 medium (-0.2) = occurrence title · `titleM` Fraunces 18 medium = section leads · `body` Public Sans 16 = notes · `bodyEmphasis` Public Sans 16 semibold = **button labels** · `callout` Public Sans 15 = recurrence summary / AI context · `label` Public Sans 13 medium (+0.3) = eyebrows / chip text / "RECURRING" badge · `code` JetBrains Mono 13 (+0.2) = the **time range** + date. Display reads tighter (negative tracking); receipts read wider (positive).

**Spacing (4pt grid):** `xs 4 · sm 8 · md 12 · lg 16` (default gap / card inner) `· xl 20` (between sections) `· xxl 24` (between groups) `· huge 48` (sheet bottom breathing). 16pt side margins.

**Radii (crisp cut-paper, never 16–20 squircle bubbles):** `chip 4` (rubber-stamp chips) · `small 6` (**default** — buttons, fields, the AI-context tile, the brass notice) · `medium 8` · `card 10` (cards) · `large 12` (the sheet itself).

**Depth ("letterpress, not float"):** the card = `.letterpress` (1pt `--border` stroke + hard value-cut shadow `--text-primary` 6%, **blur radius 0**, y:1). NO soft uniform drop shadows anywhere. System **Liquid Glass** is chrome-only — the grabber zone and any nav-bar island; re-tint it **warm** toward kraft/clay, never Apple's cool blue-grey.

**Components (by name):**
- **CueButton** — full-width, radius 6, padding v12/h16, label `bodyEmphasis`, press = 1pt downward letterpress offset (no scale/glow/shadow), `.easeOut(0.16)`. Variants used: `.decisive` (clay fill + cream — the ONE Complete CTA), `.secondary` (clear + 1pt border + espresso label — **Skip this occurrence**), `.destructive` (brick + cream — **Delete series**), `.ghost` (clear + `--accent-text` clay label — **Edit**).
- **CueCard** — fill `--surface`, radius 10, `.letterpress`; optional `--surface-sunken` header strip with a 1pt `--separator` bottom rule.
- **CueChip** — 4pt rubber-stamp rectangle, NEVER a pill, no dot. Unselected = `--surface` + `--text-secondary` + 1pt border; selected = `--primary` espresso fill + cream (deliberately NOT clay). Used for the "This occurrence / All occurrences" scope toggle.
- **WaxSeal** — irregular hand-pressed blob (16 vertices, fixed jitter, NOT a clean circle). Unstamped = dashed "seal-well" (1.5pt `--border`, dash 4/4, @0.9). Stamped = `--secondary` clay fill + `--primary-pressed` 40% rim (multiply) + centered cream `checkmark`. The signature mark of the **Complete** moment.
- **CueAvatar** — not used here.

---

## Frame & platform

Single fixed iPhone **393 × 852 pt @3x**, **NOT responsive** — a native iOS 26 screen, not a web page.

- **Presentation:** a **sheet** over the Calendar / Today tab, `.presentationDetents([.medium, .large])`, **opened at `.medium`**, grabber visible (`.presentationDragIndicator(.visible)`), `.presentationBackgroundInteraction(.enabled(upThrough: .medium))` so the calendar dims-but-stays-alive beneath. Sheet fill = `--surface-elevated`, corner `large 12`. Expands to `.large` on drag or when notes/recurrence overflow.
- **Status bar / Dynamic Island:** the sheet sits below them; the dimmed calendar behind keeps the real status bar (time + battery) and reserves the Dynamic Island. No content under the island.
- **Sheet chrome:** a compact inline header row INSIDE the sheet (not a system nav bar): leading **Done/Close** (`xmark`, `--text-secondary`), centered nothing, trailing **Edit** (`.ghost` text button, `--accent-text`). The grabber sits above it in the `--surface-sunken` zone.
- **Safe areas:** 16pt side margins; respect the **34pt home-indicator gutter** — the primary **Complete** CTA floats in the **bottom thumb zone** just above it.
- **One-handed reach:** the single most-likely action (**Complete**) is the lowest, largest, warmest target. Destructive **Delete** is deliberately highest-friction (last, with a confirmation dialog).

---

## Layout

Top → bottom (a single `ScrollView`; the Complete CTA is pinned to the bottom safe-area inset, not scrolled).

Real content: a recurring weekly task **"Stand-up — Mobile squad"** in group **Work** (group color `#5A3A24`-adjacent espresso… no — use a distinct group hue `#3E6B57` sage for Work), Wed 25 Jun, 09:30–09:45, recurring weekly, with a one-line note.

```
┌─────────────────────────────────────────────┐
│            ▁▁▁  (warm glass grabber)          │  ← --surface-sunken zone
│  ✕                                     Edit   │  ← Close (muted) · Edit (.ghost clay)
├─────────────────────────────────────────────┤
│ ▏ ● Work          ⟳ RECURRING                 │  ← group dot (sage) + name · badge (label)
│ ▏                                             │
│ ▏ Stand-up — Mobile squad                     │  ← titleL Fraunces, espresso spine ▏left
│ ▏ ──────                                       │  ← 44×2 clay rule (the only structural clay tick)
│                                               │
│  ◷  Wed 25 Jun · 09:30 – 09:45                │  ← clock icon + JetBrains Mono time range
│  ⟳  Every week on Wednesday · until 31 Dec    │  ← recurrence summary (callout), from GET /tasks/:id
│                                               │
│  ▭ note.text  Async-first; skip if you're     │  ← notes (body), only if non-empty
│              shipping the build.              │
│                                               │
│ ┌───────────────────────────────────────────┐ │  ← AI CONTEXT tile (graceful, dismissible)
│ │ ✦  Cue   ·   Leave by 09:20                │ │  ← --surface card, sparkle in --accent-text
│ │    11 min walk from home · light rain      │ │  ← callout, --text-secondary. Degrades cleanly.
│ └───────────────────────────────────────────┘ │
│                                               │
│  Applies to                                   │  ← label eyebrow (recurring only)
│  [ This occurrence ]  [ All occurrences ]     │  ← CueChip pair, "This" selected (espresso)
│                                               │
│  ⤼ Skip this occurrence    (.secondary)       │  ← outlined espresso, recurring only
│  🗑 Delete series          (.destructive)      │  ← brick fill, cream, confirm dialog
│                                               │
│····(scroll)···········································│
└─────────────────────────────────────────────┘
   ┌─────────────────────────────────────────┐    ← pinned, bottom thumb zone
   │  ⬗  Mark done                            │    ← CueButton .decisive (clay) + WaxSeal seal-well glyph
   └─────────────────────────────────────────┘
              ⎯⎯⎯ (34pt home gutter) ⎯⎯⎯
```

**Region by region:**
1. **Grabber + header** — warm-glass `--surface-sunken` zone, drag indicator; Close (`xmark`, muted) left, **Edit** (`.ghost`, `--accent-text`) right. Edit is **disabled** until the authoritative series (`GET /tasks/:id`) has loaded — editing off a failed load could wipe the recurrence rule (real landmine from `TaskDetailScreen`).
2. **Header block** — leading **espresso card spine** (4pt). A small **group color dot** + group name "Work" (`label`), and on the same row, the **`⟳ RECURRING`** badge (`label`, `--text-secondary`) when `isRecurring`. Below: the occurrence **title** in `titleL` Fraunces, then a **44×2 clay rule** (`--secondary`) — the one tiny structural clay tick (it is a 2pt rule, not a fill region, so it does not spend the rationed seal moment).
3. **Time band** — `◷` clock icon (`--primary`) + the **time range in JetBrains Mono** `code`: `Wed 25 Jun · 09:30 – 09:45`. All-day variant: `Wed 25 Jun · All day`.
4. **Recurrence summary** — only when `isRecurring`. `⟳` icon + human summary (`callout`, `--text-secondary`) like **"Every week on Wednesday · until 31 Dec"**, sourced from `GET /tasks/:id → recurrence`. While that fetch is in flight: a small inline `ProgressView` tinted `--primary`. On failure: the brass notice (see states).
5. **Notes** — only when notes are non-empty (trimmed): `note.text` icon + `body`, multi-line, `fixedSize` vertical so it never clips.
6. **AI context tile** — a `--surface` `CueCard` (radius `small 6`): a `✦`/`sparkles` glyph in `--accent-text`, the word **"Cue"** in `label`, then a one-line brief like **"Leave by 09:20 — 11 min walk from home · light rain."** Travel/weather. **Degrades cleanly**: if no context, the tile is simply **absent** (no skeleton, no "unavailable" copy). Dismissible with a small `xmark`.
7. **Scope toggle (recurring only)** — `Applies to` eyebrow + a **CueChip pair**: `This occurrence` (selected, espresso fill) / `All occurrences`. Drives whether Skip/Delete target the instance or the series.
8. **Secondary actions** — **Skip this occurrence** (`.secondary`, recurring only) then **Delete series** (`.destructive`, brick). Delete always confirms via `.confirmationDialog`.
9. **Primary CTA (pinned)** — **`Mark done`** as `CueButton .decisive` (clay fill, cream label) with a small **WaxSeal** glyph (seal-well → stamped on tap). This is the single rationed wax-seal moment. For a **pure event** (`requiresCompletion == false`) there is **no Complete CTA** — the pinned slot instead shows a calm `.secondary` **"Add to today"**/dismiss, and the seal moment is omitted entirely (events can't be completed).

**The ONE wax-seal / clay moment:** the **Mark done** decisive button + its WaxSeal. The 44×2 clay rule under the title is a hairline tick, not a fill. Everything else (group dot, spine, done-state) uses espresso / olive / group hue / brass — never terracotta.

---

## Data & states

Bound to the real backend shapes (see `OccurrenceDTO`, `ScheduleEvent`, `TaskDTO`):

- **Title** → `OccurrenceDTO.title` (effective per-instance; may be an `overrideTitle`).
- **Time range** → `occurrenceStart` / `occurrenceEnd`. Format `Wed 25 Jun · 09:30 – 09:45` (mono). All-day → `OccurrenceDTO.isAllDay == true` → `Wed 25 Jun · All day` (no end time).
- **Notes** → `OccurrenceDTO.notes` (trim; hide section when empty).
- **Group color + name** → `TaskGroup.color` (hex, e.g. `#3E6B57`) + `TaskGroup.name`, joined via `groupId`; fall back to `Calendar.color` / no dot if ungrouped.
- **Recurring badge** → `OccurrenceDTO.isRecurring`.
- **Recurrence summary** → `GET /tasks/:id` → `TaskDTO.recurrence` (`RecurrenceRuleDTO`), rendered via `humanSummary` ("Every 2 weeks on Mon, Wed", "Every week on Wednesday · until 31 Dec").
- **Occurrence identity** → `(seriesId, originalStart)`. `originalStart` is the **stable exception key**; `occurrenceStart` is effective/display-only — **never conflate them** in requests.

**Actions → endpoints (exact):**
- **Complete** → `PATCH /tasks/:id/completion` body `SetCompletionRequest { isCompleted: Bool, occurrenceStart: String? }`. For a recurring instance, `occurrenceStart` = **`originalStart`** as a **fractional-seconds ISO** string; for a one-off, omit it (whole-task path). Trust the server's authoritative `completedAt` back (clock-skew safe). Optimistic: stamp the seal immediately, revert on failure.
- **Edit** → opens the Edit sheet (`10-event-edit.md`), `PATCH /tasks/:id`. Requires the loaded `seriesDTO`.
- **Skip this occurrence** → `POST /tasks/:id/skip` body `{ occurrenceStart: <originalStart, fractional ISO> }`. Recurring only.
- **Delete series** → `DELETE /tasks/:id` → `DeletedIDResponse`. Removes all local occurrences + resyncs affected months.

**States:**
- **Default (recurring task):** all sections present, "Mark done" CTA, scope chips visible.
- **Default (one-off task):** no recurrence section, no scope chips, no Skip; just Edit / Delete / Mark done.
- **Default (pure event):** no Complete (no seal), no Skip-only-vs-series distinction beyond Delete; CTA slot = calm dismiss.
- **Already completed:** spine + check turn **olive `--success`**, title gets a single strikethrough, card at ~0.62 opacity; the CTA flips to a `.secondary` **"Mark not done"** (clay seal NOT shown when undoing — undo is calm, not a celebration).
- **Loading recurrence:** inline small `ProgressView` (`--primary`) in the recurrence row; rest of screen is already populated from the passed occurrence (no full-screen spinner — the occurrence data arrives with the tap).
- **Recurrence load failed:** an inline **brass** notice (`--warning` @0.12 fill, 1pt `--warning` @0.4 border, radius `small`): `⚠ Couldn't load recurrence details` + a **Retry** (`label`, `--accent-text`). **Edit stays disabled** in this state (guard against clearing the rule). INK on brass, never cream.
- **Action error (complete/skip/delete):** revert optimistic change + a **NotificationBanner** (`.error`, brick rail) — transient, not a full-page error.
- **Offline:** Complete is **optimistic** (seal stamps, queued); Skip/Delete present a banner "You're offline — try again when connected" and stay disabled until reachable. AI-context tile is simply absent offline (degrades cleanly).
- **Long title:** wraps to ≤3 lines in `titleL`, never truncated mid-sheet; sheet auto-grows toward `.large`.
- **AI context absent / partial:** tile omitted entirely (no skeleton); if only travel known, show just "11 min walk from home" — no empty weather slot.

---

## Interactions & motion

- **Present / dismiss:** sheet slides up to `.medium`; the calendar behind dims (background interaction enabled up through medium). Drag the grabber to `.large`. Swipe-down or Close dismisses. Reduce Motion → the slide becomes a **cross-fade** of the sheet at its medium height; no parallax on the backdrop.
- **Mark done (the signature):** tap → optimistic completion. The **WaxSeal stamps**: `.spring(response: 0.42, dampingFraction: 0.62)`, scale 0.4→1, opacity 0→1, rotation −8°→0° (~450ms settle). The spine + title cross-fade to olive/strikethrough over `.easeOut(0.16)`. **Reduce Motion fallback:** no spring/rotation — the seal **cross-fades** from seal-well to stamped (opacity only), spine recolors instantly. `.sensoryFeedback(.success)` fires either way.
- **Button press:** all CueButtons depress 1pt downward (`.easeOut(0.16)`) — no scale, glow, or shadow. The `.decisive` Complete adds the `--primary-pressed` multiply overlay @0.22 ("ink soaking in").
- **Scope chip toggle:** `This occurrence ↔ All occurrences` fill/ink swap, `.easeOut(0.16)`, `.sensoryFeedback(.selection)`.
- **Skip:** button shows an inline `ProgressView`; on success the sheet dismisses (the occurrence is gone from the day). Reduce Motion unaffected (no decorative motion here).
- **Delete:** opens `.confirmationDialog` ("Delete this entire series? This removes every occurrence."); destructive confirm → spinner on the brick button → dismiss. `.sensoryFeedback(.impact)` on confirm.
- **AI tile dismiss:** tap `xmark` → tile collapses with `.snappy` height + opacity; Reduce Motion → instant removal.
- **Recurrence retry:** tapping Retry re-runs `GET /tasks/:id`; spinner replaces the brass notice in place.

The **160ms ease-out** (every press/toggle) and the **single seal spring** are the two recurring signatures — do not invent new curves.

---

## iOS specifics

- **Dynamic Type:** all roles are relative type styles — title, summary, notes scale. At AX sizes the action buttons stack full-width (already are) and the time band wraps the date above the range rather than clipping. Never fix point sizes.
- **Haptics (`.sensoryFeedback`):** `.success` on Mark done / completion · `.selection` on scope-chip toggle and detent snap · `.impact` on Delete confirm and Skip commit. Respect the system haptic setting.
- **Context menu:** long-press the title region exposes Complete / Edit / Skip / Delete as `contextMenu` items (mirror of the visible buttons) for power users.
- **Swipe actions:** N/A on a detail sheet (this *is* where a day-card's trailing swipe leads); the day list owns leading=complete / trailing-full=delete.
- **Confirmation:** Delete always routes through `.confirmationDialog` with a `.destructive` role button + Cancel; never a one-tap destroy.
- **VoiceOver labels:**
  - Title element: "Stand-up — Mobile squad, recurring task, group Work."
  - Time: "Wednesday 25 June, 9:30 to 9:45 AM" (read the resolved range, not the mono glyphs).
  - Recurrence: "Repeats every week on Wednesday until 31 December."
  - Complete button: "Mark done" / when completed "Mark not done"; state announced via `.accessibilityValue("completed")`. The WaxSeal itself is `.accessibilityHidden(true)` (decorative; the button carries the label).
  - Scope chips: "Applies to: This occurrence, selected" / "All occurrences."
  - AI tile: "Cue suggestion. Leave by 9:20, 11 minute walk from home, light rain." Dismiss button: "Dismiss suggestion."
  - Group dot: folded into the title label (color is never the sole signal — the group **name** is spoken).
  - Never color-only meaning: done state = strikethrough + olive + the word "completed"; recurring = the badge text, not just the icon.

---

## ✦ Claude Design prompt (paste this)

```
Design a single native iOS 26 SHEET screen: "Event / Occurrence detail" for CUE, an AI-assisted
calendar + Telegram-assistant app. Use the published "Kraft & Ink" design system and its tokens
ONLY — no new colors, fonts, gradients, or pure white/black surfaces.

FRAME: Fixed iPhone 393×852pt @3x, NOT responsive. Render as a SHEET at the .medium detent over a
dimmed live calendar; sheet fill --surface-elevated, corner radius 12 (large), a warm Liquid-Glass
grabber zone (--surface-sunken) at top with a visible drag indicator. Respect the 34pt home-
indicator gutter; 16pt side margins; all tap targets ≥44pt. The status bar + Dynamic Island belong
to the dimmed calendar behind the sheet.

PURPOSE: Inspect ONE occurrence and lead with its single most-likely action (mark done), with edit,
skip-this-occurrence, and delete-series within reach. Cron's "lead with the likely action" pattern.

LAYOUT (top → bottom):
  1. Grabber zone (warm glass), then a compact in-sheet header row: Close (xmark, --text-secondary)
     left; Edit (ghost button, --accent-text clay text) right.
  2. Header block with a 4pt espresso (--primary) card spine on the left: a small GROUP-COLOR dot
     (sage #3E6B57) + group name "Work" in label type, and a "⟳ RECURRING" badge (label,
     --text-secondary) on the same row. Below: the title "Stand-up — Mobile squad" in Fraunces
     titleL (22, medium). Below that, a 44×2pt clay (--secondary) rule tick.
  3. Time band: a clock icon (--primary) + the time range in JetBrains Mono (code, 13):
     "Wed 25 Jun · 09:30 – 09:45".
  4. Recurrence summary (icon ⟳ + callout, --text-secondary): "Every week on Wednesday · until 31 Dec".
  5. Notes (note.text icon + Public Sans body): "Async-first; skip if you're shipping the build."
  6. An AI-CONTEXT tile — a --surface CueCard, radius 6: a sparkle glyph in --accent-text, the word
     "Cue" (label), then one line: "Leave by 09:20 — 11 min walk from home · light rain." Small
     dismiss xmark. (It must look like it can simply be absent — graceful degrade.)
  7. "Applies to" eyebrow (label) + a CueChip pair: [This occurrence] selected (espresso fill +
     cream) / [All occurrences] unselected.
  8. CueButton .secondary "Skip this occurrence" (clear + 1pt --border + espresso label), then
     CueButton .destructive "Delete series" (--danger brick fill + cream).
  9. PINNED in the bottom thumb zone, above the home gutter: CueButton .decisive "Mark done"
     (--secondary clay fill + cream label) with a small WaxSeal seal-well glyph at its leading edge.

COMPONENTS (by name): CueCard (--surface, radius 10, letterpress depth = 1pt --border + hard
value-cut shadow at --text-primary 6%, BLUR RADIUS 0, y:1), CueButton (.decisive/.secondary/
.destructive/.ghost; full-width, radius 6, label Public Sans 16 semibold, press = 1pt downward
letterpress offset), CueChip (4pt rubber-stamp rectangle, NEVER a pill, no dot; selected = espresso
fill + cream), WaxSeal (irregular hand-pressed clay blob, NOT a clean circle; here a dashed
seal-well that stamps to clay + cream check on Mark done).

REAL CONTENT (verbatim, no lorem, no "Event 1"): a recurring weekly task "Stand-up — Mobile squad"
in group "Work" (sage dot), Wed 25 Jun 09:30–09:45, "Every week on Wednesday · until 31 Dec",
note "Async-first; skip if you're shipping the build.", AI line "Leave by 09:20 — 11 min walk
from home · light rain."

STATES to render alongside the default: (a) COMPLETED — spine + check olive --success, title
single-strikethrough, card ~0.62 opacity, CTA flips to a calm .secondary "Mark not done" (no clay
seal on undo); (b) RECURRENCE-LOAD-FAILED — an inline brass (--warning) notice with INK text and an
--accent-text "Retry", Edit disabled; (c) AI-CONTEXT-ABSENT — the tile simply gone, no skeleton.

MOTION: Mark done stamps the WaxSeal with spring(response 0.42, damping 0.62) — scale 0.4→1,
rotation −8°→0° (~450ms); spine + title cross-fade to olive/strikethrough over 160ms ease-out.
Reduce-Motion fallback: seal cross-fades opacity-only, spine recolors instantly, no rotation.
Buttons depress 1pt on press (160ms ease-out). Sheet present = slide to medium; Reduce-Motion =
cross-fade, no backdrop parallax. Haptics: .success on Mark done, .selection on scope chips,
.impact on Delete confirm.

iOS PATTERNS: sheet detents [.medium, .large] open at .medium with background interaction enabled;
.confirmationDialog on Delete ("Delete this entire series?"); context menu on the title mirrors the
action set; VoiceOver speaks date+weekday+state and never relies on color alone (done = strikethrough
+ "completed", recurring = badge text). Dynamic Type: relative styles, buttons stack at AX sizes,
nothing clips.

ANTI-AI-SLOP GUARDRAILS (hard): NO Inter / Helvetica / SF Pro — pin Fraunces (titles ≥17pt),
Public Sans (body/labels), JetBrains Mono (the time range / dates). NO purple, NO blue accents,
NO gradients, NO glassmorphism on the content cards (glass is chrome-only and re-tinted WARM, never
Apple cool blue). NO soft uniform drop shadows — letterpress only (1px border + hard value-cut,
blur 0). NO pure #FFFFFF surface-on-white, NO pure #000000. NO generic evenly-spaced bento grid —
this is a one-column typesetter's sheet that breathes. Crisp 4–12px cut-paper corners, never
16–20px squircle bubbles. Selected chips fill espresso --primary, NOT clay. The terracotta wax seal
appears EXACTLY ONCE — on "Mark done"; the group color is sage data, the spine/structure is
espresso, done is olive, the warning is brass. Color presence, not a rainbow. Do not say
"modern / clean / sleek / beautiful". Honor Kraft & Ink exactly; native iOS, not a web page.
```
