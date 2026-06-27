# Notifications & daily report

> The single home for CUE's daily ritual and its reminders: switch the daily report on and choose when it lands, decide whether the morning brief / evening shutdown shows up in-app AND on Telegram (one toggle), and set the default lead time for per-task reminders.

This screen is **new** in the app (pushed from Settings → "Notifications & Report", page 12). The **daily-report half is fully wired** to a real backend endpoint (`GET/PATCH /users/me/report-settings`). The **per-task reminder defaults half is design-ahead-of-backend** — the `NotificationRule` / `NotificationStrategy` schema exists, but there is **no client controller yet**, so render that section as a real, honest UI and mark it clearly (the spec calls out exactly where the wiring is missing). Render it in the **Kraft & Ink** system exactly, binding every wired element to the real backend fields named below.

---

## Design system (Kraft & Ink)

Use the published **"Kraft & Ink"** system and its tokens ONLY. No new colors, fonts, gradients, or pure white/black surfaces. Reference everything by name; never invent hex.

**Color (opaque sRGB; reference by role):**
- `--background #FFFFFF` — app canvas behind everything (the white page; the `Form` background, scroll content background hidden).
- `--surface #FAF6EF` — grouped-inset section blocks, rows (faint warm paper; never whiter than the page).
- `--surface-elevated #FEFCF8` — raised surfaces (the inline time-picker wheel tray when expanded; not heavily used).
- `--surface-sunken #F1EADF` — recessed strips: the leading icon tiles on each section, the time-value pill track, picker tracks, zebra.
- `--primary #5A3A24` (espresso) — structural tint, section icons, the time value, selected reminder-offset chip fill, selected channel segment. The backbone.
- `--primary-pressed #43291A` — pressed state of primary.
- `--secondary #BE4A28` (clay) — **FILL ONLY**, rationed. On this screen clay is spent on **exactly one accent**: the **Daily report enable toggle's ON tint** (the single decisive "this ritual is live" moment). Nowhere else. No wax seal.
- `--accent-text #A53D22` — the ONLY clay allowed as **text / icons / thin rules** (AA-safe). Optional: the "Connect Telegram" inline link when a Telegram channel is chosen but unlinked. Nowhere decorative.
- `--on-accent #FBF5EA` (cream) — ink placed on a primary/secondary fill (the selected chip text, the selected channel-segment text, the knob-side glyph if any).
- `--text-primary #2E211A` — body + headings (warm near-black): section titles, row labels, the chosen time digits.
- `--text-secondary #6E5C4C` — supporting / muted text: explanatory copy, section eyebrows, footers, the timezone caption, disabled/gated hints.
- `--separator #D0BA98` — DECORATIVE hairlines only (faint inter-row rules inside a section block, never a real edge).
- `--border #8C7142` — FUNCTIONAL edges a user must locate (section block outlines, chip outlines when unselected, the time-pill outline).
- `--success #466234` (olive) — the "Saved" confirmation tick / the live Telegram-linked affordance (a finished/agreed state).
- `--warning #C9A24B` (brass) — pending / "not yet wired" hint and the design-ahead-of-backend note background accent (FILL only; place INK on it, never cream).
- `--danger #A8331F` (brick) — a save-failure inline message (text only — no brick fill on this calm screen).
- Discipline: clay is one-hot and here spent ONLY on the report-enable toggle. Olive = saved/linked, brass = pending/unwired, espresso = structure + selection. **Color presence, not a rainbow.**

**Typography (3 bundled families — substitute via Google Fonts in preview; NEVER Inter/SF Pro):**
- **Fraunces** (display, ≥17pt only): `display-L` 34 semibold −0.4 (the "Notifications & Report" large nav title when not truncated — render inline ~17pt on a pushed screen), `title-L` 22 medium −0.2, `title-M` 18 medium −0.2 (section card titles like "Daily report", "Daily brief & shutdown", "Reminders"), `headline` 17 medium (an emphasised lead line inside a card).
- **Public Sans** (body/labels): `body` 16 regular (row labels — "Daily report", "Send time", "Show on Today & Telegram"), `body-emph` 16 semibold (button labels, "Save"), `callout` 15 regular (the explanatory paragraph under each toggle, supporting copy), `label` 13 medium +0.3 (section-header eyebrows — `textCase(nil)`, never SCREAMING CAPS; chip text; the channel-segment labels), `caption` 12 regular (footers, the timezone line, the design-ahead note).
- **JetBrains Mono** (receipt voice — times, offsets, IDs): `code` 13 regular +0.2 (the `08:30` send-time value, the `10 min` reminder offset chips, the `Europe/Vilnius` timezone), `code-small` 11 medium +0.8 (micro-labels like the "before" suffix on an offset).
- Rule: Fraunces is the editorial voice for titles ≥17pt — never for dense labels/body. **Every time-of-day, every minute-offset, and the timezone read in JetBrains Mono** (receipt voice, wider tracking). Section eyebrows are Public Sans `label` with system uppercasing **suppressed** (`textCase(nil)`) so they read as typeset headings, not iOS shout-caps.

**Spacing (4pt grid):** `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 (default gap / row inner) · xl 20 · xxl 24 (between sections) · xxxl 32 · huge 48`. 16pt side margins (grouped-inset blocks inset from the page edge). Let the paper breathe between sections; the explanatory copy under each toggle gets `md 12` from its row.

**Radius (crisp cut-paper, never squircle bubbles):** `chip 4 (the reminder-offset chips — rubber-stamp, never a pill) · small 6 (default — the time pill, the channel segmented control) · medium 8 (the grouped section blocks + the leading icon tiles) · card 10 · large 12`. Grouped-inset section blocks = `medium 8`, NOT the iOS-default 10–12 squircle. The reminder chips are `chip 4`, NOT pills.

**Depth — "letterpress, not float" (blur radius 0 always):**
- `letterpress` (default) = 1pt `--border` stroke + hard `--text-primary @6%` value-cut, y:1 — applied to each grouped section block (a crisp pressed card of rows, not a floating bubble).
- `value-cut` = 1pt `--border` + `--text-primary @12%`, y:2 (reserved; the inline time-picker tray may use it when expanded to read as a stacked sheet — optional).
- NO soft uniform drop shadows anywhere. System **Liquid Glass** (frosted) is ONLY the chrome (tab bar, nav bar), re-tinted **warm** toward kraft/clay — never Apple's cool blue-grey. The `Form`/rows themselves are letterpress paper, never glass.

**Components (by name):**
- **CueCard** — the grouped section block: fill `--surface`, radius `medium 8`, letterpress depth; rows divided by faint 1pt `--separator` inset hairlines. Optional `--surface-sunken` header strip with a `title-M` Fraunces title.
- **CueChip** — the **reminder-offset chips** (`None` / `At time` / `5 min` / `10 min` / `30 min` / `1 hr` / `1 day`) and the **channel chips/segments** (`Push` / `Telegram`). 4pt rubber-stamp rectangle, NEVER a pill, NEVER pill-with-a-dot. Selection by fill+ink: unselected = `--surface` fill + `--text-secondary` + 1pt `--border`; selected = `--primary` espresso fill + `--on-accent` cream, no border. Offset values render in JetBrains Mono `code`.
- **CueButton** — `.primary` espresso for any explicit "Save" affordance if the screen isn't fully optimistic-on-toggle; on this screen saves are **optimistic per-control**, so a footer Save button is optional (prefer instant-commit toggles). The toggle itself is a native `Toggle` re-tinted (see below).
- **WaxSeal** — **NOT present** on this screen. This is a settings surface with no single "commit-and-stamp" moment; the seal is reserved for completing a task and saving an event only. Do NOT invent one.
- **Leading icon tiles** — each section leads with a small `--surface-sunken` rounded-rect tile (radius `medium 8`, ~28pt) holding an SF Symbol in `--primary` (espresso): `bell.badge.fill` (daily report), `sun.max.fill` / `sparkles` (brief & shutdown), `alarm.fill` / `clock.badge` (reminders). Tiles, not bare glyphs.
- **Native `Toggle`** — re-tinted: the **Daily report enable** toggle uses **clay `--secondary`** as its ON track (the rationed accent). The **brief & shutdown** toggle and the **Telegram-channel** toggles use **espresso `--primary`** as the ON track (structural, so they never compete with the one clay moment). Knob is cream `--on-accent` over a `--surface-sunken` OFF track.

---

## Frame & platform

- **Single fixed iPhone 393×852pt @3x. NOT responsive** — a native iOS 26 screen, not a web page.
- iOS status bar at top (time left, cellular/wifi/battery right). **Dynamic Island reserved** (don't draw under it). Top safe area ~59pt. 34pt home-indicator gutter at the bottom; keep content clear of it.
- 16pt side margins; grouped-inset section blocks inset from the page edge. All tap targets ≥44pt (every row, every chip ≥44pt; chips may be ~44pt tall with `sm 8` vertical padding).
- **Nav chrome — this is a PUSHED screen** (stack-push from Settings, page 12). Inline ~17pt nav title **"Notifications & Report"** in Fraunces (`headline`/inline, `--text-primary`) with a **leading back chevron + "Settings" label** (espresso `--primary`). NO large title (a drill-down, not a tab root). NO trailing nav-bar action (no search — search lives on Today/Calendar only).
- **Bottom: floating warm-tinted Liquid-Glass tab bar**, ~21pt insets from sides/bottom, fully expanded. THREE merged destination tabs + ONE separated trailing action capsule:
  - `Today` (`sun.max`-style), `Calendar` (`calendar`), `Settings` (`gearshape`, **selected** — espresso ink, because this screen lives inside the Settings stack).
  - Separated to the right in its own capsule: **"+"** (`plus.circle.fill`) — an *action item* that opens the Create sheet over the current tab; never a destination, never shows selected.
- **One-handed reach:** the most-tapped controls — the report enable toggle, the send-time pill, and the brief toggle — sit in the upper-middle thumb arc; the design-ahead reminder defaults sit lower (read-mostly today). Nothing destructive on this screen, so no mis-tap guard needed.

---

## Layout

Top → bottom. A native grouped `Form` (inset style) over `--background` with the scroll background hidden, 16pt side margins, `--space-xxl (24)`-ish between section blocks. Real CUE content — no lorem. The example state below shows the report **enabled** at **08:30**, the brief/shutdown ritual **on (in-app + Telegram)**, and reminders defaulting to **10 minutes before** via **Telegram**, with timezone **Europe/Vilnius**.

```
┌──────────────────────────────────────────────┐
│ ●●●  9:41                       ▂▄ 􀙇 100%▐     │  status bar (Dynamic Island reserved)
│  ‹ Settings    Notifications & Report          │  inline nav title (Fraunces ~17pt) + back
│                                                │
│  Daily report                                  │  section eyebrow (label, textCase nil)
│ ┌────────────────────────────────────────────┐ │
│ │ ▦ bell   Daily report            [ ●===○ ] │ │  Toggle — ON track = CLAY --secondary
│ │  ─────────────────────────────────────────  │ │  --separator inset hairline
│ │           Send time              [ 08:30 ] │ │  mono time pill (sunken track) — tap = wheel
│ └────────────────────────────────────────────┘ │
│  A short briefing of your day, sent at this    │  footer callout, --text-secondary
│  time in Europe/Vilnius.                        │  timezone in JetBrains Mono code
│                                                │
│  Daily brief & shutdown                        │
│ ┌────────────────────────────────────────────┐ │
│ │ ▦ sun    Show on Today & Telegram  [ ●==○ ]│ │  Toggle — ON track = ESPRESSO --primary
│ └────────────────────────────────────────────┘ │
│  Your morning brief and evening shutdown appear │  explanatory callout, --text-secondary
│  as a card on Today and (if linked) as a        │
│  Telegram message. One switch controls both.    │
│                                                │
│  Reminders                                     │  section eyebrow
│ ┌────────────────────────────────────────────┐ │
│ │ ▦ alarm  Default reminder                  │ │  title row (body) + sunken icon tile
│ │  ─────────────────────────────────────────  │ │
│ │   [None] [At time] [5 min] [10 min]◍       │ │  CueChips (chip 4), "10 min" SELECTED
│ │   [30 min] [1 hr] [1 day]                   │ │  mono offsets, espresso selected fill
│ │  ─────────────────────────────────────────  │ │
│ │   Channel        [ Push | Telegram ]◍       │ │  segmented chips, "Telegram" SELECTED
│ └────────────────────────────────────────────┘ │
│  ┌──brass rail──────────────────────────────┐  │
│  │ ⚑ Reminder delivery isn't wired up yet.   │  │  design-ahead note (brass rail + ink)
│  │   These defaults are saved on-device and  │  │  caption, --text-secondary, no fill shout
│  │   apply once notifications ship.          │  │
│  └───────────────────────────────────────────┘  │
│                                                │
│        (34pt home-indicator gutter)            │
│   ┌─────────────────────────┐   ┌───┐          │
│   │  Today   Calendar  Settings│  │ + │         │  floating warm Liquid-Glass tab bar
│   └─────────────────────────┘   └───┘          │  Settings selected + separated "+"
└──────────────────────────────────────────────┘
```

**Region detail (top → bottom):**

1. **Daily report section** (eyebrow `Daily report`, Public Sans `label`, `--text-secondary`, `textCase(nil)`). A CueCard block with two rows:
   - **Daily report** row — leading `--surface-sunken` icon tile with `bell.badge.fill` (`--primary`), label `Daily report` (Public Sans `body`, `--text-primary`), trailing a native **`Toggle` whose ON track is CLAY `--secondary`** (the screen's one rationed clay moment). Bound to `ReportSettingsDTO.enabled`. This is the master switch — when OFF, the **Send time** row dims (`opacity 0.5`, non-interactive) but stays visible (don't collapse the layout).
   - **Send time** row — label `Send time` (`body`, `--text-primary`) trailing a **time value pill**: a `--surface-sunken` rounded-rect (radius `small 6`, 1pt `--border`) holding `08:30` in **JetBrains Mono `code`** (`--text-primary`). Tapping the pill reveals an **inline `DatePicker(.hourAndMinute, displayedComponents: .wheels)`** tray below the row (graphical wheel, `--surface-elevated` tray) — NOT a modal. Bound to `ReportSettingsDTO.reportTimeLocal` (`"HH:mm"`, validated `^([01]\d|2[0-3]):[0-5]\d$`). Footer callout under the card (`--text-secondary`): *"A short briefing of your day, sent at this time in"* + `Europe/Vilnius` (the user's `User.timezone`, **JetBrains Mono `code`**, inline). The send time is a **local wall-clock minute in that timezone**, not a UTC offset — make the timezone explicit so the user trusts it.

2. **Daily brief & shutdown section** (eyebrow `Daily brief & shutdown`). A CueCard block with one row:
   - **Show on Today & Telegram** row — leading `sun.max.fill` (or `sparkles`) icon tile (`--primary`), label `Show on Today & Telegram` (`body`), trailing a native **`Toggle` with ESPRESSO `--primary` ON track** (structural — NOT clay, so it never competes with the report toggle's one clay moment). This is the **single toggle** that controls BOTH surfaces of the ritual: the in-app **morning brief / evening shutdown card on Today** (page 03) AND the optional **Telegram message**. Explanatory callout below the card (`--text-secondary`, `callout`): *"Your morning brief and evening shutdown appear as a card on Today and (if linked) as a Telegram message. One switch controls both."* If Telegram is **not linked**, append a quiet inline line (`caption`, `--accent-text` clay-as-text): *"Telegram not linked — only the Today card will show."* + a small **"Connect Telegram"** text affordance pushing to page 15.

3. **Reminders section** (eyebrow `Reminders`). A CueCard block — **the per-task reminder DEFAULTS** (what a new task inherits before you customise it). Two sub-rows inside the card:
   - **Default reminder** title (`body`, `--text-primary`) with the `alarm.fill` / `clock.badge` icon tile, then a **horizontal wrap of CueChips** mapping to `NotificationRule.offsetMinutes`: `None` (no rule) · `At time` (`offsetMinutes 0`) · `5 min` (`-5`) · `10 min` (`-10`, **selected in the example**) · `30 min` (`-30`) · `1 hr` (`-60`) · `1 day` (`-1440`). Chips are `chip 4` rubber-stamp rectangles; the numeric offsets render in **JetBrains Mono `code`** with a `code-small` "before" feel; selected chip = espresso `--primary` fill + cream. (Negative `offsetMinutes` = "before start" per the entity doc.)
   - **Channel** sub-row — label `Channel` (`body`) + a **two-segment control / two chips** `Push` | `Telegram` mapping to `NotificationChannel.PUSH` / `NotificationChannel.TELEGRAM`. Selected segment = espresso `--primary` fill + cream (`Telegram` selected in the example). The **`Telegram` segment is GATED when Telegram is not linked** — rendered disabled (`opacity 0.5`) with a tap routing to "Connect Telegram" (page 15), exactly like the report's Telegram dependency.
   - **Design-ahead-of-backend note** below the card — a brass-railed caption (a 4pt `--warning` leading rail, NO brass fill behind the text; ink `--text-primary`/`--text-secondary` per the "place INK on brass" rule): *"⚑ Reminder delivery isn't wired up yet. These defaults are saved on-device and apply once notifications ship."* This is the honest flag the spec demands: the `NotificationRule` / `NotificationStrategy` schema exists on the backend, but **there is no client controller** — so the section is real UI, persisted locally (`@AppStorage` / a local store), not yet PATCHed to the server.

**Rationed clay placement:** **ONE clay moment** — the **Daily report enable toggle's ON track** (`--secondary`). That is the single "this ritual is live" accent. Everything else is espresso (structure, selected chips, the brief/Telegram toggles), olive (saved/linked), brass (the design-ahead note rail), warm paper. The optional clay-as-**text** (`--accent-text`) appears only on the "Connect Telegram" inline affordance. **No wax seal anywhere.**

---

## Data & states

Bind every wired element to these exact backend shapes (DTOs to be added to `Networking/APIModels.swift`, mirroring the existing `TelegramLinkStatusDTO` pattern; a `ReportSettingsStore` mirrors `TelegramLinkStore` — `@Observable @MainActor`, shared `APIClient`, optimistic writes surfacing failures as `NotificationStore` banners).

| UI element | Source field / endpoint |
|---|---|
| Daily report enable toggle | `ReportSettingsDTO.enabled` (`Bool`) via `GET /users/me/report-settings`; write via `PATCH /users/me/report-settings { enabled }` (`UpdateReportSettingsDto`) |
| Send-time pill / wheel | `ReportSettingsDTO.reportTimeLocal` (`"HH:mm"`, 24-hour, e.g. `"08:30"`); write via `PATCH … { reportTimeLocal }`; client must format/validate against `^([01]\d|2[0-3]):[0-5]\d$` before sending (server returns 400 on malformed) |
| Timezone caption | `UserDTO.timezone` (IANA, e.g. `"Europe/Vilnius"`) — display-only; the report fires at the local wall-clock minute in this zone |
| Brief & shutdown toggle | a single user preference controlling the Today ritual card (page 03) + the optional Telegram message. **Backend note:** the Telegram brief IS the daily report (`report-sender.service` → a 2–4 sentence warm briefing). For v1 design, treat this as **one preference**: if the screen ships before a dedicated `briefEnabled` field, bind the in-app card visibility to a local pref and the Telegram side to `ReportSettingsDTO.enabled`. **Flag in the spec that the unified field is a small additive BE change.** |
| Telegram-linked gating | `TelegramLinkStore.status` — `.connected` unlocks the Telegram channel option and the Telegram side of the brief; `.notConnected` / `.failed` gates them (cross-reference page 15) |
| Default reminder offset chips | `NotificationRule.offsetMinutes` (`Int`, negative = before start; `0` = at start; `None` = no rule) — **schema-only, NO client endpoint** → persisted locally (`@AppStorage`/local store) |
| Reminder channel segments | `NotificationChannel.PUSH` / `NotificationChannel.TELEGRAM` — **schema-only** → persisted locally; `TELEGRAM` gated on link status |

**States to render (produce variants):**
- **Default (populated, report enabled)** — the example above: toggle ON (clay track), send time `08:30`, timezone `Europe/Vilnius`, brief ON (espresso track), reminder default `10 min` via `Telegram`, design-ahead note present.
- **Report disabled** — enable toggle OFF; the **Send time** row dims to `opacity 0.5` and stops responding to taps, but stays in place (layout doesn't jump). Footer copy stays. The brief & shutdown section is independent — it does NOT dim with the report toggle (different preference).
- **Loading (cold read)** — on first mount, while `GET /users/me/report-settings` resolves: the Daily report card shows a quiet espresso `ProgressView` in place of the toggle/time values (or a `redacted(reason: .placeholder)` shimmer on the two rows). The rest of the page (brief, reminders) is interactive immediately (independent of the report fetch). No full-screen spinner.
- **Saved / optimistic** — flipping the toggle or committing a new time updates the UI **immediately** and PATCHes in the background. On success, a brief olive `--success` checkmark/affordance pulses near the row (≤1s) or a quiet "Saved" banner via `NotificationStore`. No blocking overlay for a single-field save.
- **Error (save failed)** — the optimistic change **reverts** to the last server value and a `NotificationStore` error banner surfaces (*"Couldn't save your report settings."*); an inline `--danger` (brick) caption may also appear under the affected row (text only, no fill). The toggle/time snaps back so the UI never lies about persisted state.
- **Telegram not-linked (gating)** — the **Telegram** reminder-channel segment renders disabled (`opacity 0.5`); tapping it routes to **Connect Telegram (page 15)** instead of selecting. The brief section's Telegram line reads *"Telegram not linked — only the Today card will show."* with a **Connect Telegram** affordance (`--accent-text`). The daily-report toggle itself is **still usable** — the report can be on even before Telegram is linked (it just won't deliver to Telegram until linked); make that honest, don't hard-block the toggle.
- **Design-ahead-of-backend (reminders)** — ALWAYS show the brass-railed note under the Reminders card. The chips/segments are fully interactive and persist locally, but the note makes clear delivery isn't wired (`NotificationRule` is schema-only; no controller). Never imply a server round-trip happens for reminders today.
- **Edge cases:**
  - *Malformed/empty time* → never let the wheel produce an out-of-range value; clamp to a valid `HH:mm`; never PATCH a string the server would 400 on.
  - *Offline* → toggles/time keep the last-known value; a failed PATCH reverts + banners; reminder chips (local) still persist.
  - *Missing report data on first paint* → trailing values render blank/redacted (never a placeholder dash that looks like a real value) until the GET lands.

---

## Interactions & motion

- **Daily report toggle** → tapping flips instantly (native `Toggle`), the **clay `--secondary`** ON track sliding in; the PATCH fires optimistically. `.sensoryFeedback(.selection)` on the flip; `.sensoryFeedback(.success)` only when the save confirms. **Reduce-Motion:** the track color swaps without the knob-slide easing (instant). When toggled OFF, the **Send time** row cross-fades to `opacity 0.5` (`.easeOut` ≤160ms) and disables; ON cross-fades it back.
- **Send-time pill** → tapping the `08:30` pill expands an **inline wheel `DatePicker`** below the row with a gentle `.snappy` height reveal (the tray reads as a stacked sheet, `value-cut` depth). Spinning the wheel updates the pill's mono value live; the PATCH commits on **wheel settle** (debounced ~400ms after the last change), not on every tick, to avoid PATCH spam. `.sensoryFeedback(.selection)` on each detent tick (respecting the system haptic setting). Tapping the pill again (or scrolling away) collapses the tray. **Reduce-Motion:** the tray appears/disappears without the height animation.
- **Brief & shutdown toggle** → identical mechanics with the **espresso `--primary`** track (structural). Flipping it shows/hides the Today ritual card (page 03) and toggles the Telegram side; instant, optimistic. `.sensoryFeedback(.selection)`.
- **Reminder offset chips** → single-select; tapping a chip swaps the selected fill to espresso `--primary` + cream with the standard `.easeOut(0.16)` CueChip fill swap (no scale, no glow). Selecting `None` clears the default. Persists locally (no network). `.sensoryFeedback(.selection)`.
- **Channel segments** → `Push` / `Telegram` single-select, same fill swap. Selecting `Telegram` while unlinked does NOT select — it routes to page 15 (with `.sensoryFeedback(.selection)` suppressed, since nothing was selected).
- **Optimistic save + revert on failure** → every wired write (report enable, time, brief) updates the UI first, then PATCHes. On failure the control **animates back** to the prior value (`.easeOut`) and a banner explains; never leave the UI showing an unsaved-but-displayed state. `.sensoryFeedback(.error)` on the revert.
- **No wax-seal animation on this screen** — there is no commit-and-stamp moment. Do not invent one.

---

## iOS specifics

- **Dynamic Type:** every text style is relative (`relativeTo:`) — section titles, row labels, the mono time/offset values all scale. At AX sizes: the Send-time row lets the mono time pill drop **below** its label (label-over-value stack) rather than squeezing; the reminder-offset chips **wrap to multiple rows** (already a wrap layout) and never clip the mono digits; the channel segments may stack vertically if the row gets tall. Every row stays ≥44pt; the icon tile stays ≥28pt.
- **Haptics (`.sensoryFeedback`):** `.selection` on every toggle flip, chip select, channel select, and each time-wheel detent tick; `.success` when a save confirms (report enable / time / brief); `.error` on an optimistic revert. Respect the system haptic setting. No `.impact`-heavy feedback — this is a calm settings surface.
- **VoiceOver labels:**
  - Daily report toggle: *"Daily report, on. Switch."* / *"…, off. Switch."*
  - Send time: *"Send time, 8:30 AM. Adjusts in Europe Vilnius time. Button."* (speak a human time, not the raw `HH:mm`; name the timezone so the meaning is unambiguous).
  - Brief toggle: *"Show daily brief and shutdown on Today and Telegram, on. Switch."* When Telegram unlinked, the hint reads *"Telegram not linked. Only the Today card will show."* and the affordance: *"Connect Telegram. Button."*
  - Reminder offset chips: each *"10 minutes before, selected. Button."* / *"30 minutes before. Button."*; `None` → *"No reminder."*; `At time` → *"At start time."*
  - Channel: *"Channel, Telegram, selected. Button."*; the disabled Telegram segment: *"Telegram. Connect Telegram to enable. Dimmed."*
  - The design-ahead note reads as static text: *"Reminder delivery isn't wired up yet. These defaults are saved on this device and apply once notifications ship."*
  - Never convey meaning by color alone — the report toggle states its on/off in words; the gated Telegram option states "Connect Telegram to enable," not just a dim tint.
- **Links to Connect Telegram:** any time a Telegram option is **chosen-but-unlinked** (the brief's Telegram side, the reminder Telegram channel), surface a clear **"Connect Telegram"** affordance (`--accent-text` clay-as-text) that pushes **page 15** onto the Settings stack — never silently no-op. Mirror page 12's live `TelegramLinkStore.status` so the gating updates the moment a link completes.

---

## ✦ Claude Design prompt (paste this)

```
SCREEN: Notifications & daily report — CUE's single home for the daily report (Telegram briefing
on/off + send time), the morning-brief/evening-shutdown ritual (one toggle for the in-app Today card
AND the optional Telegram message), and the per-task reminder DEFAULTS (offset + channel). Pushed
from Settings.

SYSTEM: Use the published "Kraft & Ink" design system and its tokens ONLY. No new colors, fonts,
gradients, or pure white/black surfaces. This screen spends EXACTLY ONE clay --secondary accent —
the Daily-report ENABLE toggle's ON track — and has NO wax seal (no commit-and-stamp moment).
Reference tokens and components by NAME.

FRAME: Single fixed iPhone 393×852pt @3x. NOT responsive — a native iOS 26 screen, not a web page.
iOS status bar (time + battery; Dynamic Island reserved). Top safe area ~59pt; 34pt home-indicator
gutter; 16pt side margins; all tap targets >=44pt. This is a PUSHED screen: inline ~17pt nav title
"Notifications & Report" in Fraunces with a leading back chevron + "Settings" label (espresso), NO
large title, NO trailing nav action. Bottom: floating WARM-tinted Liquid-Glass tab bar (never
minimizes) — three merged tabs Today / Calendar / Settings (Settings SELECTED, espresso ink, since
this lives in the Settings stack), plus a SEPARATED trailing "+" action capsule (plus.circle.fill).

AUDIENCE: a signed-in user deciding whether CUE messages them each morning, when, and how reminders
should default — visiting occasionally, not daily.

LAYOUT (top -> bottom, native grouped-inset Form on --background, ~24pt between section blocks; each
block is a CueCard: --surface fill, radius 8, letterpress depth (1px --border + hard value-cut, blur
0), rows divided by faint 1pt --separator inset hairlines; each section leads with a ~28pt
--surface-sunken rounded icon tile holding an espresso SF Symbol):
  1. "Daily report" eyebrow (Public Sans label 13, --text-secondary, NOT uppercased). Block, two rows:
       - bell.badge.fill tile + "Daily report" (Public Sans body) + a native Toggle whose ON TRACK is
         CLAY --secondary (the screen's ONE rationed clay moment).
       - "Send time" (body) + a time value pill: --surface-sunken rounded-rect (radius 6, 1px --border)
         showing "08:30" in JetBrains Mono. Tap reveals an INLINE wheel DatePicker (.hourAndMinute,
         .wheels) below the row — not a modal. When the report toggle is OFF, this row dims to 50%
         opacity and disables but stays in place.
     Footer callout (--text-secondary): "A short briefing of your day, sent at this time in" +
     "Europe/Vilnius" (the timezone in JetBrains Mono).
  2. "Daily brief & shutdown" eyebrow. Block, one row: sun.max.fill tile + "Show on Today & Telegram"
     (body) + a native Toggle with ESPRESSO --primary ON track (structural — NOT clay). Explanatory
     callout below (--text-secondary): "Your morning brief and evening shutdown appear as a card on
     Today and (if linked) as a Telegram message. One switch controls both." If Telegram is NOT linked,
     add a quiet line in --accent-text: "Telegram not linked — only the Today card will show." + a
     "Connect Telegram" text affordance.
  3. "Reminders" eyebrow. Block: alarm.fill tile + "Default reminder" (body), then a WRAPPING row of
     CueChips (chip 4, rubber-stamp, NEVER pills) with mono offsets: None / At time / 5 min / 10 min
     (SELECTED) / 30 min / 1 hr / 1 day — selected = espresso --primary fill + cream. Then a "Channel"
     sub-row with a two-segment control Push | Telegram (Telegram SELECTED) — selected = espresso fill
     + cream; the Telegram segment is DISABLED (50% opacity) when Telegram isn't linked and taps route
     to Connect Telegram. BELOW the card: a brass-railed note (a 4px --warning leading rail, NO brass
     fill behind text, ink in --text-secondary): "Reminder delivery isn't wired up yet. These defaults
     are saved on-device and apply once notifications ship."
  Bottom: floating warm Liquid-Glass tab bar — Today / Calendar / Settings (selected) + separated "+".

COMPONENTS (by name): CueCard (the section blocks), native Toggle re-tinted (clay --secondary ON for
the report enable; espresso --primary ON for brief & shutdown), an inline wheel DatePicker for the
send time, CueChip (reminder-offset chips + channel segments), leading --surface-sunken icon tiles
with espresso SF Symbols. NO WaxSeal, NO filled CueButton CTA — saves are optimistic per-control.

REAL CONTENT (verbatim — no lorem, no "Item 1"): rows "Daily report", "Send time" = "08:30",
timezone "Europe/Vilnius"; "Show on Today & Telegram"; reminder offsets None / At time / 5 min /
10 min (selected) / 30 min / 1 hr / 1 day; channel Push | Telegram (Telegram selected). Section
eyebrows: Daily report / Daily brief & shutdown / Reminders. Times and offsets in JetBrains Mono.

NATIVE PATTERNS: grouped-inset Form; native Toggles committing optimistically; an inline wheel
DatePicker (.hourAndMinute) for the time (not a modal); single-select chips with the CueChip fill
swap; .sensoryFeedback(.selection) on toggles/chips and (.success) on save / (.error) on revert; a
back chevron pushing from Settings. All rows and chips >=44pt.

STATE: Show the populated default (report ENABLED at 08:30, brief ON, reminder default "10 min" via
Telegram, design-ahead note present). ALSO produce: report DISABLED (Send-time row dimmed to 50% but
present); LOADING cold read (espresso spinner/redacted on the report rows, rest interactive); SAVED
(quiet olive --success confirmation); ERROR (optimistic value reverts + a banner + brick inline
caption); Telegram NOT-LINKED (Telegram channel segment dimmed/gated routing to Connect Telegram, the
brief's Telegram line shown).

ANTI-AI-SLOP GUARDRAILS (hard): Fraunces for titles >=17pt ONLY (section card titles + the inline nav
title); Public Sans for all row labels/body/explanatory copy; JetBrains Mono for EVERY time-of-day,
every minute-offset, and the timezone — NEVER Inter or SF Pro. Section eyebrows are Public Sans label
with uppercasing SUPPRESSED (typeset, not iOS shout-caps). Letterpress depth = 1px --border + hard
value-cut (blur 0) on the section blocks — NO soft drop shadows, NO gradients, NO glassmorphism on
content (glass is chrome-only and WARM-tinted, never Apple cool blue). NO purple, NO neon, NO blue
accents, NO pure #FFFFFF cards-on-white, NO pure #000000. Grouped blocks + icon tiles use crisp 8px
cut-paper corners; reminder chips are 4px rubber-stamp rectangles, NEVER pills, NEVER pill-with-a-dot.
SPEND CLAY --secondary on EXACTLY ONE thing — the Daily-report enable toggle's ON track — and NOTHING
else; all other selected toggles/chips fill espresso --primary so they never compete. NO wax seal —
this screen has no commit moment; do NOT invent one. Olive --success = saved/linked; brass --warning
= the design-ahead note (place INK on brass, never cream). Never convey state by color alone (toggles
say on/off in words; the gated Telegram option says "Connect Telegram to enable"). Native iOS 26
patterns throughout. Don't describe it as "modern/clean/sleek/beautiful".
```
