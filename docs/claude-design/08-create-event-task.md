# Create event / task (merged)

One bottom sheet that creates either an event or a task — with live natural-language quick-create up top and a wax-seal "make it stick" save at the bottom. Event vs task is a single `requiresCompletion` toggle; the backend stores both as one `Task` primitive (`POST /tasks`).

> Mirrors the implemented `NewEventScreen` / `NewEventViewModel` (`cue/Features/Calendar/NewEvent/`) and the shared `RecurrenceSection` (`cue/Features/Calendar/TaskDetail/TaskEditScreen.swift`). Field names, chips, duration presets, and the saving-overlay seal are taken verbatim from code. New for this design: the NL quick-create bar and the per-task reminder row (`NotificationRule` schema exists; client controller is a follow-up).

---

## Design system (Kraft & Ink)

Use the published **"Kraft & Ink"** system and these tokens ONLY. Do not invent colors, fonts, gradients, or pure white/black surfaces.

**Color (opaque sRGB, by role — reference by name, never hex):**
- `--background #FFFFFF` — app canvas / behind the sheet's content.
- `--surface #FAF6EF` — faint warm paper; form rows, cards.
- `--surface-elevated #FEFCF8` — the SHEET itself (this is a modal — sits on elevated paper).
- `--surface-sunken #F1EADF` — recessed strips (section header bands, the quick-create well, zebra).
- `--primary #5A3A24` — espresso; structural tint, key actions, **selected chips**, the Save-as-event default.
- `--primary-pressed #43291A` — pressed espresso / seal rim multiply.
- `--secondary #BE4A28` — rationed clay. **FILL ONLY.** The ONE decisive Save CTA + the wax seal. Nothing else.
- `--accent-text #A53D22` — the only clay allowed as **text/icon/thin rule** (AA-safe). Used for the "switch picker" links and the confirm-chips affordance.
- `--on-accent #FBF5EA` — cream ink on a primary/secondary fill.
- `--text-primary #2E211A` — body + headings (warm near-black).
- `--text-secondary #6E5C4C` — labels, supporting copy, placeholders.
- `--separator #D0BA98` — decorative hairlines ONLY (faint, never a real edge).
- `--border #8C7142` — functional edges (text fields, card outlines, chip borders).
- `--success #466234` — olive (completed/agreed — not used on this screen except the "task" mode hint).
- `--warning #C9A24B` — brass (pending/draft; place INK on it, never cream).
- `--danger #A8331F` — brick (destructive; the Cancel-discard confirmation).
- RULE: selected chips/toggles fill **espresso `--primary`**, NOT clay, so they never compete with the seal.
- RULE: clay-as-text must use `--accent-text`; the fill clay `--secondary` is ~3.6:1 → fill only.

**Typography (3 bundled families; web preview via Google Fonts — never Inter/SF Pro):**
- Display/headings: **Fraunces** (titles ≥17pt only). `titleL` 22 medium (−0.2), `titleM` 18 medium (−0.2), `headline` 17 medium.
- Body/labels: **Public Sans**. `body` 16 reg, `bodyEmphasis` 16 semibold (**button labels**), `callout` 15 reg, `label` 13 medium (+0.3, **field labels / eyebrows / chip text**), `caption` 12 reg.
- Code/receipts: **JetBrains Mono**. `code` 13 reg (+0.2, **dates, times, durations, counts, the parsed-time stamp**), `codeSmall` 11 medium (+0.8, micro-labels).
- RULE: display reads tighter (negative tracking); receipts read wider (positive). Times/durations/dates are always JetBrains Mono.

**Spacing (4pt grid):** `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 (default / card inner) · xl 20 · xxl 24 · xxxl 32 · huge 48`. 16pt side margins.

**Radius (cut-paper, never squircle bubbles):** `chip 4 (rubber-stamp) · small 6 (default — buttons, fields) · medium 8 (icon tiles, banner) · card 10 · large 12 (sheets, overlays)`.

**Depth — "letterpress, not float" (both blur radius 0):**
- `letterpress` = 1pt `--border` + hard shadow(`--text-primary` 6%, y:1) — default card.
- `valueCut` = 1pt `--border` + hard shadow(`--text-primary` 12%, y:2) — the saving-overlay card.
- NO soft drop shadows anywhere. System Liquid Glass (warm-tinted) is for chrome only (the sheet grabber region, the keyboard toolbar).

**Components (by name):**
- `CueCard` — `--surface` fill, radius 10, letterpress depth; optional `--surface-sunken` header strip with a 1pt `--separator` bottom rule.
- `CueButton` — full-width, radius 6, label `bodyEmphasis`, press = 1pt downward letterpress depress (no scale/glow), 160ms ease-out. `.decisive` = clay fill + cream (the ONE hot CTA). `.secondary` = clear + 1pt `--border` + espresso label. `.ghost` = clear + `--accent-text` label.
- `CueChip` — 4pt rubber-stamp rectangle, NEVER a pill, no dot. Unselected = `--surface` + `--text-secondary` + 1pt `--border`. Selected = `--primary` espresso fill + `--on-accent`, no border. Text = `label`.
- `CueAvatar` — circle ringed 1.5pt `--primary` (not used here; group color appears as a small swatch tile instead).
- `WaxSeal` — irregular hand-pressed clay blob (16 vertices, fixed jitter — NOT a clean circle). Unstamped = dashed `--border` "seal-well" (dash 4/4). Stamped = `--secondary` clay fill + `--primary-pressed` 40% rim (multiply) + centered cream SF Symbol. Stamp spring: `.spring(response 0.42, damping 0.62)` — scale 0.4→1, opacity 0→1, rotation −8°→0°.

---

## Frame & platform

- **Single fixed iPhone 393×852pt @3x. NOT responsive — a native iOS sheet, not a web page.**
- iOS status bar (time + battery) and Dynamic Island reserved at top; behind/above the sheet the dimmed Calendar/Today tab is faintly visible.
- **This screen is a `.sheet` presented by the separated "+" action** (not a tab). `presentationDetents([.medium, .large])`, opens at **`.medium`** with the keyboard already up and the title field auto-focused; user drags to `.large` to reach recurrence/group/reminder. Visible **grabber** at top center. Corner radius = system sheet (top corners only).
- Inside the sheet: an inline nav bar — leading **Cancel** (`.ghost`, `--accent-text`), centered Fraunces `titleM` title that swaps **"New event" ⇄ "New task"** with the `requiresCompletion` toggle, no trailing item (Save lives in the thumb zone).
- 34pt home-indicator gutter respected. The **decisive Save** button is pinned to the bottom safe-area inset (`safeAreaInset(edge: .bottom)`), always in the one-handed thumb zone, riding above the keyboard.
- All tap targets ≥44pt. Light mode only.

---

## Layout (top → bottom)

A grouped `Form` on `--surface-elevated`, `scrollContentBackground(.hidden)`, real CUE content throughout. The ONE rationed clay/wax-seal moment is the **Save** button → its press stamps the wax seal in the saving overlay. Everything else stays espresso/structural.

```
╭──────────────────────────────────────────╮  ← sheet top, grabber, .medium detent
│              ▬▬▬  (grabber)               │
│  Cancel              New event            │  ← inline nav: ghost Cancel · Fraunces titleM
├──────────────────────────────────────────┤
│ ┌─ QUICK CREATE (sunken well) ──────────┐ │  ← --surface-sunken, radius 8, 1pt border
│ │ ✎  "Lunch with Mara tomorrow 1pm 45m" │ │     NL field, JetBrains-mono-ish entry
│ │                              [ Parse ] │ │     ghost Parse button (--accent-text)
│ │  ┌ parsed ─────────────────────────┐  │ │
│ │  │ 🗓 Tomorrow  ⌚13:00  ⏱45m  #none │  │ │  ← confirm chips (espresso selected look)
│ │  │           Use ✓     Dismiss ✕    │  │ │     Use applies to fields below; Dismiss clears
│ │  └─────────────────────────────────┘  │ │
│ └───────────────────────────────────────┘ │
│                                            │
│ DETAILS                                    │  ← section header, --surface-sunken band
│  Title   [ Lunch with Mara            ]    │  ← auto-focused; sentences capitalization
│  Notes   [ Catch up re: Q3 roadmap…   ]    │  ← axis:.vertical, 3–6 lines
│                                            │
│ TIME                                       │
│  ◻ All-day                       (off)     │  ← Toggle (espresso tint when on)
│  [5m][10m][15m][30m][45m]●[1h][1.5h][2h]…  │  ← duration CueChips, horizontal scroll
│  Starts        Wed Jun 24, 2026   13:00    │  ← compact DatePicker; mono date/time
│  Switch to start + end pickers             │  ← --accent-text caption link (classic mode)
│                                            │
│  ◻ Requires completion           (off)     │  ← THE event⇄task switch
│      "Turns this event into a task you      │     footer caption, --text-secondary
│       can check off."                       │
│                                            │
│ REPEAT                                      │
│  Repeat               Every week on Wed  ›  │  ← RecurrenceSection → opens editor sheet
│                                            │
│ REMINDER                                    │  ← NEW (NotificationRule, schema-only)
│  Remind me            10 min before      ›  │  ← offsetMinutes picker
│  Channel        [ Push ]  [ Telegram ]      │  ← two CueChips, espresso-selected
│                                            │
│ GROUP                                       │
│  Group        ▢#A53D22  Work             ›  │  ← Picker; leading color swatch = group.color
│                                            │
├──────────────────────────────────────────┤
│  ┌────────────────────────────────────┐   │
│  │           Save event   🔴          │   │  ← CueButton(.decisive) — clay fill, cream
│  └────────────────────────────────────┘   │     THE one clay CTA; press → wax seal
│              (home indicator)              │
╰──────────────────────────────────────────╯
```

**Region notes:**
1. **Quick-create well** — `--surface-sunken` card (radius 8, 1pt `--border`), a pencil glyph + single-line NL `TextField` placeholder `"Try: Standup every weekday 9:30am 15m #Work"`. Trailing **Parse** is a `.ghost` button (`--accent-text`). On parse, a **confirm strip** of `CueChip`s appears (`🗓 Tomorrow · ⌚13:00 · ⏱45m · ↻none · #none`) with **Use ✓ / Dismiss ✕** affordances in `--accent-text`. Confirm-before-commit: chips only fill the fields below when the user taps **Use** — they never silently mutate the form.
2. **Details** — `Title` (Fraunces-free; plain `body` field, sentences autocap) and multi-line `Notes` (`body`, 3–6 lines). Real placeholder: title `"Lunch with Mara"`, notes `"Catch up re: Q3 roadmap"`.
3. **Time** — `All-day` Toggle (espresso when on). When off: horizontal `EventDuration` chip strip (`5m 10m 15m 30m 45m 1h 1.5h 2h 3h`, default **1h** selected espresso) + a compact `Starts` DatePicker (date + time, mono receipt voice). A `--accent-text` caption link **"Switch to start + end pickers"** flips to the classic dual `Start`/`End` DatePicker pair (end constrained to `≥ start`). When All-day on: single date-only picker, chips + end hidden.
4. **Requires completion** — the event⇄task pivot Toggle, with footer `caption`: *"Turns this event into a task you can check off."* Title and Save label both swap to "task" wording when on.
5. **Repeat** — `RecurrenceSection`: a row showing `Repeat` + summary (`"Off"` default, or `"Every week on Wed"`), chevron → opens the full **RecurrenceEditor** sheet (frequency Off/Daily/Weekly/Monthly/Yearly · interval stepper · weekday grid for weekly · End: never / on date / after N).
6. **Reminder** — `Remind me` row → offset picker (`None · At time · 5 min · 10 min · 30 min · 1 hour · 1 day before`) mapping to `NotificationRule.offsetMinutes`; `Channel` = two `CueChip`s **Push** / **Telegram** (`NotificationRule.channel`), espresso-selected, Push default.
7. **Group** — Picker, default `None`; each option shows a small `group.color` swatch tile + `group.name` (e.g. `Work`, `Errands`, `Health`). Source: `GET /task-groups`. Hidden entirely if the user has no groups.
8. **Save** — `CueButton(.decisive)` pinned bottom, label **"Save event"** ⇄ **"Save task"**, disabled until title is non-empty. This is the screen's single clay moment; pressing it presses the wax seal.

---

## Data & states

Every control is bound to a real backend field (`CreateTaskRequest` → `POST /tasks`):

| UI element | Field / endpoint |
|---|---|
| Title | `title` (trimmed; required — drives `canSubmit`) |
| Notes | `notes` (trimmed; sent `nil` when empty) |
| All-day toggle | `isAllDay`; when true `endAt` sent as `nil` |
| Duration chips | local `EventDuration` → computes `endAt = startAt + duration` |
| Starts / Start+End pickers | `startAt`, `endAt` (`endAt ≥ startAt`) |
| Requires completion | `requiresCompletion` (event=false / task=true) |
| Repeat | `recurrence: RecurrenceRuleInput { frequency, interval, byWeekday[], endType, endDate "YYYY-MM-DD", count }` |
| Reminder offset + channel | `NotificationRule.offsetMinutes`, `channel` PUSH/TELEGRAM (**schema-only — no client POST yet; render the UI, persist locally / no-op on submit**) |
| Group | `groupId`; options from `GET /task-groups` → `TaskGroupDTO { id, name, color(hex), icon, sortOrder }`; color swatch = `group.color` |
| Calendar | `calendarId` resolved silently (`ensureDefaultCalendar` — `GET /calendars`, create "Default" if none) — never shown |
| Save | `POST /tasks` → `TaskDTO`; on success upsert locally + dismiss |
| Timezone | `timezone = TimeZone.current.identifier` (silent) |

**States to render:**
- **Default (primary frame):** event mode, title `"Lunch with Mara"`, 1h duration selected, Starts `Wed Jun 24, 2026 13:00`, Repeat `Off`, Reminder `10 min before / Push`, Group `Work` (clay-ish swatch). Save enabled, label "Save event".
- **Task mode variant:** `Requires completion` ON → title `"Renew passport"`, nav title + Save label → "task", duration/time still editable.
- **Empty / invalid:** title blank → Save **disabled** (`opacity 0.5`), no error text; quick-create well shows placeholder only.
- **Parse loading:** small inline spinner in the well replacing **Parse** for ~600ms; confirm chips fade in after.
- **Parse low-confidence:** if the AI can't resolve a token, that chip renders as a `--warning` (brass) draft chip with ink, e.g. `⚠ time?`, prompting manual edit — never auto-commits a guess.
- **Saving:** full-sheet warm scrim (`--text-primary` 8% — NOT black) + a `valueCut` `CueCard` containing the `WaxSeal` stamping down (64pt) over `code`-voice copy `"Saving…"`.
- **Save error:** native `.alert` "Couldn't save" with the `LocalizedError` message + OK; sheet stays open, fields intact. (Transient — not a full-page `ErrorStateView`.)
- **Recurring edge:** Repeat summary wraps to a second line for long rules (`"Every 2 weeks on Mon, Wed · until Jan 1, 2027"`) — truncate with tail, full text in the editor.
- **All-day edge:** chips + end picker collapse with `.default` animation; only a date picker remains.
- **Long title:** title field scrolls horizontally; on the saved card later it truncates — here it never clips.
- **Overflow groups:** many groups → Picker uses the system wheel/menu; no "+N more" needed in a Picker.
- **Offline:** `POST /tasks` fails → the same "Couldn't save" alert; quick-create Parse (AI) shows a brass banner `"Assistant offline — fill the fields manually."` and the manual form remains fully usable.

---

## Interactions & motion

- **Open:** "+" presents the sheet at `.medium`, keyboard up, title focused. Drag the grabber (or scroll) to `.large`. Detent snap → `.sensoryFeedback(.impact, weak)`.
- **Event⇄task pivot:** toggling `Requires completion` cross-fades the nav title and Save label (`.snappy`); no layout jump.
- **All-day toggle:** `withAnimation(.default)` — chips + end-picker height collapse/expand.
- **Duration chip select:** `CueChip` fill/ink swap, `.easeOut(0.16)`; recomputes `endAt` instantly; `.sensoryFeedback(.selection)`.
- **Picker-mode link:** "Switch to start + end pickers" flips with `withAnimation` between chip+single and dual-DatePicker layouts.
- **Quick-create parse:** tap **Parse** → 600ms inline spinner → confirm chips fade/scale in (`.snappy`). **Use** writes parsed values into the fields with a brief espresso highlight pulse on each changed row; **Dismiss** clears the strip. Confirm-before-commit is mandatory.
- **Repeat / Reminder rows:** chevron rows push a child sheet (`RecurrenceEditor`) or reveal an inline picker; standard sheet slide.
- **Save → wax seal (the signature moment):** press the `.decisive` button (1pt letterpress depress, clay → `--primary-pressed` multiply @0.22 "ink soaking in", 160ms). On submit, the saving overlay's `WaxSeal` stamps: `.spring(response 0.42, damping 0.62)` — scale 0.4→1, opacity 0→1, rotation −8°→0° (~450ms felt). On success → `.sensoryFeedback(.success)`, overlay fades, sheet dismisses.
- **Cancel with edits:** confirmation dialog (`--danger` "Discard" / cancel) only if the form is dirty.

**Reduce Motion fallbacks:**
- Wax-seal spring → a **150ms opacity + scale-from-0.9 cross-fade** stamp (no rotation, no overshoot). Seal still appears; it just doesn't bounce.
- Confirm-chip fade-in → instant appear.
- All-day collapse / pivot cross-fade → instant state swap, no height animation.
- Detent drag remains (system), parallax dimming behind the sheet drops to a static scrim.

---

## iOS specifics

- **Dynamic Type:** all text uses relative styles (`.cueText` roles map to `Font.TextStyle`). At AX sizes: duration chip strip stays horizontally scrollable; Repeat/Reminder/Group rows wrap label-over-value instead of side-by-side; nothing clips. Title/Notes fields grow.
- **Haptics (`.sensoryFeedback`):** `.selection` on chip + channel selection and Use/Dismiss; `.impact` on detent snap; `.success` on save commit; `.warning` on parse low-confidence.
- **Keyboard toolbar:** above the keyboard, a warm Liquid-Glass bar with **Done** + quick chips **Today · Tomorrow · Next Mon** that set `startAt`; dismisses to reveal the pinned Save.
- **Context menus / swipe:** none on this create sheet (creation, not a list).
- **VoiceOver labels:**
  - Quick-create field: *"Quick create, text field. Describe your event in plain language."*; Parse button: *"Parse with assistant."*; confirm chip: *"Parsed: tomorrow, 1 PM, 45 minutes. Double-tap Use to apply."*
  - Requires-completion toggle: *"Requires completion, switch, off. Turns this event into a task you can check off."*
  - Repeat row: *"Repeat, Off. Double-tap to edit recurrence."* / *"Repeat, every week on Wednesday."*
  - Reminder: *"Remind me, 10 minutes before."*; channel chips announce selected state.
  - Group: *"Group, Work."* (color is decorative — never the only signal; the name carries meaning).
  - Save: *"Save event, button"* / *"Save task, button"*; disabled state announced when title empty.
  - The wax seal is `accessibilityHidden(true)`; the saving overlay announces *"Saving"* via the live region.

---

## ✦ Claude Design prompt (paste this)

> Generate a single fixed iPhone screen (393×852pt @3x, NOT responsive — a native iOS bottom sheet, not a web page). Use the published **"Kraft & Ink"** design system and its tokens ONLY.
>
> **Screen:** "Create event / task" — one modal sheet that creates either an event or a task, with live natural-language quick-create and a wax-seal Save.
>
> **Frame & chrome:** Render it as a `.medium`-detent bottom sheet on `--surface-elevated` (#FEFCF8 warm paper), top corners rounded, a centered grabber, with the dimmed Calendar tab faintly behind it. iOS status bar + Dynamic Island reserved. Inline nav inside the sheet: leading **Cancel** (ghost, clay-text `--accent-text`), centered Fraunces 18pt title **"New event"**. 16pt side margins, 34pt home-indicator gutter, all tap targets ≥44pt.
>
> **Layout, top → bottom:**
> 1. **Quick-create well** — a recessed `--surface-sunken` card (radius 8, 1pt `--border`): a pencil icon + single-line field placeholder *"Try: Standup every weekday 9:30am 15m #Work"*, trailing ghost **Parse** in `--accent-text`. Below it, a confirm strip of espresso-selected rubber-stamp chips: `🗓 Tomorrow` · `⌚ 13:00` · `⏱ 45m` · `# none`, with **Use ✓** / **Dismiss ✕** in clay-text. (Confirm-before-commit.)
> 2. **DETAILS** section — Title field showing *"Lunch with Mara"*; multi-line Notes showing *"Catch up re: Q3 roadmap"*.
> 3. **TIME** section — an **All-day** toggle (off); a horizontal rubber-stamp chip strip `5m 10m 15m 30m 45m [1h] 1.5h 2h 3h` with **1h** selected (espresso fill, cream text); a compact **Starts** date+time row `Wed Jun 24, 2026  13:00` in JetBrains Mono; a clay-text caption link *"Switch to start + end pickers"*.
> 4. A **Requires completion** toggle (off) with footer caption *"Turns this event into a task you can check off."* — this is the event⇄task switch.
> 5. **REPEAT** row — `Repeat   Off ›`.
> 6. **REMINDER** section — `Remind me   10 min before ›`; a `Channel` row with two chips **Push** (selected, espresso) / **Telegram**.
> 7. **GROUP** row — `Group`, value *"Work"* with a small color swatch tile (clay-text `#A53D22`) and chevron.
> 8. **Save** — a full-width `CueButton(.decisive)` pinned to the bottom safe area, **clay `--secondary` fill, cream `--on-accent` label "Save event"**, with a small wax-seal glyph. This is the screen's ONE clay moment.
>
> **Typography:** Fraunces only for the 18pt title (and any heading ≥17pt). Public Sans for all body/labels/placeholders. JetBrains Mono for every date, time, duration, and count. Field labels and chip text use the 13pt +0.3-tracking label style. Never Inter or SF Pro.
> **Color discipline:** espresso `--primary` is structure and selection (selected chips/toggles fill espresso, cream text). Clay `--secondary` appears EXACTLY ONCE — the Save button fill (+ its wax seal). Clay-as-text uses `--accent-text` only (the Parse link, the swatch, the picker links). No other accent. Group color is a tiny decorative swatch, not a meaning channel on its own.
> **Depth:** letterpress only — 1pt `--border` + a hard value-cut offset (blur radius 0). NO soft drop shadows. Cut-paper corners (4–12pt), never squircle bubbles. The keyboard toolbar and grabber region may be warm-tinted Liquid Glass; content cards must NOT be glass.
> **States to also show (small variants beside the main frame):** (a) **Saving** — warm-ink scrim (8% espresso, not black) over a value-cut card with the irregular hand-pressed **wax seal stamped** (clay blob, cream checkmark) and mono *"Saving…"*; (b) **Task mode** — Requires-completion ON, title *"Renew passport"*, button reads **"Save task"**; (c) **Disabled Save** — empty title, button at 50% opacity.
>
> **Anti-AI-slop guardrails (hard):** Honor Kraft & Ink EXACTLY — no invented palette, no Inter/SF Pro/Helvetica, NO purple, NO blue, NO gradients, NO glassmorphism on content cards, NO neon, NO bento grid, NO generic evenly-spaced card matrix, no pure #FFFFFF-on-white or pure #000000, no soft blurred drop shadows. Use native iOS patterns: a real `.medium`/`.large` sheet with a grabber, grouped-inset `Form` rows, compact `DatePicker`, espresso-selected chips, a bottom-thumb-zone CTA, a keyboard toolbar. Exactly ONE wax-seal / clay moment per screen — the Save commit. Real CUE content only (Lunch with Mara, Renew passport, Work group, Q3 roadmap) — never lorem, never "Item 1". Don't say "modern/clean/sleek/beautiful" — render a typesetter's notebook, not a SaaS dashboard.
