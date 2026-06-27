# Group create / edit

One modal sheet that creates or renames a task group and sets its identity — a name, a color swatch, an SF-symbol icon, and an optional default recurrence that every task in the group inherits. Create posts `POST /task-groups`; edit patches `PATCH /task-groups/:id`. No wax seal here — this is a quiet configuration screen; the single clay touch is the selected color swatch (the group's own ink), nothing more.

> Mirrors the implemented `GroupEditSheet` (`cue/Features/Groups/GroupEditSheet.swift`), the `RecurrenceSection`/`RecurrenceEditor` (`cue/Features/Calendar/Recurrence/RecurrenceEditor.swift`), and `TaskGroupDTO` (`cue/Networking/APIModels.swift`). The 6 color hex values, the 12 SF-symbol icons, the espresso-ring swatch selection, the espresso-fill icon-tile selection, the "no color" slash chip, the inherit note, and the `FieldUpdate` tri-state save are all verbatim from code. This is a **secondary** screen reached from Settings → Groups.

---

## Design system (Kraft & Ink)

Use the published **"Kraft & Ink"** system and these tokens ONLY. Do not invent colors, fonts, gradients, or pure white/black surfaces.

**Color (opaque sRGB, by role — reference by name, never hex):**
- `--background #FFFFFF` — app canvas / behind the sheet's content.
- `--surface #FAF6EF` — faint warm paper; form rows, icon tiles, swatch row background.
- `--surface-elevated #FEFCF8` — the SHEET itself (this is a modal — sits on elevated paper).
- `--surface-sunken #F1EADF` — recessed strips (section header bands, the "no color" slash chip fill, zebra).
- `--primary #5A3A24` — espresso; structural tint, the **selected** swatch ring + **selected** icon-tile fill, the recurrence summary chevron.
- `--primary-pressed #43291A` — pressed espresso.
- `--secondary #BE4A28` — rationed clay. **FILL ONLY.** Here it only ever appears as ONE of the six color swatches (the group's chosen ink), never as a button fill or accent — there is no decisive CTA on this screen.
- `--accent-text #A53D22` — the only clay allowed as **text/icon/thin rule** (AA-safe). Not used on this screen except as one of the persistable swatch hexes (`#A53D22`-adjacent inks are stored, but the rendered swatch fill uses the raw stored hex).
- `--on-accent #FBF5EA` — cream ink/glyph on a primary/secondary fill (the cream glyph inside a selected icon tile).
- `--text-primary #2E211A` — body + headings (warm near-black); the name field text, icon glyphs.
- `--text-secondary #6E5C4C` — section labels, supporting copy, placeholders, the inherit note, unselected icon glyphs.
- `--separator #D0BA98` — decorative hairlines ONLY (faint, never a real edge).
- `--border #8C7142` — functional edges (the name field, every swatch ring, every unselected icon tile outline).
- `--success #466234` — olive (not used here).
- `--warning #C9A24B` — brass; appears only as one of the six color swatches (the "brass" ink option). Place INK on it, never cream.
- `--danger #A8331F` — brick; appears only as one of the six color swatches (the "brick" ink option), and as the destructive tint if a delete affordance is shown.
- RULE: selection on this screen fills **espresso `--primary`** (the swatch ring + the icon tile), NOT clay — so the user's *chosen* color stays the only colored thing on the page.
- RULE: the six swatches are real persisted hexes (`#5A3A24 #BE4A28 #466234 #A8331F #C9A24B #6E5C4C`); render each at its raw hex. Everything else stays espresso/ink/paper.

**Typography (3 bundled families; web preview via Google Fonts — never Inter/SF Pro):**
- Display/headings: **Fraunces** (titles ≥17pt only). `titleM` 18 medium (−0.2) — the inline sheet title "New group" / "Edit group".
- Body/labels: **Public Sans**. `body` 16 reg (the name field + value text), `bodyEmphasis` 16 semibold (nav buttons Cancel/Save), `callout` 15 reg (recurrence summary), `label` 13 medium (+0.3 — **section headers / eyebrows**), `caption` 12 reg (the inherit note).
- Code/receipts: **JetBrains Mono**. `code` 13 reg (+0.2 — the recurrence summary's count/date receipts, e.g. `· until 2027-01-01`), `codeSmall` 11 medium (+0.8, micro-labels — not heavily used here).
- RULE: Fraunces only for the 18pt sheet title. All field labels, section headers, and the inherit note are Public Sans. Recurrence dates/counts are JetBrains Mono.

**Spacing (4pt grid):** `xxs 2 · xs 4 · sm 8 · md 12 (swatch + icon-grid gutters) · lg 16 (default / row inset) · xl 20 · xxl 24 · xxxl 32 · huge 48`. 16pt side margins.

**Radius (cut-paper, never squircle bubbles):** `chip 4 · small 6 (default — fields) · medium 8 (icon tiles — `Radius.medium`) · card 10 · large 12 (the sheet)`. Color swatches are the one circle on the screen (32pt `Circle`, ringed) — a deliberate exception because color is read as a dot.

**Depth — "letterpress, not float" (both blur radius 0):**
- `letterpress` = 1pt `--border` + hard shadow(`--text-primary` 6%, y:1) — default form-row paper.
- NO soft drop shadows anywhere. Icon tiles and swatches use a 1pt `--border` outline + value-step, never a float. System Liquid Glass (warm-tinted) is for chrome only (the sheet grabber region, the keyboard toolbar over the name field).

**Components (by name):**
- `CueChip` — 4pt rubber-stamp rectangle, NEVER a pill, no dot. Used here only if a "Color" / "Icon" eyebrow needs a chip; the swatch row and icon grid are custom tiles, not chips. Selected fill = `--primary` espresso + `--on-accent`.
- `CueButton` — full-width, radius 6, letterpress press. **Not used as a bottom CTA here** — Save lives in the nav bar (this is a `Form` sheet, like the real `GroupEditSheet`). If a destructive "Delete group" row is shown in edit mode, it is a `.destructive` (`--danger` brick fill, cream) or a plain `--danger`-text row.
- `WaxSeal` — **not used on this screen.** Group config is not a commit ritual; reserve the seal for completing a task and saving an event.
- The **color swatch** = a 32pt `Circle` filled with the raw stored hex (or `--surface-sunken` + a `slash.circle` glyph for the "no color" option), always ringed by a 1pt `--border`; selected adds an outer 2pt `--primary` espresso ring (inset −4).
- The **icon tile** = a 40pt rounded square (radius 8 `medium`), `--surface` fill + 1pt `--border` and `--text-secondary` glyph when unselected; `--primary` espresso fill + no border + `--on-accent` cream glyph when selected.

---

## Frame & platform

- **Single fixed iPhone 393×852pt @3x. NOT responsive — a native iOS sheet, not a web page.**
- iOS status bar (time + battery) and Dynamic Island reserved at top; behind/above the sheet the dimmed **Settings → Groups** list is faintly visible (this sheet is presented from `GroupsScreen`).
- **This screen is a `.sheet` wrapped in a `NavigationStack`** (matches `GroupsScreen`'s `.sheet(isPresented:)` / `.sheet(item:)`). `presentationDetents([.medium, .large])`; opens at **`.medium`** with the **name field auto-focused** and the keyboard up; the user drags to `.large` to reach the icon grid and recurrence. Visible **grabber** at top center. Top corners rounded (system sheet); content background is `--background` with `scrollContentBackground(.hidden)`.
- Inside the sheet: an **inline nav bar** — leading **Cancel** (`bodyEmphasis`), centered Fraunces `titleM` title that reads **"New group"** (create) or **"Edit group"** (edit), trailing **Save** (`bodyEmphasis`, disabled until the name is non-empty). `navigationBarTitleDisplayMode(.inline)`.
- 34pt home-indicator gutter respected. All tap targets ≥44pt (swatches 32pt visual but ≥44pt hit area; icon tiles 40pt visual, padded to ≥44pt). Light mode only.

---

## Layout (top → bottom)

A grouped `Form` on `--surface-elevated`, `scrollContentBackground(.hidden)`, real CUE content throughout. There is **no wax-seal / decisive-CTA moment** — the one spot of color is the *selected* swatch (the group's own ink). Selection chrome (rings, tile fills) is espresso. Save lives in the nav bar, not a bottom button.

```
╭──────────────────────────────────────────╮  ← sheet top, grabber, .medium detent
│              ▬▬▬  (grabber)               │
│  Cancel            Edit group       Save  │  ← inline nav: Cancel · Fraunces titleM · Save
├──────────────────────────────────────────┤
│ DETAILS                                    │  ← section header, label, --text-secondary
│  [ Errands                            ]    │  ← name TextField, words-autocap, focused
│                                            │
│ COLOR                                      │
│  ⊘   ●   ●   ●   ●   ●   ●                  │  ← horizontal swatch row, 32pt circles
│  none esp clay oliv brk brss mut           │     "none" = slash chip; selected = esp ring
│      └ selected swatch wears a 2pt          │
│        espresso ring (here: clay #BE4A28)   │
│                                            │
│ ICON                                       │
│  ┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐                  │  ← 6-col LazyVGrid, 40pt tiles, 12pt gutter
│  │📁││★ ││♥ ││⚡││🔥││📖│                  │     folder star heart bolt flame book
│  └──┘└──┘└──┘└──┘└──┘└──┘                  │
│  ┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐                  │
│  │💼││🛒││🏃││🏋││♫ ││🎓│                  │     briefcase cart figure.run dumbbell …
│  └▓▓┘└──┘└──┘└──┘└──┘└──┘                  │     selected tile (briefcase) = espresso fill
│                                            │
│ REPEAT                                      │
│  Repeat            Every week on Wed  ›     │  ← RecurrenceSection → opens RecurrenceEditor
│                                            │
│ ┌ ℹ︎ This recurrence becomes the default ┐   │  ← inherit note, shown ONLY when repeat ≠ off
│ │   for tasks added to this group; a      │     caption, --text-secondary, info.circle
│ │   task's own rule still wins.           │
│ └──────────────────────────────────────┘   │
╰──────────────────────────────────────────╯
        (home indicator) — no bottom CTA
```

**Region notes:**
1. **Details** — a single `TextField` for `name`, placeholder *"Group name"*, `textInputAutocapitalization(.words)`, auto-focused on open. Real value in the primary frame: **"Errands"** (edit mode). Plain `body` (Public Sans) — *not* Fraunces; group names are data, not display type.
2. **Color** — a horizontally-scrolling row of **7** 32pt `Circle` swatches: a leading **"no color"** chip (`--surface-sunken` fill + a `slash.circle` glyph in `--text-secondary`) then the six persisted inks rendered at their raw hex — `#5A3A24` espresso, `#BE4A28` clay, `#466234` olive, `#A8331F` brick, `#C9A24B` brass, `#6E5C4C` muted. Every swatch is ringed by a 1pt `--border`. The **selected** swatch gains an outer **2pt `--primary` espresso ring** (inset −4) — selection is espresso, not the color itself. Row sits on `--surface`.
3. **Icon** — a 6-column `LazyVGrid` of **12** 40pt rounded-square tiles (radius 8), 12pt gutters, on `--surface`. Symbols, in order: `folder.fill · star.fill · heart.fill · bolt.fill · flame.fill · book.fill · briefcase.fill · cart.fill · figure.run · dumbbell.fill · music.note · graduationcap.fill`. Unselected tile = `--surface` fill + 1pt `--border` + `--text-secondary` glyph. **Selected** tile = `--primary` espresso fill, no border, `--on-accent` cream glyph.
4. **Repeat** — `RecurrenceSection`: a disclosure row `Repeat` + summary (default **"Off"**, or e.g. **"Every week on Wed"** / **"Every 2 weeks on Mon, Wed · until 2027-01-01"**, mono receipt voice on the date/count tail), chevron → pushes the full **RecurrenceEditor** sheet (frequency Off/Daily/Weekly/Monthly/Yearly · interval stepper · weekday grid for weekly · End: never / on date / after N occurrences).
5. **Inherit note** — a `caption` `Label` with an `info.circle` glyph, `--text-secondary`, **rendered only when a recurrence is set** (`recurrenceInput != nil`): *"This recurrence becomes the default for tasks added to this group; a task's own rule still wins."* When Repeat is Off this whole section is absent.
6. **No bottom button.** Save and Cancel are the two nav-bar items; there is no full-width CTA and no wax seal. (This matches the real `GroupEditSheet`, which puts Save in `.topBarTrailing`.)

---

## Data & states

Every control is bound to a real backend field. Create → `CreateTaskGroupRequest` → `POST /task-groups`; edit → `UpdateTaskGroupRequest` → `PATCH /task-groups/:id`.

| UI element | Field / endpoint |
|---|---|
| Name | `name` (trimmed of whitespace; **required** — empty disables Save) |
| Color swatch | `color` — a hex string (`"#BE4A28"`) or `nil` for "no color"; rendered via `Color(hex:)`. What's stored is exactly what ships to the API. |
| Icon tile | `icon` — an SF-symbol name (`"cart.fill"`) or `nil`; one of the 12 presets |
| Repeat / inherit | `recurrence: RecurrenceRuleInput { frequency, interval, byWeekday[], byMonthDay, byMonth, endType NEVER/UNTIL_DATE/COUNT, endDate "YYYY-MM-DD", count }`; persisted as the group's `defaultRecurrenceRuleId` |
| Save (create) | `POST /task-groups` body `{ calendarId, name, color, icon, sortOrder:null, recurrence }`. `calendarId` is resolved silently (`GET /calendars`, create "Default" if none) — never shown. |
| Save (edit) | `PATCH /task-groups/:id` body `{ name, color, icon, sortOrder:null, recurrence: FieldUpdate }` — the recurrence is a **tri-state**: `.unchanged` if it matches the baseline, `.clear` (explicit null) if the user turned it off, `.set(rule)` if new/changed. |
| Result | `TaskGroupDTO { id, calendarId, name, color, icon, sortOrder, defaultRecurrenceRuleId, recurrence, createdAt, updatedAt }` → upserted into the local `EventTaskGroup` `@Model` and the list refreshes. |

**States to render:**
- **Default — Edit mode (primary frame):** title **"Edit group"**, name **"Errands"**, **clay `#BE4A28`** swatch selected (espresso ring), **`cart.fill`** icon tile selected (espresso fill), Repeat **"Off"**, no inherit note, Save enabled.
- **Create mode variant:** title **"New group"**, name field empty with placeholder *"Group name"*, **no color** swatch selected (the slash chip carries the espresso ring), no icon selected, Repeat Off, **Save disabled** (`opacity 0.5`).
- **Recurrence set variant:** Repeat row reads **"Every week on Wed"**, the **inherit note appears** beneath it. A long rule (`"Every 2 weeks on Mon, Wed · until 2027-01-01"`) truncates with a tail in the row; full text lives in the editor.
- **Empty / invalid:** blank name → Save disabled, no error text shown (validation is the disabled button, not a red message).
- **Saving:** a full-sheet warm-ink scrim (`--text-primary` **8% — NOT black**) over a centered `ProgressView` tinted `--primary` (matches the real `.overlay { if isSubmitting … }`). No wax seal — this is a quiet save.
- **Save error:** native `.alert` titled "Couldn't save" with the `LocalizedError` message + **OK**; the sheet stays open, all selections intact. (Transient — not a full-page `ErrorStateView`.)
- **Long name:** the name field scrolls horizontally; on the Groups list row it later truncates, but here it never clips.
- **Overflow icons:** only 12 fixed presets — the 6×2 grid fits with no "+N more"; no scrolling needed at default type sizes.
- **All-day / recurring edge:** a group recurrence has no time-of-day (it's a default rule, not an event) — the editor exposes frequency/interval/weekday/end only; there is no all-day concept here.
- **Offline:** `POST`/`PATCH` fails → the same "Couldn't save" alert; the form remains fully usable and re-submittable. `GET /calendars` (for create's silent `calendarId`) failing surfaces the same alert.

---

## Interactions & motion

- **Open:** the sheet presents at `.medium`, keyboard up, name field focused (`@FocusState`). Drag the grabber (or scroll) to `.large` to reach the icon grid + recurrence. Detent snap → `.sensoryFeedback(.impact, weak)`.
- **Color swatch tap:** taps the `Button`-wrapped swatch → `colorHex` updates; the outer **2pt espresso ring** moves to the tapped swatch with `.easeOut(0.16)` (a quick ring slide, no scale). `.sensoryFeedback(.selection)`. Tapping the already-selected swatch keeps it; tapping the **slash chip** clears the color (`colorHex = nil`).
- **Icon tile tap:** the tapped tile fills espresso + glyph flips to cream (`.easeOut(0.16)` fill/ink swap, matching `CueChip`); the previously selected tile reverts to paper. `.sensoryFeedback(.selection)`.
- **Repeat row:** chevron → pushes the **RecurrenceEditor** via standard navigation slide. On return, the summary line updates and — if a rule was set — the **inherit note fades/slides in** (`withAnimation(.default)`); turning Repeat back to Off slides it out.
- **Save:** tap the nav-bar **Save** → the warm-ink scrim + spinner overlay appears (`isSubmitting`), the request fires, and on success `onSaved(dto)` upserts locally and the sheet dismisses with the standard sheet slide-down. `.sensoryFeedback(.success)` on dismiss. **No wax-seal stamp** — deliberately calmer than the event-save ritual.
- **Cancel:** dismisses immediately (the real sheet's Cancel does not gate on dirty state); standard slide-down.

**Reduce Motion fallbacks:**
- Selected-swatch ring slide → **instant** ring placement (no slide), still espresso, still 2pt.
- Icon-tile fill swap → instant fill/ink change, no 160ms ease.
- Inherit-note reveal → instant appear/disappear, no height animation.
- Sheet detent drag remains (system); the dim behind the sheet becomes a static scrim instead of a parallax dim.

---

## iOS specifics

- **Dynamic Type:** all text uses relative styles (`.cueText` roles → `Font.TextStyle`). At AX sizes: the color swatch row stays horizontally scrollable; the icon grid keeps 6 columns but tiles grow and the grid scrolls within `.large`; the Repeat row wraps label-over-summary instead of side-by-side; the inherit note wraps freely; nothing clips.
- **Haptics (`.sensoryFeedback`):** `.selection` on every swatch and icon-tile tap; `.impact` on detent snap; `.success` on a successful save/dismiss; `.error` (or the alert's default) on save failure.
- **Keyboard toolbar:** a warm Liquid-Glass bar above the keyboard with a **Done** button to dismiss the keyboard and reveal the icon grid / recurrence beneath. (Name is the only text field; pickers handle their own input.)
- **Context menus / swipe actions:** none on this sheet — it is a config form, not a list. (Swipe-to-delete lives on the parent `GroupsScreen` row, not here.)
- **VoiceOver labels:**
  - Name field: *"Group name, text field."*
  - Color swatch: announce the **role name, not just the hex**, and selected state — *"Clay, color, selected"*, *"Olive, color"*, *"No color"*. Color is never the only signal; the name carries the group's meaning, and selected state is spoken.
  - Icon tile: *"Cart icon, selected"* / *"Star icon."* — speaks the symbol's intent, with selected state.
  - Repeat row: *"Repeat, Off. Double-tap to edit recurrence."* / *"Repeat, every week on Wednesday."*
  - Inherit note: read as supporting text after the Repeat row.
  - Nav: *"Cancel, button."* / *"Save, button"* (announces disabled when the name is empty).

---

## ✦ Claude Design prompt (paste this)

> Generate a single fixed iPhone screen (393×852pt @3x, NOT responsive — a native iOS bottom sheet, not a web page). Use the published **"Kraft & Ink"** design system and its tokens ONLY.
>
> **Screen:** "Group create / edit" — one modal sheet that sets a task group's name, color, icon, and an optional default recurrence. Create posts `POST /task-groups`; edit patches `PATCH /task-groups/:id`. This is a quiet config sheet — there is NO wax seal and NO clay CTA.
>
> **Frame & chrome:** Render it as a `.medium`-detent bottom sheet on `--surface-elevated` (#FEFCF8 warm paper), top corners rounded, a centered grabber, with the dimmed Settings → Groups list faintly behind it. iOS status bar + Dynamic Island reserved. Inline nav inside the sheet: leading **Cancel**, centered Fraunces 18pt title **"Edit group"**, trailing **Save** (Save lives in the nav bar, NOT a bottom button). 16pt side margins, 34pt home-indicator gutter, all tap targets ≥44pt.
>
> **Layout, top → bottom (grouped Form on warm paper):**
> 1. **DETAILS** section — a single name field showing *"Errands"* (Public Sans body, words-autocapitalized, focused with the keyboard up).
> 2. **COLOR** section — a horizontal row of seven 32pt circle swatches, each ringed by a 1pt `--border`: a leading **"no color"** chip (`--surface-sunken` fill + a slash glyph), then six persisted inks at their raw hex — espresso `#5A3A24`, clay `#BE4A28`, olive `#466234`, brick `#A8331F`, brass `#C9A24B`, muted `#6E5C4C`. The **selected** swatch (clay `#BE4A28`) wears an extra 2pt `--primary` ESPRESSO ring — selection is espresso, the chosen color is the only saturated thing on the page.
> 3. **ICON** section — a 6-column grid of twelve 40pt rounded-square tiles (radius 8): folder.fill, star.fill, heart.fill, bolt.fill, flame.fill, book.fill, briefcase.fill, cart.fill, figure.run, dumbbell.fill, music.note, graduationcap.fill. Unselected = `--surface` fill + 1pt `--border` + `--text-secondary` glyph. The **selected** tile (cart.fill) = `--primary` espresso fill, no border, cream `--on-accent` glyph.
> 4. **REPEAT** row — `Repeat   Every week on Wed ›` (disclosure to a recurrence editor).
> 5. An **inherit note** beneath Repeat (caption, `--text-secondary`, info.circle glyph): *"This recurrence becomes the default for tasks added to this group; a task's own rule still wins."* — shown ONLY because a recurrence is set.
>
> **Typography:** Fraunces only for the 18pt sheet title. Public Sans for the name field, section headers (13pt +0.3 tracking label style), value text, and the inherit caption. JetBrains Mono for any recurrence date/count receipt (e.g. `· until 2027-01-01`). Never Inter or SF Pro.
> **Color discipline:** espresso `--primary` is structure and selection (the swatch ring + the icon-tile fill, cream glyph). The ONLY saturated color on the page is the user's CHOSEN swatch fill; the other five swatches sit in the row as options. NO clay button, NO wax seal, no decisive CTA, no second accent. Color is a decorative/identity channel announced by name to VoiceOver, never the only signal.
> **Depth:** letterpress only — 1pt `--border` + a hard value-cut offset (blur radius 0). NO soft drop shadows. Cut-paper corners (4–12pt) on tiles and rows; the swatches are deliberate 32pt circles (color reads as a dot). The grabber region and keyboard toolbar may be warm-tinted Liquid Glass; content must NOT be glass.
> **States to also show (small variants beside the main frame):** (a) **Create mode** — title **"New group"**, empty name with placeholder *"Group name"*, the "no color" slash chip carrying the espresso ring, no icon selected, **Save disabled** at 50% opacity; (b) **Saving** — a warm-ink scrim (8% espresso, NOT black) over a centered espresso-tinted spinner (no wax seal); (c) **No recurrence** — Repeat reads "Off" and the inherit note is absent.
>
> **Anti-AI-slop guardrails (hard):** Honor Kraft & Ink EXACTLY — no invented palette, no Inter/SF Pro/Helvetica, NO purple, NO blue, NO gradients, NO glassmorphism on content, NO neon, NO bento grid, NO generic evenly-spaced card matrix, no pure #FFFFFF-on-white or pure #000000, no soft blurred drop shadows. Use native iOS patterns: a real `.medium`/`.large` sheet with a grabber, grouped-inset `Form` rows, a Save/Cancel nav bar (not a bottom CTA), a horizontal swatch row, a `LazyVGrid` icon picker, a disclosure-to-editor recurrence row, a keyboard toolbar. ZERO wax-seal / clay-CTA moments — the only color is the selected swatch. Real CUE content only (Errands group, cart icon, "Every week on Wed") — never lorem, never "Item 1", never "Group 1". Don't say "modern/clean/sleek/beautiful" — render a typesetter's notebook, not a SaaS dashboard.
