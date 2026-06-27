# Empty / Loading / Error kit

A single gallery screen that renders every reusable non-content state CUE shows across its surfaces — empty placeholders, loading affordances, full-page errors, an inline pagination row, and the four notification banner severities — so the founder can paste one prompt and review the whole state vocabulary in Kraft & Ink at once.

> **Status: partial.** The kit exists in code (`ErrorStateView`, `LoadingStateView` + siblings, `NotificationBanner` / `AppNotification`, `NotificationHost`). **Known DS gap to fix in this design:** `ErrorStateView`'s retry currently uses a system `.borderedProminent` button — it must wear the Kraft & Ink skin (`CueButton(.secondary)`, or `.primary` when retry is the single obvious action). Empty states currently lean on the system `ContentUnavailableView`; this gallery shows the on-brand letterpress treatment they should adopt.

This is **not a shipped screen** — it is a reference gallery for the design system. Render it as one scrollable iPhone canvas with labelled sections.

---

## Design system (Kraft & Ink)

Restated literally from `01-DESIGN-SYSTEM.md` so this prompt is self-sufficient. Use these tokens ONLY — do not invent palette, fonts, gradients, or pure white/black surfaces.

**Color (opaque sRGB, by role):**
- `--background #FFFFFF` — app canvas behind everything.
- `--surface #FAF6EF` — cards, rows (faint warm paper, never whiter than the page).
- `--surface-elevated #FEFCF8` — sheets / modals.
- `--surface-sunken #F1EADF` — recessed strips, section bands, zebra.
- `--primary #5A3A24` espresso — key actions, structural tint. `--primary-pressed #43291A`.
- `--secondary #BE4A28` clay — **FILL ONLY**, the one-hot accent (wax seal / single decisive CTA / TODAY). Rationed to **≤ once per screen**.
- `--accent-text #A53D22` — the ONLY clay allowed as **text / icons / thin rules** (AA-safe).
- `--on-accent #FBF5EA` cream — ink placed on a primary/secondary fill.
- `--text-primary #2E211A` — body + headings. `--text-secondary #6E5C4C` — muted.
- `--separator #D0BA98` — decorative hairlines ONLY. `--border #8C7142` — functional edges (inputs, card outlines).
- Status: `--success #466234` olive (done), `--warning #C9A24B` brass (pending — **place INK on it, never cream**), `--danger #A8331F` brick (destructive/error), `--info #5A3A24` espresso (structural). Color presence, not a rainbow.

**Typography (3 bundled families; web preview via Google Fonts):**
- Display/headings: **Fraunces** — titles ≥ 17pt only, never dense UI labels/body. `displayL 34 semibold / −0.4`, `titleL 22 medium / −0.2`, `titleM 18 medium / −0.2`, `headline 17 medium`.
- Body/labels: **Public Sans** (explicitly NOT Inter / SF Pro). `body 16 regular`, `bodyEmphasis 16 semibold` (= button labels), `callout 15 regular`, `label 13 medium / +0.3` (= chip text / eyebrows), `caption 12 regular`.
- Code/receipts: **JetBrains Mono** — IDs, dates, counts, error bodies, stamps. `code 13 regular / +0.2`, `codeSmall 11 medium / +0.8`.
- Tracking rule: display reads tighter (negative), receipts read wider (positive).

**Spacing (4pt grid):** `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 (default / card inner) · xl 20 · xxl 24 (between cards) · xxxl 32 · huge 48 (empty-state breathing room)`. 16pt side margins.

**Radii (crisp cut-paper, never 16–20 squircle):** `chip 4 · small 6 (default — buttons, fields) · medium 8 (icon tiles, notification banner) · card 10 · large 12 (sheets)`.

**Depth — "letterpress, not float" (both shadows blur-radius 0):**
- `letterpress` = 1px `--border` overlay + `shadow(--text-primary 6%, y:1)` — card default.
- `value-cut` = 1px `--border` + `shadow(--text-primary 12%, y:2)` — crisp stacked-paper offset.
- `glass` = system Liquid Glass — **chrome only** (tab bar, nav bar, notification banner), re-tinted **warm** toward kraft/clay, never Apple's cool blue-grey.
- NO soft uniform drop shadows anywhere. NO gradients. NO glassmorphism on content cards.

**Components used here (reference by name):** `CueCard` (surface, radius 10, letterpress, optional sunken header strip + separator rule), `CueButton` (.primary espresso fill / .decisive clay fill — the ≤1 hot CTA / .secondary clear + border + espresso label / .destructive / .ghost; press = 1px downward letterpress depress, 160ms ease-out), `CueChip` (4px rubber-stamp rectangle, never a pill; selected = espresso fill + cream text), `CueAvatar` (1.5px espresso-ringed circle), `WaxSeal` (irregular hand-pressed clay blob — the brand commit gesture, ≤ once per screen). `ErrorStateView`, `LoadingStateView` / `InlineLoadingRow` / `loadingOverlay`, `NotificationBanner` are the kit pieces this gallery showcases.

---

## Frame & platform

- **Single fixed iPhone 393 × 852pt @3x. NOT responsive** — a native iOS screen, not a web page.
- iOS status bar at top (time left, cellular/Wi-Fi/battery right); **Dynamic Island reserved** in the center notch zone — keep content clear of it. Top safe area ~59pt; **34pt home-indicator gutter** at the bottom.
- 16pt side margins. All tap targets ≥ 44pt.
- **Nav chrome:** inline nav bar titled "States kit" (Fraunces ~17pt) — this is a Settings-reachable reference page, so a back chevron sits leading; no trailing actions. The page is a vertical `ScrollView`.
- **Floating warm Liquid-Glass tab bar** at the bottom (3 tabs — Today / Calendar / Settings — with a separated "+" action item), inset ~21pt from sides and bottom, scroll-to-shrink. Notification banners render in a **separate top overlay** above all chrome (`NotificationHost`), anchored to the top safe area, newest-on-top.
- One-handed reach: nothing interactive is mandatory above the fold; the retry CTA inside the error card sits in the lower-middle thumb zone.

---

## Layout

Top-to-bottom, a scrollable gallery. Each section is a `--surface-sunken` eyebrow label (`label` role, `--text-secondary`) followed by the live component on the `--background` page. Real CUE content throughout — no lorem.

```
┌─────────────────────────────────────────────┐
│  ●●●          9:41                  ▮▮ 􀛪 ▰▰  │  status bar · Dynamic Island reserved
│  ‹  States kit                               │  inline nav bar (Fraunces 17)
├─────────────────────────────────────────────┤
│ ░ EMPTY STATES ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │  sunken eyebrow (label, --text-secondary)
│                                              │
│            ◌  circle.dashed                   │  Today / Day — no tasks
│          No tasks                             │  Fraunces titleM, --text-primary
│   Nothing scheduled for this day.             │  Public Sans callout, --text-secondary
│                                              │
│   ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─    │  --separator hairline divider
│                                              │
│            􀈕  folder                           │  Groups — empty
│          No Groups                            │  Fraunces titleM
│   Tap + to create your first group.           │  callout
│         [  + New group  ]                     │  CueButton(.secondary), espresso label
│                                              │
├─────────────────────────────────────────────┤
│ ░ LOADING ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│                                              │
│              ◐  (large spinner, --primary)    │  LoadingStateView
│           Loading your tasks…                 │  callout, --text-secondary
│                                              │
│   ┌─ list footer ──────────────────────────┐ │
│   │ Standup notes for Thu                    │ │  an existing row (CueCard)
│   │ · · ◐  Loading more…                     │ │  InlineLoadingRow (small spinner)
│   └──────────────────────────────────────────┘ │
│                                              │
│   ┌─ loadingOverlay (over content) ─────────┐ │
│   │   Pay rent          [warm-ink scrim 8%]  │ │  content dimmed, glass-backed
│   │   ▒▒▒▒▒  ◐ Refreshing…  (glass card)    │ │  spinner on glass r=20
│   └──────────────────────────────────────────┘ │
│                                              │
├─────────────────────────────────────────────┤
│ ░ ERROR (full page) ░░░░░░░░░░░░░░░░░░░░░░░░  │
│            􀙨  wifi.exclamationmark            │  ErrorStateView
│       Something went wrong                    │  Fraunces titleM
│  We couldn't reach the server. Check your     │  callout, centered
│      connection and try again.                │
│         [    Retry    ]   ◀ FIX: CueButton    │  was system .borderedProminent
│                                              │
├─────────────────────────────────────────────┤
│ ░ NOTIFICATION BANNERS ░░░░░░░░░░░░░░░░░░░░░  │  (glass — chrome, not cards)
│  ▌ⓘ Calendar synced                       ✕ │  info  · espresso rail
│  ▌✓ Event saved · "Dentist" at 3:00 PM    ✕ │  success · olive rail
│  ▌△ Working offline · changes will sync   ✕ │  warning · brass rail
│  ▌⊗ Couldn't save event                   ✕ │  error · brick rail
│     The server rejected the request.          │   expanded:
│     ─────────────────────────────────────     │
│     HTTP 422  {"message":["title …"]}         │  JetBrains Mono code body
│     Show less  ⌄                              │  --accent-text disclosure
└─────────────────────────────────────────────┘
       ╭──────────────────────────────────╮
       │  ◉ Today   ▦ Calendar   ⚙ Set  ⊕ │   floating warm Liquid-Glass tab bar
       ╰──────────────────────────────────╯
```

**Section detail:**

1. **Empty states** (two, divided by a `--separator` hairline). On the white page, centered, generous `--space-huge` vertical breathing room.
   - **Today / Day — "No tasks":** glyph `circle.dashed` in `--text-secondary` (~44pt), title **"No tasks"** (Fraunces `titleM`, `--text-primary`), description **"Nothing scheduled for this day."** (`callout`, `--text-secondary`). No action — the day's own "+" covers creation.
   - **Groups — "No Groups":** glyph `folder` (`--text-secondary`), title **"No Groups"**, description **"Tap + to create your first group."**, then a single `CueButton(.secondary)` labelled **"New group"** with a leading `plus` (clear fill, 1px `--border`, espresso label). No clay here.

2. **Loading** (three affordances stacked):
   - `LoadingStateView` — large `ProgressView` tinted `--primary`, caption **"Loading your tasks…"** (`callout`, `--text-secondary`), centered in its area.
   - `InlineLoadingRow` — inside a short `CueCard` "list", one real row (**"Standup notes — Thu"**) then a small centered spinner + **"Loading more…"** (`caption`, `--text-secondary`) as the pagination footer.
   - `loadingOverlay` — a `CueCard` showing a real task (**"Pay rent"**) with the **warm-ink scrim** (`--text-primary` at 8%, NOT black) over it and a glass-backed spinner card (radius 20) reading **"Refreshing…"**. Demonstrates a blocking refresh that keeps context.

3. **Error (full page)** — `ErrorStateView.networkFailure`: glyph `wifi.exclamationmark`, title **"Something went wrong"** (Fraunces `titleM`), message **"We couldn't reach the server. Check your connection and try again."** (`callout`, centered), and the **Retry** button **rendered as `CueButton(.secondary)`** (clear + 1px `--border` + espresso label) — explicitly NOT a system blue/tinted prominent button. (If a variant is wanted where retry is the single obvious action, render `CueButton(.primary)` espresso fill instead.)

4. **Notification banners** — all four severities as a vertical stack, each **Liquid Glass** (radius 8, warm-tinted), a 4px leading severity `Capsule` rail, severity glyph, title (`bodyEmphasis`/`--text-primary`) + message (`callout`/`--text-secondary`), trailing `xmark` close (`--text-secondary`):
   - **info** — rail/icon `--info` espresso, `info.circle.fill`: **"Calendar synced"** · "Your calendar is up to date."
   - **success** — `--success` olive, `checkmark.circle.fill`: **"Event saved"** · "Dentist at 3:00 PM was added."
   - **warning** — `--warning` brass, `exclamationmark.triangle.fill`: **"Working offline"** · "Changes will sync when you reconnect."
   - **error (expanded)** — `--danger` brick, `xmark.octagon.fill`: **"Couldn't save event"** · "The server rejected the request." Expanded to show the JetBrains Mono `code` detail block `HTTP 422 … {"message":["title should not be empty"]}` with a top `Divider`, and a **"Show less ⌄"** disclosure in `--accent-text` (chevron rotated 180°).

**The single rationed clay / wax-seal moment:** there is **no wax seal** on this gallery (no commit happens here). Clay appears in exactly one rationed place: the **brick error banner's severity rail/icon** as the most salient state in the stack, plus the sanctioned `--accent-text` disclosure cue. No clay-filled CTA — keep the empty-state and retry buttons espresso (`.secondary`/`.primary`), never `.decisive`, so the gallery models correct rationing.

---

## Data & states

This gallery's "data" is the kit's own props. Bind to the real backend-facing surfaces and component APIs.

- **Empty copy is per-surface and real** (verbatim from `Localizable.xcstrings`):
  - Day / list empty → `calendar.list.empty.title` = "No tasks", `calendar.list.empty.description` = "Nothing scheduled for this day." (icon `circle.dashed`).
  - Groups empty → `groups.empty.title` = "No Groups", `groups.empty.description` = "Tap + to create your first group." (icon `folder`).
  - (Today/Dashboard, Search, and Telegram surfaces reuse the same `ErrorStateView` / `LoadingStateView` / empty pattern with their own copy.)
- **Loading copy:** `LoadingStateView(label:)` "Loading your tasks…"; `InlineLoadingRow(label:)` defaults to `common.loading` = "Loading…"; `loadingOverlay` "Refreshing…". The overlay scrim is `theme.textPrimary.opacity(0.08)` (warm ink), spinner on `.glassEffect(.regular, in: .rect(cornerRadius: 20))`.
- **Error copy:** `ErrorStateView.networkFailure(retry:)` → `error.somethingWrong` = "Something went wrong" + `error.network.unreachable` = "We couldn't reach the server. Check your connection and try again." + `common.retry` = "Retry". Retry button hidden when `retry == nil` (non-recoverable, e.g. a report with no completed tasks → title "Nothing to report", icon `chart.bar.xaxis`).
- **Banner model:** `AppNotification { severity, title, message?, detail?, dismissal, isExpandable }` rendered by `NotificationBanner`. Severity → role: info=`--info`, success=`--success`, warning=`--warning`, error=`--danger`; icons `info.circle.fill` / `checkmark.circle.fill` / `exclamationmark.triangle.fill` / `xmark.octagon.fill`. `.info`/`.success` auto-dismiss (4s); `.warning`/`.error` permanent. Expandable **iff `detail != nil`** — the expand affordance toggles **"Show details"/"Show less"** (`notification.showDetails` / `notification.showLess`) in `--accent-text`; the detail body is the raw HTTP status + JSON response in JetBrains Mono `code`, `textSelection` enabled.

**State / edge coverage to render:**
- **Decision matrix to encode visually:** full-page first-load failure → `ErrorStateView`; transient failure during an interaction → a **banner**, not a page; nothing yet to show → **empty**; more streaming in → **`InlineLoadingRow`**; blocking refresh of on-screen content → **`loadingOverlay`**.
- **Long titles / overflow:** in the error banner, a long event title (e.g. "Quarterly planning sync with the design and platform teams") truncates the collapsed message to `lineLimit(2)`; expanded reveals full `detail`. Empty-state descriptions wrap, never clip.
- **Offline:** the warning banner ("Working offline") models offline; the error page models an unreachable server with retry.
- **Empty banner stack:** when no notifications exist, the top overlay is fully transparent and **non-hit-testing** (does not block the app).
- **Recurring / all-day:** not surfaced in this kit (no event rows); referenced only as content inside the loading-card example.

---

## Interactions & motion

- **Banner expand/collapse:** tap an expandable (error/warning with `detail`) banner body → `detail` reveals + chevron rotates 0↔180°, `.snappy` (~0.3s spring-ish). **Reduce Motion:** cross-fade the detail block in, no chevron rotation — toggle visibility with `.opacity`.
- **Banner dismiss:** tap the trailing `xmark`, **or swipe up** (DragGesture, threshold ~30pt upward) → banner removed with `.move(edge: .top).combined(with: .opacity)`. Auto-dismiss banners run a cancellable 4s timer; any manual dismiss cancels it. **Reduce Motion:** fade only, drop the slide.
- **`loadingOverlay` show/hide:** `.snappy` with `.opacity` transition on `isLoading`. **Reduce Motion:** instant cross-fade.
- **Spinners:** `ProgressView` is system-standard indeterminate motion; honor the system "Reduce Motion" automatically (no custom spin).
- **CueButton press (Retry / New group):** 1px **downward letterpress depress** (offset, no scale/glow/shadow), `.easeOut(0.16)`. Pressed fills: `.secondary` → `--surface-sunken`; `.primary` → `--primary-pressed`. **Reduce Motion:** keep the offset (it's a value change, not motion) but it's already minimal.
- **No wax-seal animation here** — the gallery has no commit moment. (When this kit is reused on a screen that commits, the seal's `.spring(0.42, 0.62)` scale 0.4→1 / rotation −8°→0° applies, with a Reduce-Motion cross-fade fallback since `WaxSeal.swift` currently applies the spring unconditionally.)

---

## iOS specifics

- **Dynamic Type:** every label uses a relative text style (`titleM`/`callout`/`code` via `.cueText`) — text scales to AX sizes. Empty-state stacks reflow vertically and wrap; the error message wraps; the banner message goes from `lineLimit(2)` to full when expanded. Never clip or truncate-without-recourse.
- **Haptics (`.sensoryFeedback`):** `.success` when a `.success` banner posts (event saved); `.warning`/`.error` notch when those post; `.selection` on banner expand toggle. The Retry tap triggers `.impact` on commit. Respect the system haptic setting.
- **Context menus / swipe actions:** none in the gallery itself — but the banner's swipe-up-to-dismiss is the only gesture, with the visible `xmark` as the discoverable fallback. (On real screens this kit lives over, leading swipe = complete, trailing-full = delete; not modeled here.)
- **VoiceOver:**
  - Empty states: the icon is decorative (`accessibilityHidden`); title + description combine into one element, e.g. "No tasks. Nothing scheduled for this day."
  - `LoadingStateView` / `InlineLoadingRow`: combined element announcing the label (or "Loading…").
  - Banners: combined element labelled **"<severity prefix>. <title>. <message>"** (e.g. "Error. Couldn't save event. The server rejected the request."), trait `.isButton` when expandable, hint "Double-tap to show details / show less"; close button labelled "Dismiss". Severity is announced as a **word**, never color-only.
  - Retry: a standard button, labelled "Retry".

---

## ✦ Claude Design prompt (paste this)

```
Design ONE fixed iPhone screen (393×852pt @3x, NOT responsive — a native iOS reference
gallery, not a web page) titled "States kit". Use the published "Kraft & Ink" design
system and its tokens ONLY — no new colors, fonts, gradients, or pure white/black.

PURPOSE: a scrollable gallery showing every reusable non-content state CUE (an AI-assisted
calendar app) shares across screens: empty placeholders, loading affordances, a full-page
error, an inline pagination row, and the four notification-banner severities. Each block has
a small uppercase eyebrow label (Public Sans label role, --text-secondary) on a faint
--surface-sunken strip, then the live component on the white --background page.

FRAME: iOS status bar (time left; Wi-Fi + battery right); Dynamic Island reserved in the
center — keep content clear of it. Top safe area ~59pt, 34pt home-indicator gutter, 16pt
side margins, tap targets ≥44pt. Inline nav bar "States kit" (Fraunces ~17pt) with a leading
back chevron, no trailing actions. Bottom: a floating WARM Liquid-Glass tab bar (re-tinted
toward kraft/clay, never cool blue), 3 tabs — Today / Calendar / Settings — plus a separated
"+" action item, inset ~21pt. Notification banners render in a SEPARATE top overlay above
all chrome, anchored to the top safe area.

LAYOUT (top → bottom, scrolling):

1) EMPTY STATES — two, centered, generous (--space-huge) vertical breathing room, divided by
   a faint --separator hairline:
   • Day empty: SF Symbol "circle.dashed" (~44pt, --text-secondary), title "No tasks"
     (Fraunces titleM, --text-primary), description "Nothing scheduled for this day."
     (Public Sans callout, --text-secondary). No button.
   • Groups empty: SF Symbol "folder", title "No Groups", description
     "Tap + to create your first group.", then ONE CueButton(.secondary) labelled
     "New group" with a leading "plus" (clear fill, 1px --border, espresso --primary label).

2) LOADING — three affordances stacked:
   • LoadingStateView: large spinner tinted --primary, caption "Loading your tasks…"
     (callout, --text-secondary), centered.
   • InlineLoadingRow: a small CueCard "list" with one real row "Standup notes — Thu",
     then a small centered spinner + "Loading more…" (caption, --text-secondary) as a footer.
   • loadingOverlay: a CueCard showing the task "Pay rent" covered by a WARM-INK scrim
     (--text-primary at 8% opacity, NOT black) with a glass-backed spinner card (radius 20)
     reading "Refreshing…".

3) ERROR (full page): SF Symbol "wifi.exclamationmark", title "Something went wrong"
   (Fraunces titleM), message "We couldn't reach the server. Check your connection and try
   again." (callout, centered), and a Retry button rendered as CueButton(.secondary) — clear
   fill + 1px --border + espresso --primary label. DO NOT use a system blue/tinted prominent
   button (this is a known gap we are fixing).

4) NOTIFICATION BANNERS — all four severities as a vertical stack. Each is INTENTIONALLY
   Liquid Glass (radius 8, warm-tinted — distinct from the letterpress cards), with a 4px
   leading severity Capsule rail + a severity glyph + a title (Public Sans bodyEmphasis,
   --text-primary) + message (callout, --text-secondary) + a trailing "xmark" close
   (--text-secondary):
   • info — rail/icon --info espresso, "info.circle.fill": "Calendar synced" ·
     "Your calendar is up to date."
   • success — --success olive, "checkmark.circle.fill": "Event saved" ·
     "Dentist at 3:00 PM was added."
   • warning — --warning brass, "exclamationmark.triangle.fill": "Working offline" ·
     "Changes will sync when you reconnect."
   • error (EXPANDED) — --danger brick, "xmark.octagon.fill": "Couldn't save event" ·
     "The server rejected the request." Show a top Divider then a JetBrains Mono (code role)
     detail block: HTTP 422  {"message":["title should not be empty"]}, and a "Show less ⌄"
     disclosure in --accent-text with the chevron rotated 180°.

REAL CONTENT (verbatim, no lorem / no "Item 1"): the exact strings above — "No tasks",
"Nothing scheduled for this day.", "No Groups", "Tap + to create your first group.",
"Loading your tasks…", "Standup notes — Thu", "Pay rent", "Refreshing…",
"Something went wrong", "Calendar synced", "Event saved", "Dentist at 3:00 PM was added.",
"Working offline", "Couldn't save event".

TYPOGRAPHY: Fraunces for titles ≥17pt (titleM 18 medium). Public Sans for body/labels/buttons
(bodyEmphasis = banner titles & button labels; callout = descriptions; label = eyebrows).
JetBrains Mono for the error detail body. Never Inter / SF Pro.

DEPTH: letterpress only on cards — 1px --border + hard value-cut shadow at blur-radius 0,
crisp 4–12px cut-paper corners. Banners and the tab bar are the ONLY Liquid-Glass elements.

ACCESSIBILITY: every state speaks its meaning as words, never color-only (banners announce
"Error." / "Success." prefixes). Text scales with Dynamic Type and wraps, never clips.

ANTI-AI-SLOP GUARDRAILS (hard): NO Inter / Helvetica / SF Pro as the display face — pin
Fraunces. NO purple, NO blue accents, NO gradients, NO glassmorphism on content cards, NO
soft/blurred drop shadows, NO pure #FFFFFF surface-on-white, NO pure #000000. NO generic
evenly-spaced bento grid — this is a labelled vertical reference gallery. Ration the clay
--secondary: it appears in ONE place only (the brick error banner's rail/icon as the most
salient state) plus the sanctioned --accent-text disclosure cue — NO clay-filled CTAs, NO
wax seal on this screen, NO multiplying the accent. Honor Kraft & Ink exactly; use only its
named tokens and components (CueCard, CueButton, CueChip, ErrorStateView, LoadingStateView,
NotificationBanner). Native iOS patterns throughout (status bar, inline nav, warm Liquid-Glass
tab bar, system spinners, ≥44pt targets). Don't say "modern / clean / sleek / beautiful".
```
