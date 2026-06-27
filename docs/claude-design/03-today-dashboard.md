# Today (Dashboard home)

> Glanceable agenda home — a warm "good morning, here's your day" page: greeting, the one next thing, a free-gap read, today's load, a unified upcoming list, a "This Evening" section, and the optional morning-brief / evening-shutdown ritual card whose copy mirrors the Telegram message.

This is the **default landing tab** of CUE. The screen exists in code today only as a 25-line `ContentUnavailableView` stub (`Features/Dashboard/DashboardView.swift`) — generate it fresh, but bind every element to the **real backend fields** named below and obey the **Kraft & Ink** system exactly.

---

## Design system (Kraft & Ink)

Use the published **"Kraft & Ink"** system and its tokens ONLY. No new colors, fonts, gradients, or pure white/black. Reference everything by name; never invent hex.

**Color (opaque sRGB; reference by role):**
- `--background #FFFFFF` — app canvas behind everything (the white page).
- `--surface #FAF6EF` — cards, rows (faint warm paper; never whiter than the page).
- `--surface-elevated #FEFCF8` — the ritual card / any raised surface.
- `--surface-sunken #F1EADF` — recessed strips: card header bands, the load meter track, zebra.
- `--primary #5A3A24` (espresso) — structural tint, key actions, selected chips, icons. The backbone.
- `--primary-pressed #43291A` — pressed state of primary.
- `--secondary #BE4A28` (clay) — **FILL ONLY**, rationed: the wax seal, the single decisive CTA, the TODAY/now marker. At most ONE clay-fill moment on this screen.
- `--accent-text #A53D22` — the ONLY clay allowed as **text / icons / thin rules** (AA-safe).
- `--on-accent #FBF5EA` (cream) — ink placed on a primary/secondary fill.
- `--text-primary #2E211A` — body + headings (warm near-black).
- `--text-secondary #6E5C4C` — supporting / muted text.
- `--separator #D0BA98` — DECORATIVE hairlines only (faint, never a real edge).
- `--border #8C7142` — FUNCTIONAL edges a user must locate (card outlines, inputs).
- `--success #466234` (olive) — completed / finished states.
- `--warning #C9A24B` (brass) — pending / draft (FILL only; place INK on it, never cream).
- `--danger #A8331F` (brick) — destructive.
- Discipline: clay is one-hot. Olive = done, brass = pending, espresso = structure. **Color presence, not a rainbow.** Group colors come from the backend (`TaskGroupDTO.color`) and ride on a thin 4pt rail / dot — they are membership identity, not status.

**Typography (3 bundled families — substitute via Google Fonts in preview; NEVER Inter/SF Pro):**
- **Fraunces** (display, ≥17pt only): `display-L` 34 semibold −0.4 (screen hero), `display-M` 27 semibold −0.4, `title-L` 22 medium −0.2 (section title), `title-M` 18 medium −0.2 (card/row title), `headline` 17 medium (emphasised lead line).
- **Public Sans** (body/labels): `body` 16 regular, `body-emph` 16 semibold (button labels), `callout` 15 regular (supporting), `label` 13 medium +0.3 (eyebrows / chip text), `caption` 12 regular.
- **JetBrains Mono** (receipt voice — dates, counts, times, durations, "+N"): `code` 13 regular +0.2, `code-small` 11 medium +0.8.
- Rule: Fraunces is the editorial voice for titles ≥17pt — never for dense labels/body. Times, counts and durations read in JetBrains Mono (wider tracking); display reads tighter (negative tracking).

**Spacing (4pt grid):** `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 (default gap / card inner) · xl 20 · xxl 24 (between cards) · xxxl 32 (between sections) · huge 48 (hero/empty breathing room)`. 16pt side margins. Let the paper breathe.

**Radius (crisp cut-paper, never squircle bubbles):** `chip 4 · small 6 (default) · medium 8 · card 10 · large 12`. Cards = `card 10`.

**Depth — "letterpress, not float" (blur radius 0 always):**
- `letterpress` (card default) = 1pt `--border` stroke + hard `--text-primary @6%` value-cut, y:1.
- `value-cut` = 1pt `--border` + `--text-primary @12%`, y:2 (crisp stacked-paper offset).
- NO soft uniform drop shadows anywhere. System **Liquid Glass** (frosted) is used ONLY for chrome (tab bar, nav-bar search island, floating elements), re-tinted **warm** toward kraft/clay — never Apple's cool blue-grey.

**Components (by name):**
- **CueCard** — fill `--surface`, radius 10, letterpress depth; optional `--surface-sunken` header strip with a 1pt `--separator` bottom rule.
- **CueButton** — full-width, radius 6, label `body-emph`, press = 1pt downward letterpress depress (no scale/glow), `.easeOut 160ms`. Variants: `.primary` (espresso fill + cream), `.decisive` (clay fill + cream — the ONE hot CTA, ≤1/screen), `.secondary` (clear + 1pt border + espresso label), `.ghost` (clear + `--accent-text` label).
- **CueChip** — 4pt rubber-stamp rectangle (NEVER a pill, never pill-with-dot). Unselected = `--surface` + `--text-secondary` + 1pt `--border`; selected = `--primary` espresso fill + cream, no border, no dot. Text = `label` role.
- **CueAvatar** — circle, always ringed by a 1.5pt `--primary` stroke; placeholder = `--surface-sunken` + `person.fill` glyph in `--text-secondary`.
- **WaxSeal** — irregular hand-pressed clay blob (~16 vertices, fixed jitter — NOT a clean circle). Unstamped = dashed empty "seal-well" (1.5pt `--border`, dash 4/4). Stamped = `--secondary` clay fill + `--primary-pressed @40%` rim (multiply) + centered cream glyph. Reserved for the TWO commit moments only (completing a task, saving an event).

---

## Frame & platform

- **Single fixed iPhone 393×852pt @3x. NOT responsive** — a native iOS 26 screen, not a web page.
- iOS status bar at top (time left, cellular/wifi/battery right). **Dynamic Island reserved** (don't draw under it). Top safe area ~59pt. 34pt home-indicator gutter at the bottom; keep content clear of it.
- 16pt side margins. All tap targets ≥44pt.
- **Nav chrome:** large-title nav at root — `Today` in Fraunces ~34pt (`display-L`), collapsing to an inline ~17pt title on scroll. **Trailing nav-bar action: a single Liquid-Glass "glass island" search button** (`magnifyingglass` in `--primary`), warm-tinted frosted circle/capsule — search is NOT a tab, it's reachable here. ≤1 trailing action besides it.
- **Bottom: floating warm-tinted Liquid-Glass tab bar**, ~21pt insets from sides/bottom, fully expanded (never minimizes on scroll). THREE merged destination tabs + ONE separated trailing action capsule:
  - `Today` (`sun.max`-style, **selected** — espresso ink), `Calendar` (`calendar`), `Settings` (`gearshape`).
  - Separated to the right in its own capsule: **"+"** (`plus.circle.fill`) — an *action item* (opens the Create sheet over the current tab), not a destination; it never shows a selected state.
- **One-handed reach:** the most-tapped affordances (next-task complete, the "+" create, the ritual CTA) sit in the lower 2/3 thumb arc; the greeting + search island are top-anchored read-only zones.

---

## Layout

Top → bottom. A single vertical `ScrollView` over `--background`, 16pt side margins, `--space-xxl (24)` between major cards. Real CUE content — no lorem.

```
┌──────────────────────────────────────────────┐
│ ●●●  9:41                       ▂▄ 􀙇 100%▐     │  status bar (Dynamic Island reserved)
│                                                │
│  Wednesday · 24 Jun          ⌕ (glass island) │  eyebrow (JBMono) + nav search button
│  Good morning, Jane          [JA avatar ring]  │  display-L Fraunces hero + CueAvatar
│                                                │
│ ┌── NEXT ───────────────────────────────────┐ │  ← the one next thing
│ │ │ 09:30  Standup with the platform team   │ │  4pt clay rail = group color "Work"
│ │ │ ✎ in 18 min · 30 min            ◌ seal  │ │  free-gap (JBMono) + unstamped seal-well
│ └────────────────────────────────────────────┘ │
│                                                │
│ ┌── TODAY'S LOAD ───────────────────────────┐ │  CueCard, header strip
│ │  5 things        ▓▓▓▓▓░░░░░  moderate      │ │  count (JBMono) + one-accent intensity bar
│ │  2 done · 3 to go                         │ │  olive done / espresso remaining (caption)
│ └────────────────────────────────────────────┘ │
│                                                │
│  Up next                          See all →    │  title-L Fraunces section header
│ ┌────────────────────────────────────────────┐ │
│ │ │ 11:00  Dentist — Dr. Reyes      ↻        │ │  group rail + recurring glyph (↻)
│ │ │ 13:00  Lunch w/ Marco @ Café Nord        │ │
│ │ │ 15:30  Submit Q3 budget draft   ☐        │ │  a task (requiresCompletion) → checkbox
│ │ │ ⬚ all-day  Renew passport                │ │  all-day band, no time
│ │                              + 2 more       │ │  overflow row (JBMono)
│ └────────────────────────────────────────────┘ │
│                                                │
│  This evening                                  │  title-L — Things-style later section
│ ┌────────────────────────────────────────────┐ │
│ │ │ 18:30  Pick up groceries        ☐        │ │
│ │ │ 20:00  Call Mom                 ↻ ☐      │ │
│ └────────────────────────────────────────────┘ │
│                                                │
│ ┌══ YOUR MORNING BRIEF ════════════ Jarvis ══┐ │  ritual card — surface-elevated, value-cut
│ │ "Good morning, sir. 5 on the books today.  │ │  copy MIRRORS the Telegram message
│ │  First up: Standup at 09:30. You wrapped    │ │
│ │  2 last night — Gym, Read 20 pages."       │ │  uses completedAt recap
│ │                                            │ │
│ │  [  Plan my day  ]  ← .decisive (clay)     │ │  THE one rationed clay CTA / wax moment
│ └════════════════════════════════════════════┘ │
│                                                │
│        (34pt home-indicator gutter)            │
│   ┌─────────────────────────┐   ┌───┐          │
│   │  Today   Calendar  Settings│  │ + │         │  floating warm Liquid-Glass tab bar
│   └─────────────────────────┘   └───┘          │  3 merged tabs + separated "+" action
└──────────────────────────────────────────────┘
```

**Region detail (top → bottom):**

1. **Header / greeting.** Eyebrow line in JetBrains Mono `code` (`--text-secondary`): full weekday + date `Wednesday · 24 Jun`. Below it the hero in Fraunces `display-L` (`--text-primary`): time-of-day greeting + first name from `UserDTO.displayName` → `Good morning, Jane`. Trailing: **CueAvatar** (≈44pt, 1.5pt `--primary` ring) from `UserDTO.avatarBase64`, placeholder = sunken paper + `person.fill`. The nav-bar **search glass island** sits in the trailing nav slot above the greeting.

2. **NEXT card** (the hero of the page). A CueCard with a thin 4pt **leading rail in the group's color** (`TaskGroupDTO.color`, e.g. clay-orange `#E27921` for "Work"). Row: `occurrenceStart` time in JetBrains Mono `code` + title in Fraunces `title-M`. Subline (`callout`, `--text-secondary`): the **free-gap** read — `in 18 min` (computed now → `occurrenceStart`) + `·` + duration `30 min` (`occurrenceStart`→`occurrenceEnd`, JBMono). Trailing: an **unstamped WaxSeal "seal-well"** (dashed) ONLY if this next item is a task (`requiresCompletion == true`); otherwise no seal (an event has nothing to complete). This is the single most important glance on the screen.

3. **TODAY'S LOAD card.** CueCard with a `--surface-sunken` header strip eyebrow `TODAY'S LOAD` (`label`). Body: total `5 things` in JetBrains Mono + a **one-accent intensity bar** on a `--surface-sunken` track — filled in espresso `--primary`, length scaled by today's count from `DailyCountsResponse.counts["2026-06-24"]`, with a qualitative word (`light` / `moderate` / `full`). Sub-caption: `2 done · 3 to go` — "done" in olive `--success`, remainder in `--text-secondary` (both `caption`). Density is intensity of ONE accent, never a rainbow.

4. **"Up next" section** — Fraunces `title-L` header + a `See all →` ghost link (`--accent-text`) that switches to the Calendar tab. A single CueCard listing the next **unified events + tasks** (from `GET /tasks`, `from=now`, ordered by `occurrenceStart`). Each row: 4pt group-color rail + time (JBMono) or `⬚ all-day` band + title (`body`/`title-M`). Trailing glyphs on a **separate channel from color**: `↻` recurring (`isRecurring`, `--accent-text`), `☐` checkbox if `requiresCompletion`. Cap at ~4 rows; overflow as a JetBrains-Mono `+ 2 more` row that pushes into Calendar.

5. **"This evening" section** (Things-style) — Fraunces `title-L`. Same row anatomy, filtered to occurrences after ~17:00. Reduces daytime overwhelm. Hidden entirely when empty.

6. **Ritual card — Morning brief / Evening shutdown** (the ONE rationed clay moment). A `--surface-elevated` CueCard with **value-cut** depth (slightly more present than the others) and a header strip: eyebrow `YOUR MORNING BRIEF` (`label`) left, persona name `Jarvis` (the seeded `presetName`, `code-small`, `--accent-text`) right. Body in Fraunces `headline`/`body` is **the same prose CUE sends to Telegram** — e.g. *"Good morning, sir. 5 on the books today. First up: Standup at 09:30. You wrapped 2 last night — Gym, Read 20 pages."* The recap line is driven by yesterday's `completedAt` occurrences. Bottom: a **CueButton `.decisive`** (clay fill, cream label) — `Plan my day` — the screen's single wax/clay commit. After 5pm this card flips to **Evening shutdown** copy (recap of today's `completedAt` + "Nothing left for tonight" + `Wind down` CTA).

**Rationed clay placement:** exactly ONE clay fill on the screen — the `.decisive` ritual CTA. The NEXT-card seal-well is *unstamped* (dashed border, not clay fill), so it doesn't spend the accent. Everything else is espresso, olive, brass, or paper.

---

## Data & states

Bind every element to these exact backend shapes (DTOs as defined in `Networking/APIModels.swift`):

| UI element | Source field / endpoint |
|---|---|
| Greeting name | `UserDTO.displayName` (first name; fall back to "there" if nil) |
| Avatar | `UserDTO.avatarBase64` (base64, no data-URL prefix; placeholder if nil) |
| Date eyebrow | device date in `UserDTO.timezone` |
| NEXT task | first `OccurrenceDTO` from `GET /tasks?from=<now>` where `occurrenceStart >= now`, ordered ascending |
| NEXT title / time | `OccurrenceDTO.title`, `.occurrenceStart`, `.occurrenceEnd` |
| Group color rail | `TaskGroupDTO.color` resolved via `OccurrenceDTO.groupId` (hex like `#E27921`; nil → no rail) |
| Free gap | computed `now → occurrenceStart`; duration `occurrenceStart → occurrenceEnd` |
| Seal-well shown? | only if `OccurrenceDTO.requiresCompletion == true` |
| Today's load count | `DailyCountsResponse.counts["YYYY-MM-DD"]` from `GET /tasks/daily-counts` (zero-count days omitted → treat missing as 0) |
| done / to-go split | count of occurrences with `completedAt != nil` vs nil, for today |
| Up next / This evening rows | `OccurrenceDTO[]` from `GET /tasks` window, split at ~17:00 local |
| Recurring badge `↻` | `OccurrenceDTO.isRecurring` |
| All-day band | `OccurrenceDTO.isAllDay` (no time shown) |
| Checkbox / completion | `OccurrenceDTO.requiresCompletion` + `.completedAt`; toggle → `PATCH /tasks/:id/completion` |
| Ritual recap | yesterday's (or today's, for shutdown) occurrences where `completedAt != nil` (title list) |
| Persona name | `presetName` ("Jarvis") from persona-settings; ritual on/off toggle lives on the Notifications settings screen (page 16) |

**States to render (produce variants):**
- **Default** — the populated screen above (5 things, a NEXT task, a brief card).
- **Empty / clear day** — no upcoming occurrences: a calm centered block, Fraunces `title-L` *"Nothing scheduled today"* + `callout` *"Enjoy the white space — or add something."* + a `.secondary` CueButton `Add to today` that opens the Create sheet. The LOAD card reads `0 things · light`. The ritual card still shows ("Good morning, sir. A clear page today.").
- **Loading** — first paint while `GET /tasks` + `daily-counts` resolve: warm-ink scrim spinner (`LoadingStateView`, `--text-primary @8%` scrim + espresso `ProgressView`) OR skeletonized CueCards (sunken-paper placeholder bars). Greeting + avatar render immediately (already cached). Never a blank white flash.
- **Error** — feed fetch fails: an `ErrorStateView` style block under the greeting — `wifi.exclamationmark`, title *"Couldn't load today"*, message + a retry CueButton `.secondary`. The greeting/avatar stay; only the data region degrades. Transient errors surface as a top **NotificationBanner** (warm Liquid Glass, `.error` brick rail) instead of replacing the page.
- **Offline** — show last-synced data with a slim brass (`--warning`) inline note `Showing your last sync` (`caption`, INK on brass, never cream); pull-to-refresh retries.
- **Edge cases:**
  - *Recurring* → `↻` glyph + group color; never implies the whole series is "today."
  - *All-day* → `⬚ all-day` chip-band, sorts above timed items.
  - *Overflow* → `+ N more` JetBrains-Mono row → Calendar tab; never grow the card unbounded.
  - *Long titles* → truncate to 1 line with tail ellipsis; full title via VoiceOver + tap-through. Never clip mid-glyph.
  - *No group* → no color rail; title still shows (color is membership, optional).
  - *Next item is far off (no more today)* → NEXT card reads *"Next: Tomorrow 08:00 · Gym"* using tomorrow's first occurrence; free-gap reads `tomorrow`.

---

## Interactions & motion

- **Pull-to-refresh** (`.refreshable`) on the scroll view → re-fetch `GET /tasks` + `daily-counts`; espresso spinner; `.sensoryFeedback(.impact)` on release.
- **Tap NEXT card** → push/zoom to the occurrence detail sheet (`.medium` detent). **Tap any Up-next / Evening row** → same. **Tap `See all →` / `+ N more`** → switch to the Calendar tab (`.navigationTransition(.zoom)` if a matched source exists; otherwise cross-fade).
- **Complete a task inline** (tap the seal-well or row checkbox, or swipe leading→complete): the unstamped WaxSeal **stamps** — `.spring(response 0.42, dampingFraction 0.62)`, scale 0.4→1, opacity 0→1, rotation −8°→0°, clay fill soaking in + cream checkmark; the row title gets a calm olive strike/`--success` tint; LOAD bar nudges; `.sensoryFeedback(.success)`. **Reduce-Motion fallback:** drop the spring/rotation, cross-fade dashed-well → stamped clay over ~120ms, no scale.
- **Ritual `.decisive` "Plan my day" CTA** → 1pt letterpress depress (`.easeOut 160ms`) + `--primary-pressed` multiply @0.22 ("ink soaking in"), then opens the day-planning flow / Create sheet. `.sensoryFeedback(.impact)` on press. No glow, no scale, no shadow.
- **Search glass island tap** → presents Search (sheet or push) with the keyboard up.
- **Card press feedback** is letterpress only — never a soft scale/shadow bounce.
- **Section reveal on first appear** — a quiet staggered fade-in of the cards (≤200ms, `.easeOut`, ~40ms stagger). **Reduce-Motion:** all appear at once, opacity only.
- **Tab-bar "+"** → presents the Create sheet over Today (`.presentationDetents([.medium, .large])`, opens at `.medium`, keyboard up); Today stays mounted underneath.

---

## iOS specifics

- **Dynamic Type:** every text style is relative (`relativeTo:`) — the hero, rows, and JetBrains-Mono times all scale. At AX sizes: row time/title stack vertically, the LOAD `2 done · 3 to go` wraps, the ritual card grows; **never clip or truncate the seal/checkbox tap target** (stays ≥44pt). `See all →` and `+ N more` reflow below their headers.
- **Haptics (`.sensoryFeedback`):** `.success` on task completion (seal stamp); `.impact` on the `.decisive` CTA press, pull-to-refresh release, and "+" open; `.selection` on tab switches. Respect the system haptic setting.
- **Context menus** (`.contextMenu`) on Up-next / Evening rows: *Complete*, *Edit*, *Skip this occurrence* (`POST /tasks/:id/skip`), *Open in Calendar*.
- **Swipe actions** on rows: leading-edge → **Complete** (calm — olive/seal, `.sensoryFeedback(.success)`); trailing full-swipe → **Delete** (brick `--danger`, with confirm for a series). Both mirrored as `accessibilityActions`.
- **VoiceOver labels:**
  - Greeting: *"Good morning, Jane. Wednesday, June 24."*
  - NEXT: *"Next: Standup with the platform team, 9:30 AM, in 18 minutes, 30 minutes long, Work group. Task, not yet complete. Double-tap to open."*
  - LOAD: *"Today's load: 5 things, moderate. 2 done, 3 to go."*
  - Row: *"11 AM, Dentist, Dr. Reyes, recurring, Health group."* / all-day: *"All day, Renew passport."*
  - Ritual CTA: *"Plan my day, button."*
  - Never convey meaning by color alone — the recurring/all-day/done states each have a glyph or word.

---

## ✦ Claude Design prompt (paste this)

```
SCREEN: Today (Dashboard home) — CUE's default landing tab: a glanceable, warm "here's your day"
agenda home (greeting, the one next thing, today's load, a unified upcoming list, a "This Evening"
section, and an optional morning-brief / evening-shutdown ritual card).

SYSTEM: Use the published "Kraft & Ink" design system and its tokens ONLY. No new colors, fonts,
gradients, or pure white/black surfaces. The clay wax-seal accent appears at most ONCE on this
screen (on the ritual "Plan my day" .decisive CTA). Reference tokens and components by NAME.

FRAME: Single fixed iPhone 393×852pt @3x. NOT responsive — a native iOS 26 screen, not a web page.
iOS status bar (time + battery; Dynamic Island reserved). Top safe area ~59pt; 34pt home-indicator
gutter; 16pt side margins; all tap targets >=44pt. Root large-title nav: "Today" in Fraunces ~34pt
collapsing to inline ~17pt on scroll, with a single trailing warm Liquid-Glass "search island"
button (magnifyingglass, espresso). Bottom: floating WARM-tinted Liquid-Glass tab bar (never
minimizes) — three merged tabs Today (selected) / Calendar / Settings, plus a SEPARATED trailing
"+" action capsule (plus.circle.fill) that opens the Create sheet over Today.

AUDIENCE: a busy person opening the app first thing in the morning (or winding down at night) who
wants the day in one glance before deciding what to do next.

LAYOUT (top -> bottom, single ScrollView on --background, 24pt between cards):
  1. Header — eyebrow "Wednesday · 24 Jun" (JetBrains Mono, --text-secondary) + Fraunces display-L
     hero "Good morning, Jane" (--text-primary); trailing CueAvatar (1.5pt --primary ring).
  2. NEXT card — CueCard with a 4pt leading group-color rail; "09:30" (JetBrains Mono) + Fraunces
     title-M "Standup with the platform team"; subline "in 18 min · 30 min" (callout/JBMono,
     --text-secondary); trailing UNSTAMPED dashed WaxSeal seal-well (because it's a task).
  3. TODAY'S LOAD card — CueCard, sunken header strip "TODAY'S LOAD"; "5 things" (JBMono) + a single
     espresso --primary intensity bar on a --surface-sunken track + "moderate"; sub "2 done · 3 to go"
     (done in olive --success).
  4. "Up next" — Fraunces title-L header + ghost "See all ->" (--accent-text). CueCard rows of unified
     events+tasks: group-color rail + time (JBMono) or "all-day" band + title; trailing glyphs on a
     separate channel from color — recurring (--accent-text) and a checkbox for tasks. Rows:
       11:00  Dentist — Dr. Reyes      (recurring, Health)
       13:00  Lunch w/ Marco @ Café Nord
       15:30  Submit Q3 budget draft   (task ☐)
       all-day  Renew passport
     Overflow row "+ 2 more" (JBMono) -> Calendar tab.
  5. "This evening" — Fraunces title-L; same row anatomy, items after 17:00:
       18:30  Pick up groceries  (task ☐)
       20:00  Call Mom           (recurring, task ☐)
  6. Ritual card — Morning brief — a --surface-elevated CueCard with value-cut depth and a header
     "YOUR MORNING BRIEF" + persona name "Jarvis" (--accent-text). Body in Fraunces headline reads
     the SAME prose CUE sends to Telegram: "Good morning, sir. 5 on the books today. First up:
     Standup at 09:30. You wrapped 2 last night — Gym, Read 20 pages." Bottom: a CueButton .decisive
     (clay fill, cream label) "Plan my day" — THE single rationed clay / wax-seal moment on this screen.
  Bottom: floating warm Liquid-Glass tab bar — Today (selected) / Calendar / Settings + separated "+".

COMPONENTS (by name): CueCard, CueButton (.decisive for the one CTA, .secondary/.ghost elsewhere),
CueChip, CueAvatar, WaxSeal (unstamped seal-well in NEXT). Search = a warm Liquid-Glass nav-bar
island, NOT a tab. The "+" is a separated tab-bar action capsule, NOT a destination tab.

REAL CONTENT (verbatim — no lorem, no "Item 1"): greeting "Good morning, Jane"; NEXT "09:30 Standup
with the platform team", gap "in 18 min · 30 min"; load "5 things · moderate · 2 done · 3 to go";
up-next "Dentist — Dr. Reyes", "Lunch w/ Marco @ Café Nord", "Submit Q3 budget draft", "Renew
passport"; evening "Pick up groceries", "Call Mom"; brief copy as written above; recap "Gym, Read 20
pages".

NATIVE PATTERNS: large-title nav collapsing on scroll; pull-to-refresh; swipe-actions
(leading=complete with the olive seal, trailing-full=delete brick); context menus (Complete / Edit /
Skip / Open in Calendar); sheet at .medium from "+". Tap NEXT or any row -> occurrence detail.

STATE: Show the populated default. ALSO produce: empty/clear-day (Fraunces "Nothing scheduled today"
+ "Enjoy the white space — or add something." + a .secondary "Add to today"; load "0 things · light";
ritual still shows "A clear page today."); loading (warm-ink scrim spinner or sunken-paper skeleton
cards, greeting renders immediately — no white flash); error (under the greeting: wifi.exclamationmark
+ "Couldn't load today" + a .secondary retry; transient errors as a top warm-glass NotificationBanner).

ANTI-AI-SLOP GUARDRAILS (hard): Fraunces for titles >=17pt ONLY (Public Sans body, JetBrains Mono for
all dates/times/counts/durations) — NEVER Inter or SF Pro. Letterpress depth = 1px --border + hard
value-cut (blur 0) — NO soft drop shadows, NO gradients, NO glassmorphism on content cards (glass is
chrome-only and WARM-tinted, never Apple cool blue). NO purple, NO neon, NO blue accents, NO pure
#FFFFFF cards-on-white, NO pure #000000. Chips are 4pt rubber-stamp rectangles, NEVER pills, selected
fill ESPRESSO --primary (not clay). Encode "today's load" as intensity of ONE accent, not a rainbow of
dots; group color is membership on a thin rail, not status. RATION the clay --secondary to exactly ONE
moment — the "Plan my day" .decisive CTA — and nowhere else. Crisp 4–12px cut-paper corners, never
16–20px squircle bubbles. Native iOS 26 patterns throughout. Don't describe it as "modern/clean/sleek".
```
