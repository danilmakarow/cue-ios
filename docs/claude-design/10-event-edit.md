# Edit series

One modal sheet that edits the underlying `Task` **series** — title, notes, all-day, start/end, "requires completion", and recurrence — then commits with a single `PATCH /tasks/:id`. Recurrence is a **tri-state** (`FieldUpdate`: unchanged / clear / set), and the user first chooses the *scope* of the change: **this event** (a per-occurrence override / skip) vs **all events** (the series).

> Mirrors the implemented `TaskEditScreen` (`cue/Features/Calendar/TaskDetail/TaskEditScreen.swift`), the shared `RecurrenceSection` + `RecurrenceEditor` (`cue/Features/Calendar/Recurrence/RecurrenceEditor.swift`), and the `FieldUpdate` tri-state encoder (`cue/Networking/FieldUpdate.swift`). Field names, the recurrence baseline diff, the saving overlay, and the `PATCH /tasks/{seriesId}` call are taken verbatim from code. New for this design: the **scope chooser** ("This event" / "All events") surfaced up front — in code today the edit form always edits the series, while per-occurrence semantics live as **Skip** (`POST /tasks/:id/skip`) on `TaskDetailScreen`; this screen makes that choice explicit.

---

## Design system (Kraft & Ink)

Use the published **"Kraft & Ink"** system and these tokens ONLY. Do not invent colors, fonts, gradients, or pure white/black surfaces.

**Color (opaque sRGB, by role — reference by name, never hex):**
- `--background #FFFFFF` — app canvas / behind the sheet's content.
- `--surface #FAF6EF` — faint warm paper; form rows, cards.
- `--surface-elevated #FEFCF8` — the SHEET itself (this is a modal — sits on elevated paper).
- `--surface-sunken #F1EADF` — recessed strips (section header bands, the scope-chooser well, zebra).
- `--primary #5A3A24` — espresso; structural tint, key actions, **selected chips/segments**, the Save-changes default.
- `--primary-pressed #43291A` — pressed espresso / seal rim multiply.
- `--secondary #BE4A28` — rationed clay. **FILL ONLY.** The ONE decisive **Save changes** CTA + its wax seal. Nothing else.
- `--accent-text #A53D22` — the only clay allowed as **text/icon/thin rule** (AA-safe). The recurrence "tri-state" hint, the "switch picker" link, the small group swatch.
- `--on-accent #FBF5EA` — cream ink on a primary/secondary fill.
- `--text-primary #2E211A` — body + headings (warm near-black).
- `--text-secondary #6E5C4C` — labels, supporting copy, placeholders.
- `--separator #D0BA98` — decorative hairlines ONLY (faint, never a real edge).
- `--border #8C7142` — functional edges (text fields, card outlines, chip/segment borders).
- `--success #466234` — olive (completed/agreed — not used here).
- `--warning #C9A24B` — brass (pending/draft; place INK on it, never cream) — the "this clears the repeat rule" notice + a failed-to-load guard.
- `--danger #A8331F` — brick (destructive; the Delete-series action + the discard confirmation).
- RULE: selected chips/segments fill **espresso `--primary`**, NOT clay, so they never compete with the seal.
- RULE: clay-as-text must use `--accent-text`; the fill clay `--secondary` is ~3.6:1 → fill only.

**Typography (3 bundled families; web preview via Google Fonts — never Inter/SF Pro):**
- Display/headings: **Fraunces** (titles ≥17pt only). `titleL` 22 medium (−0.2), `titleM` 18 medium (−0.2), `headline` 17 medium.
- Body/labels: **Public Sans**. `body` 16 reg, `bodyEmphasis` 16 semibold (**button labels**), `callout` 15 reg, `label` 13 medium (+0.3, **field labels / eyebrows / chip text / segment labels**), `caption` 12 reg.
- Code/receipts: **JetBrains Mono**. `code` 13 reg (+0.2, **dates, times, durations, counts, the recurrence summary, occurrence date**), `codeSmall` 11 medium (+0.8, micro-labels).
- RULE: display reads tighter (negative tracking); receipts read wider (positive). Times/durations/dates/the recurrence summary are always JetBrains Mono.

**Spacing (4pt grid):** `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 (default / card inner) · xl 20 · xxl 24 · xxxl 32 · huge 48`. 16pt side margins.

**Radius (cut-paper, never squircle bubbles):** `chip 4 (rubber-stamp) · small 6 (default — buttons, fields) · medium 8 (icon tiles, banner, the scope segment) · card 10 · large 12 (sheets, overlays)`.

**Depth — "letterpress, not float" (both blur radius 0):**
- `letterpress` = 1pt `--border` + hard shadow(`--text-primary` 6%, y:1) — default card.
- `valueCut` = 1pt `--border` + hard shadow(`--text-primary` 12%, y:2) — the saving-overlay card.
- NO soft drop shadows anywhere. System Liquid Glass (warm-tinted) is for chrome only (the sheet grabber region, the keyboard toolbar).

**Components (by name):**
- `CueCard` — `--surface` fill, radius 10, letterpress depth; optional `--surface-sunken` header strip with a 1pt `--separator` bottom rule.
- `CueButton` — full-width, radius 6, label `bodyEmphasis`, press = 1pt downward letterpress depress (no scale/glow), 160ms ease-out. `.decisive` = clay fill + cream (the ONE hot CTA). `.secondary` = clear + 1pt `--border` + espresso label. `.destructive` = `--danger` brick fill + cream. `.ghost` = clear + `--accent-text` label.
- `CueChip` — 4pt rubber-stamp rectangle, NEVER a pill, no dot. Unselected = `--surface` + `--text-secondary` + 1pt `--border`. Selected = `--primary` espresso fill + `--on-accent`, no border. Text = `label`. (Used for the weekday grid + reminder channel + the scope segment.)
- `WaxSeal` — irregular hand-pressed clay blob (16 vertices, fixed jitter — NOT a clean circle). Unstamped = dashed `--border` "seal-well" (dash 4/4). Stamped = `--secondary` clay fill + `--primary-pressed` 40% rim (multiply) + centered cream SF Symbol. Stamp spring: `.spring(response 0.42, damping 0.62)` — scale 0.4→1, opacity 0→1, rotation −8°→0°.

---

## Frame & platform

- **Single fixed iPhone 393×852pt @3x. NOT responsive — a native iOS sheet, not a web page.**
- iOS status bar (time + battery) and Dynamic Island reserved at top; behind/above the sheet the dimmed `TaskDetailScreen` (which presented this) is faintly visible.
- **This screen is a `.sheet`** presented from `TaskDetailScreen`'s **Edit** button (which is itself a sheet/push from a day card). `presentationDetents([.medium, .large])`, opens at **`.large`** (the form is tall — title, time, repeat, reminder, scope) with the keyboard up only if the title field is tapped. Visible **grabber** at top center; system sheet corner radius (top corners only).
- Inside the sheet: an inline nav bar — leading **Cancel** (`.ghost`, `--accent-text`), centered Fraunces `titleM` **"Edit task"**, trailing **Save** text button (`bodyEmphasis`, espresso `--primary` tint, `.semibold`) that is **disabled while the series detail is still loading or after a failed load** (so a form that never saw the real recurrence can't silently clear it) and disabled while title is empty. *(This mirrors code: `TaskEditScreen` keeps Save in the nav bar; the bottom-pinned decisive button is this design's addition for the thumb zone — see Layout.)*
- 34pt home-indicator gutter respected. The **decisive Save changes** button is also pinned to the bottom safe-area inset (`safeAreaInset(edge: .bottom)`) — the thumb-zone clay commit — kept in sync with the nav Save.
- All tap targets ≥44pt. Light mode only.

---

## Layout (top → bottom)

A grouped `Form` on `--surface-elevated`, `scrollContentBackground(.hidden)`, populated from the **authoritative `seriesDTO`** (guaranteed loaded by the caller). Real CUE content throughout — this is editing an existing recurring task, **"Team standup"**, group **Work**. The ONE rationed clay / wax-seal moment is the **Save changes** button → its press stamps the wax seal in the saving overlay. Everything else stays espresso / structural.

```
╭──────────────────────────────────────────╮  ← sheet top, grabber, .large detent
│              ▬▬▬  (grabber)               │
│  Cancel       Edit task         Save      │  ← inline nav: ghost Cancel · Fraunces titleM · espresso Save (disabled until loaded + title non-empty)
├──────────────────────────────────────────┤
│ ┌─ APPLY CHANGES TO (sunken well) ──────┐ │  ← --surface-sunken, radius 8, 1pt border
│ │  [ This event ]   [ All events ]●     │ │     2-segment scope chooser, espresso-selected
│ │  ↻ "Editing the whole repeating series.│ │     mono recurrence summary + scope footnote
│ │     Every weekday · until Dec 19, 2026"│ │
│ └───────────────────────────────────────┘ │
│                                            │
│ DETAILS                                    │  ← section header, --surface-sunken band
│  Title   [ Team standup               ]    │  ← prefilled from seriesDTO.title; sentences
│  Notes   [ Async updates in #standup… ]    │  ← axis:.vertical, 3–6 lines; from .notes
│                                            │
│ TIME                                       │
│  ◻ All-day                       (off)     │  ← Toggle (espresso tint when on) ← isAllDay
│  Starts        Mon Jun 22, 2026   09:30    │  ← compact DatePicker; mono ← startAt
│  Ends          Mon Jun 22, 2026   09:45    │  ← end constrained ≥ start; mono ← endAt
│                                            │
│  ◻ Requires completion           (on)      │  ← requiresCompletion; this is a task → ON
│      "Lets you check off each occurrence." │     footer caption, --text-secondary
│                                            │
│ REPEAT                                      │
│  Repeat        Every weekday            ›   │  ← RecurrenceSection summary ← seriesDTO.recurrence
│  ↻ tri-state: edited rule ≠ baseline →      │  ← --accent-text caption ONLY when changed
│     "Repeat rule will be updated."          │     (clearing it → brass "rule will be removed")
│                                            │
│ REMINDER                                    │  ← NotificationRule (schema-only)
│  Remind me            5 min before       ›  │  ← offsetMinutes picker
│  Channel        [ Push ]  [ Telegram ]●     │  ← two CueChips, espresso-selected (Telegram)
│                                            │
│ GROUP                                       │
│  Group        ▢#A53D22  Work             ›  │  ← read-only here (groupId carried through); swatch = group.color
│                                            │
│ ┌────────────────────────────────────────┐ │
│ │  Delete series                          │ │  ← CueButton(.destructive) brick — confirm dialog
│ └────────────────────────────────────────┘ │     (deletes ALL occurrences; lives in detail too)
│                                            │
├──────────────────────────────────────────┤
│  ┌────────────────────────────────────┐   │
│  │         Save changes   🔴          │   │  ← CueButton(.decisive) — clay fill, cream
│  └────────────────────────────────────┘   │     THE one clay CTA; press → wax seal
│              (home indicator)              │
╰──────────────────────────────────────────╯
```

**Region notes:**
1. **Apply-changes-to (scope chooser)** — a `--surface-sunken` card (radius 8, 1pt `--border`) at the very top because it changes the *meaning* of every edit below. A 2-segment espresso-selected control: **This event** / **All events** (default **All events** — the code path today). Below it, a `code`-voice line that swaps:
   - **All events** → `"Editing the whole repeating series."` + the current recurrence summary (`Every weekday · until Dec 19, 2026`).
   - **This event** → `"Changing only Mon Jun 22 — the rest of the series is untouched."` In this mode, **Repeat is hidden** (you can't change the rule for one instance), and a save writes a per-occurrence override / Skip (`POST /tasks/:id/skip {occurrenceStart}` for removal, override fields `overrideStartAt/EndAt/overrideTitle` for an edit). If the task is **not recurring** (`isRecurring == false`), the whole chooser is **hidden** — there's only one event.
2. **Details** — `Title` (plain `body` field, sentences autocap), prefilled `"Team standup"`; multi-line `Notes` (`body`, 3–6 lines), prefilled `"Async updates in #standup"`. Both from `seriesDTO`.
3. **Time** — `All-day` Toggle (espresso when on, prefilled `isAllDay`). When off: a compact **Starts** DatePicker (date + time, mono) and an **Ends** DatePicker constrained to `≥ start`, prefilled from `startAt`/`endAt`. When All-day on: a single date-only picker, Ends hidden (and on save `endAt` is sent `nil`).
4. **Requires completion** — Toggle prefilled from `requiresCompletion` (ON for this task), footer `caption`: *"Lets you check off each occurrence."*
5. **Repeat** — `RecurrenceSection`: a row `Repeat` + the human summary from `seriesDTO.recurrence` (`"Every weekday"`), chevron → opens the full **RecurrenceEditor** sheet (frequency Off / Daily / Weekly / Monthly / Yearly · interval stepper · weekday grid for weekly, ISO `0=Mon…6=Sun` · End: never / on date / after N). **Tri-state hint** under the row, shown ONLY when the edited rule differs from the loaded baseline: a `--accent-text` caption *"Repeat rule will be updated."* — or, if the user turned Repeat **Off** on a task that had a rule, a **brass `--warning`** caption *"This will remove the repeat rule from the whole series."* No hint when unchanged (the key is omitted on PATCH). Hidden entirely in **This event** scope.
6. **Reminder** — `Remind me` row → offset picker (`None · At time · 5 min · 10 min · 30 min · 1 hour · 1 day before`, prefilled `5 min before`) → `NotificationRule.offsetMinutes`; `Channel` = two `CueChip`s **Push** / **Telegram** (`NotificationRule.channel`), espresso-selected (Telegram selected here).
7. **Group** — a row showing the carried-through `groupId`: a small `group.color` swatch tile + `group.name` (`Work`). Read-only on this screen (group is reassigned on the create sheet / detail, not mid-edit); chevron present but inert, or drop the chevron and render as a static value row.
8. **Delete series** — a `CueButton(.destructive)` (brick fill, cream) inside the form footer, opening a `.confirmationDialog` (`"Delete this and all future events?"` / brick **Delete** / Cancel) → `DELETE /tasks/:id`. Deletes the **whole series** (in **This event** scope this control instead reads **Skip this event** → `POST /tasks/:id/skip`).
9. **Save changes** — `CueButton(.decisive)` pinned to the bottom safe area, label **"Save changes"**, disabled until the series detail has loaded and title is non-empty. This is the screen's single clay moment; pressing it presses the wax seal. Mirrors the nav-bar Save.

---

## Data & states

Every control binds to a real backend field. Save → `PATCH /tasks/{event.seriesId}` with an `UpdateTaskRequest`; recurrence is a `FieldUpdate` tri-state computed by diffing the edited `RecurrenceRuleInput?` against `initialRecurrence` (derived from `seriesDTO.recurrence`).

| UI element | Field / endpoint |
|---|---|
| Scope segment | local only — selects series PATCH vs per-occurrence override/skip path |
| Title | `title` (prefilled `seriesDTO.title`; trimmed; required — drives `canSubmit`) |
| Notes | `notes` (prefilled `seriesDTO.notes ?? ""`; trimmed; sent `nil` when empty) |
| All-day toggle | `isAllDay` (prefilled); when true `endAt` sent `nil` |
| Starts / Ends pickers | `startAt`, `endAt` (`endAt ≥ startAt`; prefilled from `seriesDTO.startAt/endAt`, falling back to the tapped occurrence's `startAt/endAt`) |
| Requires completion | `requiresCompletion` (prefilled) |
| Repeat | `recurrence: FieldUpdate<RecurrenceRuleInput>` — **`.unchanged`** when edited == baseline (key omitted), **`.clear`** when turned Off on a task that had a rule (explicit JSON `null`), **`.set(rule)`** when a new/changed rule; `RecurrenceRuleInput { frequency, interval, byWeekday[] ISO 0=Mon, byMonthDay, byMonth, endType NEVER/UNTIL_DATE/COUNT, endDate "YYYY-MM-DD", count }` |
| Reminder offset + channel | `NotificationRule.offsetMinutes`, `channel` PUSH/TELEGRAM (**schema-only — no client PATCH yet; render the UI, persist locally / no-op on submit**) |
| Group | `groupId` carried through unchanged; display from `GET /task-groups` → `TaskGroupDTO { name, color(hex), icon }` |
| Save | `PATCH /tasks/{seriesId}` → `TaskDTO`; on success `onSaved(updated)` → invalidate + resync the affected month(s), dismiss |
| Delete | `DELETE /tasks/{seriesId}` (series) **or** `POST /tasks/{seriesId}/skip {occurrenceStart}` (This-event scope) |

**States to render:**
- **Default (primary frame):** All-events scope, editing recurring task **"Team standup"**, notes `"Async updates in #standup"`, not all-day, Starts `Mon Jun 22, 2026 09:30`, Ends `09:45`, Requires-completion ON, Repeat `Every weekday`, Reminder `5 min before / Telegram`, Group `Work` swatch. No tri-state hint (nothing changed yet). Save enabled.
- **Recurrence-changed variant:** user edits the rule to `Every 2 weeks on Mon, Wed · until Jan 1, 2027` → the Repeat row summary updates AND the `--accent-text` caption *"Repeat rule will be updated."* appears. Demonstrates the `.set` tri-state.
- **Recurrence-cleared variant:** user opens the editor and picks **Off** → Repeat summary reads `Off`, and a **brass `--warning`** caption appears: *"This will remove the repeat rule from the whole series."* Demonstrates the `.clear` tri-state (explicit null).
- **This-event scope variant:** segment flips to **This event** → Repeat section **hidden**, footnote *"Changing only Mon Jun 22 — the rest of the series is untouched,"* Delete button relabels to **Skip this event**.
- **Non-recurring variant:** `isRecurring == false` → the entire scope-chooser well is **hidden**; Delete reads **Delete event** (single).
- **Loading (detail not yet resolved):** the form is presented only after `seriesDTO` loads, so the realistic "loading" state is on the *parent* (`TaskDetailScreen` shows a small `ProgressView` in its recurrence row); if shown here, the Save button is disabled with the warm-ink scrim. **Never present this sheet with an unloaded series** — that's the guard the code enforces.
- **Detail-load-failed (guard):** if the caller's series fetch failed, Edit is blocked upstream; if surfaced inline, render a brass `--warning` notice row *"Couldn't load this task's details — try again,"* with a clay-text **Retry**, and keep Save disabled (so a form that read recurrence as "Off" can't clear a real rule).
- **Saving:** full-sheet warm scrim (`--text-primary` 8% — NOT black) + a `valueCut` `CueCard` containing the `WaxSeal` stamping down (64pt) over `code`-voice copy `"Saving…"`.
- **Save error:** native `.alert` *"Couldn't save"* with the `LocalizedError` message + OK; sheet stays open, fields intact. (Transient — not a full-page `ErrorStateView`.)
- **Long title / overflow:** title field scrolls horizontally; the Repeat summary truncates with a tail when long (`"Every 2 weeks on Mon, Wed · until Jan 1, 2027"`) — full text lives in the editor. No "+N more" here (single record, not a list).
- **All-day edge:** toggling All-day collapses the Ends picker with `.default` animation; only a date picker remains; `endAt` → `nil` on save.
- **Offline:** `PATCH /tasks/:id` fails → the same *"Couldn't save"* alert; fields remain, nothing is lost; the AI/Telegram-dependent reminder rows still render (local state).

---

## Interactions & motion

- **Open:** Edit presents the sheet at `.large` over the dimmed detail. The form is prefilled in `onAppear` from `seriesDTO` (`populateFromDTO`) — fields appear already filled, never blank-then-pop.
- **Scope segment:** tapping **This event** / **All events** swaps the espresso-selected segment (`.easeOut(0.16)`), cross-fades the footnote (`.snappy`), and shows/hides the Repeat section + relabels Delete. `.sensoryFeedback(.selection)`.
- **All-day toggle:** `withAnimation(.default)` — the Ends picker height collapses/expands.
- **Requires-completion / reminder channel chips:** `CueChip` fill/ink swap, `.easeOut(0.16)`, `.sensoryFeedback(.selection)`.
- **Repeat row → editor:** chevron pushes the `RecurrenceEditor` child sheet (standard slide). On return, the summary updates and — because the edited rule now differs from the baseline — the **tri-state hint** fades in (`.snappy`): `--accent-text` for a changed rule, brass `--warning` for a cleared one.
- **Save → wax seal (the signature moment):** press the `.decisive` button (1pt letterpress depress, clay → `--primary-pressed` multiply @0.22 "ink soaking in", 160ms). On submit, the saving overlay's `WaxSeal` stamps: `.spring(response 0.42, damping 0.62)` — scale 0.4→1, opacity 0→1, rotation −8°→0° (~450ms felt). On success → `.sensoryFeedback(.success)`, overlay fades, sheet dismisses, parent resyncs.
- **Delete series:** brick `.destructive` button → `.confirmationDialog` (`--danger` **Delete** / Cancel). On confirm, a small inline `ProgressView` over the button, then dismiss. `.sensoryFeedback(.warning)` on the destructive commit.
- **Cancel with edits:** if any field is dirty, a `.confirmationDialog` (`--danger` **Discard changes** / **Keep editing**); clean form dismisses immediately.

**Reduce Motion fallbacks:**
- Wax-seal spring → a **150ms opacity + scale-from-0.9 cross-fade** stamp (no rotation, no overshoot). Seal still appears; it just doesn't bounce. *(Note: code applies the spring unconditionally today — specify this cross-fade explicitly.)*
- Scope footnote cross-fade & tri-state hint fade-in → instant appear.
- All-day collapse → instant state swap, no height animation.
- Sheet dimming behind → static scrim, no parallax.

---

## iOS specifics

- **Dynamic Type:** all text uses relative styles (`.cueText` roles map to `Font.TextStyle`). At AX sizes: the scope segment stacks the two labels if needed; Repeat / Reminder / Group rows wrap label-over-value instead of side-by-side; the recurrence summary wraps to 2 lines; nothing clips. Title/Notes fields grow.
- **Haptics (`.sensoryFeedback`):** `.selection` on the scope segment + channel chips + reminder picker; `.impact` on detent snap; `.success` on save commit; `.warning` on Delete/Skip commit.
- **Keyboard toolbar:** above the keyboard, a warm Liquid-Glass bar with **Done** + quick chips **Today · Tomorrow · Next Mon** that set `startAt`; dismisses to reveal the pinned Save.
- **Context menus / swipe:** none — this is a single-record editor, not a list.
- **VoiceOver labels:**
  - Scope segment: *"Apply changes to. Segmented control. All events selected. Editing the whole repeating series."* / *"This event selected. Changing only Monday, June 22."*
  - Title: *"Title, text field, Team standup."* Notes: *"Notes, text field, Async updates in standup."*
  - Requires-completion toggle: *"Requires completion, switch, on. Lets you check off each occurrence."*
  - Repeat row: *"Repeat, every weekday. Double-tap to edit recurrence."* When changed: *"Repeat rule will be updated."* When cleared: *"Warning. This will remove the repeat rule from the whole series."*
  - Reminder: *"Remind me, 5 minutes before."*; channel chips announce selected state.
  - Group: *"Group, Work."* (color is decorative — the name carries meaning).
  - Delete: *"Delete series, button."* / in This-event scope *"Skip this event, button."*
  - Save: *"Save changes, button"*; disabled state announced ("dimmed") while the series is loading or the title is empty.
  - The wax seal is `accessibilityHidden(true)`; the saving overlay announces *"Saving"* via the live region.

---

## ✦ Claude Design prompt (paste this)

> Generate a single fixed iPhone screen (393×852pt @3x, NOT responsive — a native iOS bottom sheet, not a web page). Use the published **"Kraft & Ink"** design system and its tokens ONLY.
>
> **Screen:** "Edit series" — one modal sheet that edits an existing recurring task and commits a `PATCH /tasks/:id`. The user first picks the *scope* of the change (this event vs all events); recurrence changes are tri-state (unchanged / cleared / set).
>
> **Frame & chrome:** Render it as a `.large`-detent bottom sheet on `--surface-elevated` (#FEFCF8 warm paper), top corners rounded, a centered grabber, with the dimmed task-detail screen faintly behind it. iOS status bar + Dynamic Island reserved. Inline nav inside the sheet: leading **Cancel** (ghost, clay-text `--accent-text`), centered Fraunces 18pt title **"Edit task"**, trailing **Save** text in espresso `--primary` (semibold). 16pt side margins, 34pt home-indicator gutter, all tap targets ≥44pt.
>
> **Layout, top → bottom (this is an EXISTING recurring task — fields are PREFILLED, never blank):**
> 1. **Apply-changes-to well** — a recessed `--surface-sunken` card (radius 8, 1pt `--border`): a 2-segment espresso-selected control **[ This event ] [ All events ]** with **All events** selected, and below it a JetBrains-Mono footnote *"Editing the whole repeating series. Every weekday · until Dec 19, 2026."*
> 2. **DETAILS** section — Title field prefilled *"Team standup"*; multi-line Notes prefilled *"Async updates in #standup"*.
> 3. **TIME** section — an **All-day** toggle (off); a compact **Starts** date+time row `Mon Jun 22, 2026  09:30` and an **Ends** row `Mon Jun 22, 2026  09:45`, both JetBrains Mono.
> 4. A **Requires completion** toggle (ON) with footer caption *"Lets you check off each occurrence."*
> 5. **REPEAT** row — `Repeat   Every weekday ›`, with a clay-text (`--accent-text`) caption beneath it *"Repeat rule will be updated."* (shown because the rule was edited).
> 6. **REMINDER** section — `Remind me   5 min before ›`; a `Channel` row with two chips **Push** / **Telegram** (Telegram selected, espresso fill).
> 7. **GROUP** row — `Group`, value *"Work"* with a small color swatch tile (clay-text `#A53D22`).
> 8. **Delete series** — a full-width `CueButton(.destructive)` in brick `--danger` with cream label, inside the form.
> 9. **Save changes** — a full-width `CueButton(.decisive)` pinned to the bottom safe area, **clay `--secondary` fill, cream `--on-accent` label "Save changes"**, with a small wax-seal glyph. This is the screen's ONE clay moment.
>
> **Typography:** Fraunces only for the 18pt title (and any heading ≥17pt). Public Sans for all body/labels/placeholders. JetBrains Mono for every date, time, count, and the recurrence summary. Field labels, chip text, and segment labels use the 13pt +0.3-tracking label style. Never Inter or SF Pro.
> **Color discipline:** espresso `--primary` is structure and selection (selected segment + selected chips/toggles fill espresso, cream text). Clay `--secondary` appears EXACTLY ONCE — the Save changes button fill (+ its wax seal). Clay-as-text uses `--accent-text` only (the tri-state hint, the group swatch). Brick `--danger` is the Delete button. Brass `--warning` would carry the "rule will be removed" notice (not shown in the default frame). No other accent. Group color is a tiny decorative swatch, not a meaning channel on its own.
> **Depth:** letterpress only — 1pt `--border` + a hard value-cut offset (blur radius 0). NO soft drop shadows. Cut-paper corners (4–12pt), never squircle bubbles. The keyboard toolbar and grabber region may be warm-tinted Liquid Glass; content cards must NOT be glass.
> **States to also show (small variants beside the main frame):** (a) **Recurrence cleared** — Repeat reads `Off` with a brass `--warning` caption *"This will remove the repeat rule from the whole series."*; (b) **This-event scope** — segment switched to **This event**, the REPEAT section hidden, footnote *"Changing only Mon Jun 22 — the rest of the series is untouched,"* and the Delete button relabeled **Skip this event**; (c) **Saving** — warm-ink scrim (8% espresso, not black) over a value-cut card with the irregular hand-pressed **wax seal stamped** (clay blob, cream checkmark) and mono *"Saving…"*.
>
> **Anti-AI-slop guardrails (hard):** Honor Kraft & Ink EXACTLY — no invented palette, no Inter/SF Pro/Helvetica, NO purple, NO blue, NO gradients, NO glassmorphism on content cards, NO neon, NO bento grid, NO generic evenly-spaced card matrix, no pure #FFFFFF-on-white or pure #000000, no soft blurred drop shadows. Use native iOS patterns: a real `.large` sheet with a grabber, grouped-inset `Form` rows, a segmented scope control, compact `DatePicker`s, espresso-selected chips, a bottom-thumb-zone CTA, a keyboard toolbar. Exactly ONE wax-seal / clay moment per screen — the Save commit. Real CUE content only (Team standup, Async updates in #standup, Work group, every weekday) — never lorem, never "Item 1". Don't say "modern/clean/sleek/beautiful" — render a typesetter's notebook, not a SaaS dashboard.
