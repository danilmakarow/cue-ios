# Search

Find any task or occurrence by typing — match across `Task.title` and `Task.notes`, filter by group, and jump straight to the matching day. Visual base: **Kraft & Ink** (use the published CUE design system; invent nothing).

> **Nav decision:** Search is **NOT a tab.** It is a nav-bar **glass island** (a `magnifyingglass` icon) reachable from **Today** and **Calendar**. Tapping it presents this screen (a full-cover search surface with its own search field), not a tab switch. The 3-tab bar stays **Today / Calendar / Settings** + separated "+".

---

## Design system (Kraft & Ink)

Literal restatement of the tokens this screen uses, copied from `01-DESIGN-SYSTEM.md`. **Use these only — do not invent palette, fonts, or shadows.**

**Color (opaque sRGB, by role):**
- `--background #FFFFFF` — app canvas behind everything (the result list scrolls on the white page).
- `--surface #FAF6EF` — result-row cards (faint warm paper), the recent-searches rows.
- `--surface-elevated #FEFCF8` — the search-field fill at the top (it reads as an elevated entry surface).
- `--surface-sunken #F1EADF` — the group-filter chip rail's selected-day-style backing is NOT used; reserved here for the recent-searches section header strip and the keyboard-attached scope band.
- `--primary #5A3A24` (espresso) — structural tint: the result-row spine, row titles' lead, the active-clear glyph, the SELECTED filter chip fill, the search glyph in the field.
- `--secondary #BE4A28` (clay) — **FILL ONLY, rationed to ONCE per screen**: the result-count "receipt" tab/marker that confirms a successful match — the single "found it / make it stick" moment. Nothing else on this screen is clay-fill.
- `--accent-text #A53D22` — the only clay allowed as text/icon/thin-rule (AA). Used for the recurring-badge glyph tint and the "in <Group>" inline attribution if a clay micro-emphasis is wanted; otherwise reserved.
- `--on-accent #FBF5EA` (cream) — ink on the espresso filter-chip fill and on the clay result-count marker.
- `--text-primary #2E211A` — result titles, the typed query text, recent-query text.
- `--text-secondary #6E5C4C` — the result row's date/time receipt line, group name, placeholder text, "no results" copy, recent-section label.
- `--separator #D0BA98` — decorative hairline under the filter rail / between recent rows ONLY (never a real edge).
- `--border #8C7142` — functional edges: the search-field outline, the unselected filter-chip border, the result-card outline.
- `--success #466234` (olive) — completed occurrences (struck title + olive spine), matching the agenda row's done state. Status lives on a SHAPE channel, not by stealing the accent.
- `--warning #C9A24B` (brass) — reserved; not used on this screen.

**Typography (3 bundled families — never Inter / SF Pro):**
- **Fraunces** (display, titles ≥17pt): `title-M` 18 medium (−0.2) = each result row's task title; `title-L` 22 medium (−0.2) only if a large nav title is shown (this screen prefers the inline search field, so `title-L` is optional/absent).
- **Public Sans** (body/labels — NOT Inter): `body` 16 regular = the typed query in the field; `callout` 15 regular = the matched-notes snippet preview; `label` 13 medium (+0.3) = filter-chip text + the recent-searches section eyebrow; `caption` 12 regular = empty/recent helper copy.
- **JetBrains Mono** (receipt voice — dates/counts/times): `code` 13 regular (+0.2) = each result row's date+time receipt line ("Wed Jun 24 · 9:00–9:30"); `code-small` 11 medium (+0.8) = the clay result-count marker ("7 RESULTS") and any group-count micro-labels.

**Spacing (4pt grid):** `xxs 2` (glyph-to-label hug), `xs 4` (chip-to-chip in the filter rail), `sm 8` (within-row vertical gaps, chip insets), `md 12` (title-to-receipt, search-field inner padding), `lg 16` (default gap; card inner padding; side margins), `xl 20` (between result rows), `xxl 24` (section padding above the recent block), `huge 48` (empty-state breathing room).

**Radius (cut-paper, never squircle bubbles):** `chip 4` = filter chips (rubber-stamp rectangle, never a pill); `small 6` = the search field; `card 10` = result-row cards. No 16–20pt bubbles.

**Depth ("letterpress, not float"):** result cards use `.letterpress` (1pt `--border` + hard value-cut shadow `--text-primary` 6% y:1, **blur 0**). The search field is flat with a 1pt `--border`. The nav-bar **glass island** that hosts Search and the floating tab bar are **Liquid Glass** (chrome only), warm-tinted. **No soft drop shadows anywhere.**

**Components used:** `CueChip` (the group-filter rail: selected = espresso `--primary` fill + cream, unselected = `--surface` + `--border` — selection NEVER clay), result rows styled exactly like the **`DayAgendaCell`** paper sheet (espresso/olive spine + Fraunces title + mono receipt time + optional wax-seal toggle for tasks), `ErrorStateView`/`ContentUnavailableView` for empty + no-results, `LoadingStateView` (warm-scrim inline) for the in-flight filter. **No new WaxSeal commit on this screen** — completing a task from a result row reuses the existing agenda wax-seal toggle (it is not a new ritual); the one rationed clay moment is the **result-count receipt marker**.

---

## Frame & platform

- **Single fixed iPhone frame, 393×852pt @3x. NOT responsive** — a native iOS screen, not a web page.
- iOS status bar (time left, battery/Wi-Fi right); **Dynamic Island reserved** at top center; top safe area ~59pt; **34pt home-indicator gutter** at the bottom; **16pt side margins**.
- **Presentation:** Search opens from the **nav-bar glass island** on Today/Calendar (a `magnifyingglass` icon, warm Liquid Glass). It presents as a **dedicated search surface** (`.fullScreenCover`-style, with a leading **"Cancel"** and the keyboard up on appear) — it owns its own `.searchable`-style field, it is not a `TabView` route. On dismiss the user returns to the originating tab exactly where they left it.
- **Nav chrome:** a top **search field** (not a large title) spanning the content width, with a leading **search glyph** and a trailing **clear (×)** when non-empty, and a trailing **"Cancel"** text button outside the field. Directly beneath it, a **horizontal group-filter chip rail** (`CueChip`s) with a 0.5pt `--separator` hairline below it. The **3-tab tab bar is hidden** while the search cover is up (full-screen capture surface) — Search is reached FROM a tab, it does not sit beside the tabs.
- **One-handed reach:** the search field is at the top (where the keyboard caret expects it), but the **primary scanning + tapping happens in the lower two-thirds** — result rows are 44pt+ tap targets, and the group-filter chips sit within thumb reach just under the field. Keyboard "Search" key submits; the list lives in the thumb zone above the keyboard.

---

## Layout

Top → bottom, with realistic CUE content (real-sounding tasks/groups, no lorem):

```
┌─────────────────────────────────────────────┐
│ ●●●   9:41              Dynamic Island   ▾ 􀙇 │  status bar
├─────────────────────────────────────────────┤
│ ⚲  rent                          ✕   Cancel  │  search field (elevated) + clear + Cancel
├─────────────────────────────────────────────┤
│ [ All ] [ Work ] [Bills] [Errands] [Travel]  │  group-filter chips (CueChip rail)
│ ─────────────────────────────────────────── │  hairline (separator)
├─────────────────────────────────────────────┤
│  ╔ 7 RESULTS ╗   ← clay receipt marker        │  the ONE rationed clay moment
│                                              │
│ ┃ Pay rent                         ⟳   ◯    │  result card: espresso spine, Fraunces title,
│ ┃ Wed Jun 24 · all-day · Bills           │      recurring badge ⟳, wax-seal toggle ◯
│                                              │
│ ┃ Pay rent                         ⟳   ◯    │
│ ┃ Thu Jul 24 · all-day · Bills           │
│                                              │
│ ┃ Rent review with landlord        ◯        │  notes-match: snippet preview below
│ ┃ Mon Jun 30 · 18:00–18:30 · Personal    │
│ ┃ "…confirm rent increase clause…"        │      matched-notes snippet (callout)
│                                              │
│ ┃ Car rental pickup                       │  (event, no completion → no seal)
│ ┃ Fri Aug 15 · 10:00 · Travel            │
│                                              │
│ ┃ ̶R̶e̶n̶t̶ ̶a̶ ̶v̶a̶n̶ ̶f̶o̶r̶ ̶m̶o̶v̶e̶            ✓    │  completed: olive spine + strikethrough
│ ┃ Sat May 31 · 08:00 · Errands           │
│                                              │
│ … (scrolls) …                                │
├─────────────────────────────────────────────┤
│              (no tab bar while searching)     │  Search is a cover, not a tab
└─────────────────────────────────────────────┘
            (34pt home-indicator gutter)
```

1. **Search field** — full-width on `--surface-elevated`, `small 6` radius, 1pt `--border`, inner padding `md 12`. Leading **`magnifyingglass`** glyph in `--primary`; the typed query "rent" in **Public Sans `body`** `--text-primary`; a trailing **clear (×)** glyph in `--text-secondary` shown only when non-empty. A **"Cancel"** text button (`--accent-text`, `label` role) sits to the right of the field, outside it, to dismiss the cover. Keyboard is up on appear; the **return key reads "Search"**.

2. **Group-filter chip rail** — a horizontally scrolling row of `CueChip`s built from `GET /task-groups` plus a leading **"All"** chip (default selected). Selected = espresso `--primary` fill + cream `--on-accent` (deliberately NOT clay, so it never competes with the receipt marker); unselected = `--surface` + `--text-secondary` + 1pt `--border`. Chip text = `label` role. A 0.5pt `--separator` hairline runs below the rail. Real chips: **All · Work · Bills · Errands · Travel · Family · Personal** (each tinted ONLY by selection state, not by group color — group color appears on the rows, status/identity stays on a shape channel here).

3. **Result-count receipt marker** — the **single rationed clay moment**: a small **rubber-stamp tab** in clay `--secondary` fill with cream `--on-accent` text in JetBrains Mono `code-small`, reading e.g. **"7 RESULTS"** (or "1 RESULT"). It confirms the match — the "found it" beat — and is the only clay-fill on the screen. It sits left-aligned above the first result, scrolling with the list.

4. **Result rows** — each row is a **`DayAgendaCell`-style paper sheet** (`--surface`, `card 10`, `.letterpress` depth), top→bottom inside the card:
   - a **left spine** (4pt): espresso `--primary` for open items, **olive `--success`** for completed (carries state without spending clay).
   - **task title** in **Fraunces `title-M`** `--text-primary` (strikethrough + 62% card opacity when completed), with a leading **recurring badge** (`arrow.triangle.2.circlepath` / "⟳") tinted `--accent-text` when `isRecurring`.
   - a **mono receipt line** in JetBrains Mono `code` `--text-secondary`: weekday + date + time (or "all-day") + " · " + group name, e.g. **"Wed Jun 24 · all-day · Bills"**, **"Mon Jun 30 · 18:00–18:30 · Personal"**.
   - if the match was on **notes** (not title), a one-line **`callout`** snippet preview with the matched fragment in quotes and an ellipsis, e.g. **"…confirm rent increase clause…"**.
   - a trailing **wax-seal toggle** (the existing agenda seal: empty bordered "seal-well" when open, clay seal + cream check when done) — **shown only for tasks** (`requiresCompletion == true`); pure events show no seal. (This reuses the agenda's existing seal; it is NOT a second rationed clay moment — it is the same completion control the user already knows.)

   Real content used above (verbatim, real CUE-style; query = "rent"):
   - **Pay rent** — recurring ⟳, all-day, group "Bills", Jun 24 + Jul 24 occurrences (title match)
   - **Rent review with landlord** — Jun 30 18:00–18:30, group "Personal" (title match)
   - **Car rental pickup** — Aug 15 10:00, group "Travel", event (no seal)
   - **Rent a van for move** — completed (olive spine + strikethrough), May 31 08:00, group "Errands"
   - *(notes-match example)* a task whose **notes** contain "confirm rent increase clause" surfaces with the quoted snippet.

5. **Recent searches (empty-query state)** — when the field is empty, the body shows a **"RECENT"** eyebrow (`label`, `--text-secondary`, on a `--surface-sunken` section strip) over a short list of recent query rows ("rent", "dentist", "sprint review", "flight"), each a tappable `--surface` row with a leading `clock.arrow.circlepath` glyph and a trailing `×` to remove. No clay here (the receipt marker only appears once there are results).

**The single rationed clay/wax moment:** the **result-count receipt marker** ("7 RESULTS"). The per-row wax-seal toggles are the pre-existing agenda completion control, not new accent spend.

---

## Data & states

v1 is a **client-side filter over the already-synced window** — there is **no dedicated BE search endpoint yet** (flagged below). Results are unified **occurrences**, matching how the rest of the app reads the feed.

- **Source data** — the synced occurrence set the calendar already holds: `OccurrenceVM { id, seriesId, occurrenceStart, originalStart, title, notes, startAt, endAt, requiresCompletion, completedAt, isRecurring }` (the on-device value model fed from `GET /tasks` / the SwiftData cache via `CalendarDataAdapter`). No new fetch on keystroke — filter the in-memory window.
- **Match predicate** — case- and diacritic-insensitive `contains` over **`title`** OR **`notes`** (`Task.title` / `Task.notes`). Title matches rank above notes matches; within a rank, sort ascending by `startAt`. A notes-only match shows the quoted snippet around the hit.
- **Group filter** — the chip rail filters occurrences by **`groupId → TaskGroup`** (`EventTaskGroup.id`/`.name`/`.colorHex`), built from `GET /task-groups` / the local `@Query(sort: \EventTaskGroup.sortOrder)`. "All" = no group constraint. The receipt count reflects the post-filter result set.
- **Result row receipt line** — weekday + date from `occurrenceStart` (fallback `startAt`); time from `startAt`–`endAt` (or "all-day" when the task is all-day, which sorts first); group name from `groupId → EventTaskGroup.name`. Group **color** (`EventTaskGroup.colorHex` via `Color(hex:)`) tints the recurring badge or a small leading group dot — falling back to espresso `--primary` when nil/malformed.
- **Recurring badge** — `OccurrenceVM.isRecurring` → the `arrow.triangle.2.circlepath` glyph (shape channel, never color-only).
- **Completion** — `OccurrenceVM.completedAt != nil` → olive spine + strikethrough + 62% opacity, mirroring `DayAgendaCell`. Tapping the seal toggles via the existing `PATCH /tasks/:id/completion {isCompleted, occurrenceStart}` (address by `seriesId` + `originalStart`, NOT the display `occurrenceStart`).
- **Tap a result** — opens **Event/Occurrence detail** (`09-event-detail.md`) for `(seriesId, originalStart)`; the search cover stays in the back stack so dismissing detail returns to results.

**States:**
- **Empty query (default on open)** — show **Recent searches** (or, first-run with no history, a calm `ContentUnavailableView`: `magnifyingglass`, "Search your tasks", caption "Find anything by title or notes — filter by group."). Keyboard up, no clay marker.
- **Loading / filtering** — client filter is effectively instant; for the first cold open before the window is in memory, show an inline **`LoadingStateView`** (warm-scrim spinner, no full-screen black). Debounce the predicate ~150–200ms so typing stays smooth; never block the field.
- **No results** — `ContentUnavailableView.search`-style: `magnifyingglass`, **"No matches for "rent""**, caption "Try a different word, or clear the group filter." Offer a **"Clear filter"** ghost button when a non-"All" chip is active (a common false-empty). **No clay marker** when zero results (the receipt confirms success only).
- **Error** — client filter can't really fail; if the underlying window is unsynced/offline, surface a transient **`NotificationBanner`** (warning/brass, Liquid Glass): "Showing locally cached tasks — pull to refresh on Calendar." Never a blocking full-screen error.
- **Offline** — results come straight from the on-device SwiftData cache; perfectly usable offline within the synced window; the banner notes the window is local. (A dedicated BE search across the *entire* history is the follow-up.)
- **Edge cases:**
  - **Recurring** — a series can surface **multiple occurrence rows** (e.g. "Pay rent" Jun 24 + Jul 24); each is its own row keyed by `occurrenceKey`, each with the ⟳ badge. Cap the visible occurrences per series to the nearest few with a "more occurrences" affordance rather than flooding the list with 52 weekly hits.
  - **All-day** — receipt reads "all-day" (no time range); sorts first within a date.
  - **Completed** — olive spine + strikethrough; still searchable (don't hide done tasks from search).
  - **Overflow "+N more"** — if a series has many matching occurrences, collapse to the soonest + a "+N more occurrences" row that expands inline (the count in JetBrains Mono `code-small`).
  - **Long titles** — Fraunces title wraps to max 2 lines then truncates-tail ("Rent review with the building management…"); the receipt line and snippet stay single-line truncating.
  - **Long notes snippet** — windowed around the match, ellipses both ends, single line.

---

## Interactions & motion

- **Open Search** — tapping the nav-bar glass island presents the cover with a **warm material expand from the island** (matched-geometry feel), keyboard rising. Spring settle ~0.32, damping ~0.9. **Reduce Motion → straight cross-fade** (no expand), keyboard still rises.
- **Type → filter** — the result list **diffs in place** with a `.snappy` insert/remove as the predicate narrows; the clay **result-count marker re-stamps** with a quick `.easeOut(0.16)` count change (no bounce). Debounce ~150–200ms.
- **Filter chip select** — `CueChip` signature: `.easeOut(0.16)` fill/ink swap; the list re-diffs `.snappy`. Selection fills espresso, never clay.
- **Tap a result → detail** — standard push/sheet into `09-event-detail.md`; `.navigationTransition`-style, interruptible.
- **Wax-seal toggle (on a task row)** — the existing seal **spring (response 0.42, damping 0.62)**: scale 0.4→1, opacity 0→1, rotation −8°→0°, with `.success` haptic; the row's spine cross-fades espresso→olive and the title gains a strikethrough. **Reduce Motion → cross-fade** the seal fill + check with no scale/rotation (the design-system flag #6 fallback).
- **Clear (×) / Cancel** — clearing returns to the Recent state with a `.snappy` swap; Cancel dismisses the cover (reverse of the open transition, → cross-fade under Reduce Motion).
- **Pull-to-dismiss** — a downward drag past threshold on the result list dismisses the cover (interactive), with the keyboard dropping first.
- **Reduce-Motion fallbacks (per cue):** open/close → cross-fade; list diff → instant; marker re-stamp → instant count update; seal → cross-fade.

The **160ms ease-out** (chips, marker re-stamp) and the **single wax-seal spring** are the two recurring signatures present here; everything else stays calm so typing feels immediate.

---

## iOS specifics

- **Dynamic Type** — every text style is relative (`title-M`, `body`, `callout`, `code`, `label` scale). At AX sizes: the result row lets the Fraunces title take up to 2 lines, keeps the mono receipt line single (truncate-tail), and the snippet collapses first; the filter chips scroll horizontally without clipping. Never truncate the typed query in the field — it scrolls.
- **Haptics (`.sensoryFeedback`):** `.selection` on a filter-chip change; `.success` on a wax-seal completion from a result row; `.impact(.soft)` on cover dismiss-by-drag past threshold. Respect the system haptic setting.
- **Context menu** (long-press a result row) — quick actions without opening detail: **"Open"**, **"Mark done"/"Mark not done"** (tasks only), **"Edit"**, **"Go to day"** (jumps the Calendar tab to that occurrence's date). Surfaced as `accessibilityActions` too.
- **Swipe actions** — on a result row, **leading = complete** (calm accent, tasks only), **trailing-full = delete series** (brick `--danger`) with a confirm. Mirrors the agenda list's swipe grammar.
- **VoiceOver** — each result row is one element speaking **"Pay rent, recurring, all-day, Wednesday June 24, Bills, not completed"** (title + recurring + date/time + group + completion state); the seal is a separate **"Mark done"** action, not color-only. The clay marker reads **"7 results"**. The search field is labeled "Search tasks"; the clear button "Clear search". **Never color-only meaning** — recurring (shape ⟳), completed (strikethrough + "completed"), and group (named in the receipt line) all carry text/shape cues. **Composited contrast:** the clay marker's cream text over `--secondary` clears AA (4.61:1); espresso chip text/cream clears AAA; verify any group-color glyph over its backing ≥4.5:1, else fall back to `--text-primary` / espresso.

---

## ✦ Claude Design prompt (paste this)

> Generate a single fixed iPhone screen (393×852pt @3x, **NOT responsive** — a native iOS view, not a web page) using the published **CUE "Kraft & Ink"** design system and its tokens ONLY. No new colors, fonts, gradients, or pure #FFFFFF/#000000 surfaces.
>
> **Screen: Search.** A dedicated search surface — opened from a nav-bar **glass island** on Today/Calendar, **NOT a tab** — that filters the user's already-synced tasks by typed text across title and notes, filterable by group, and shows unified occurrence rows the user can tap to open or complete in place.
>
> **Frame & chrome.** iOS status bar (9:41, battery/Wi-Fi), Dynamic Island reserved, top safe area ~59pt, 34pt home-indicator gutter, 16pt side margins. **No tab bar is shown** (this is a full-cover search surface reached from a tab, not a tab itself). Top: a **search field** on `--surface-elevated`, 6pt radius, 1pt `--border`, with a leading `magnifyingglass` glyph in `--primary`, the typed query "rent" in **Public Sans 16** `--text-primary`, a trailing clear (×) in `--text-secondary`, and a **"Cancel"** text button (in `--accent-text`) to its right outside the field; keyboard up, return key reads "Search". Beneath it a **horizontal group-filter chip rail** of `CueChip`s — "All" (selected) · Work · Bills · Errands · Travel · Family · Personal — selected chip = espresso `--primary` fill + cream `--on-accent`, unselected = `--surface` + `--border` (4pt rubber-stamp rectangles, NEVER pills, selection NEVER clay); a 0.5pt `--separator` hairline under the rail.
>
> **Body — result list on the white page.** First, the ONE rationed clay moment: a small **rubber-stamp result-count marker** in **clay `--secondary` fill + cream `--on-accent` text**, JetBrains Mono 11pt, reading **"7 RESULTS"**, left-aligned above the first row — the only clay-fill on the screen. Then result rows, each a **letterpress paper card** (`--surface`, 10pt radius, 1pt `--border` + hard blur-0 value-cut shadow `--text-primary` 6% y:1) with a **left spine** (4pt, espresso `--primary` for open / olive `--success` for completed), a **Fraunces 18 medium** task title in `--text-primary` (with a leading "⟳" recurring badge tinted `--accent-text` when recurring; strikethrough + 62% opacity when completed), a **JetBrains Mono 13** receipt line in `--text-secondary` ("Wed Jun 24 · all-day · Bills"), an optional **Public Sans 15** quoted notes-snippet when the match is on notes ("…confirm rent increase clause…"), and a trailing **wax-seal toggle** (empty bordered seal-well when open, clay seal + cream check when done) shown ONLY for tasks (events show no seal).
>
> **Real content (verbatim — no lorem, no "Item 1"; query = "rent"):** "Pay rent" (recurring ⟳, all-day, Bills) shown as TWO occurrence rows — "Wed Jun 24 · all-day · Bills" and "Thu Jul 24 · all-day · Bills"; "Rent review with landlord" ("Mon Jun 30 · 18:00–18:30 · Personal"); "Car rental pickup" ("Fri Aug 15 · 10:00 · Travel", an event → no seal); a completed "Rent a van for move" (olive spine + strikethrough, "Sat May 31 · 08:00 · Errands"); plus one notes-match row surfacing the quoted snippet "…confirm rent increase clause…".
>
> **States to also render (as small variants):** empty query → a "RECENT" section (eyebrow on a `--surface-sunken` strip) listing recent queries "rent", "dentist", "sprint review" each with a leading `clock.arrow.circlepath` and a trailing ×; no-results → a centered `ContentUnavailableView` ("magnifyingglass", "No matches for "rent"", caption "Try a different word, or clear the group filter.") with a **"Clear filter"** ghost button when a non-All chip is active, and **no clay marker** (the receipt only confirms success).
>
> **Depth & detail.** Letterpress only — result cards use a 1pt `--border` + hard value-cut shadow (blur 0); the search field is flat-bordered. Liquid Glass is warm-tinted and used ONLY for chrome (the originating nav island, never on cards). All tap targets ≥44pt. JetBrains Mono is the receipt voice (dates, times, the result count); Fraunces is titles only (≥17pt); Public Sans is the query, snippet, chip text, and helper copy.
>
> **Anti-AI-slop guardrails (honor exactly):** NO Inter / SF Pro / Helvetica — Fraunces + Public Sans + JetBrains Mono only. NO purple, NO blue accents, NO gradients, NO glassmorphism on result cards, NO soft blurred drop shadows (only hard blur-0 value-cuts), NO pure #FFFFFF cards floating on white, NO pure #000000. NO generic evenly-spaced bento grid — this is a vertical native iOS result list. NO pill-shaped chips and NO chip-with-a-dot — 4pt rubber-stamp rectangles, selected by espresso fill not clay. NO 16–20pt squircle bubbles — crisp 4–10pt cut-paper corners. Honor Kraft & Ink exactly: clay `--secondary` is FILL-ONLY and appears **once** (the result-count receipt marker), espresso `--primary` stays structural (chips, spines), olive `--success` = completed (status on a shape/value channel, never stealing the accent). Native iOS patterns: a `.searchable`-style field with keyboard up and a "Search" return key, a horizontal scrolling chip filter rail, an agenda-style result list with swipe-to-complete/delete, context menus, and a full-cover presentation that returns to the originating tab on Cancel — Search is reached FROM a tab, it is never a tab. Don't use the words "modern/clean/sleek/beautiful".
