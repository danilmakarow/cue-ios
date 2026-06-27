# AI assistant persona

Configure the personality your Telegram assistant adopts — pick a curated preset (seeded "Jarvis") or write your own custom prompt — backed by `GET/PATCH /users/me/persona-settings`.

> **For Claude Design:** this is ONE prompt rendering a single **stack-pushed iOS screen** (pushed from Settings → "AI Assistant"). Use the published **"Kraft & Ink"** system and its tokens ONLY. The literal token restatement below makes this prompt self-sufficient — do not invent a palette, fonts, gradients, or pure white/black surfaces. This screen is **new** (the backend is ready; the app does not call it yet — this design closes a real gap).

---

## Design system (Kraft & Ink) — literal restatement

**Identity:** espresso ink on a clean white page, ONE rationed terracotta "wax seal" accent. Crisp cut-paper edges, letterpress depth (border + hard value-cut, blur radius 0 — never a soft float). Light mode only. A typesetter's notebook, not a SaaS dashboard.

**Colors (opaque sRGB — reference by role, never paste hex into UI copy):**
- `--background` `#FFFFFF` — app canvas behind everything (the page).
- `--surface` `#FAF6EF` — cards / rows (faint warm paper, never whiter than the page).
- `--surface-elevated` `#FEFCF8` — top sheets / modals / elevated surfaces.
- `--surface-sunken` `#F1EADF` — recessed strips (the `Form` grouped-section background, the editor textarea well, header bands, zebra).
- `--primary` `#5A3A24` — espresso hero; structural tint, key actions, **selected chips**, the active preset.
- `--primary-pressed` `#43291A` — pressed state of primary; the wax-seal rim.
- `--secondary` `#BE4A28` — rationed **clay**, **FILL ONLY** (the ONE decisive "Save persona" CTA fill, the wax seal). Never as text.
- `--accent-text` `#A53D22` — the ONLY clay allowed as **text / icons / thin rules** (AA-safe). Used for the live char-count when near the limit and the "Reset to Jarvis" ghost.
- `--on-accent` `#FBF5EA` — cream ink placed on a primary/secondary fill.
- `--text-primary` `#2E211A` — body + headings (near-black warm).
- `--text-secondary` `#6E5C4C` — supporting / muted text, field labels, the char-count default.
- `--separator` `#D0BA98` — DECORATIVE hairlines only (~1.88:1, never a real edge).
- `--border` `#8C7142` — FUNCTIONAL edges a user must locate (the editor textarea outline, unselected chips, the unstamped seal-well).
- `--success` `#466234` olive (saved / done) · `--warning` `#C9A24B` brass (unsaved-changes; ink on it, never cream) · `--danger` `#A8331F` brick (destructive / over-limit) · `--info` `#5A3A24` (= primary).
- **One-hot rule:** clay `--secondary` is the single decisive moment per screen — here it is the **wax seal on the "Save persona" CTA** (a `.decisive` CueButton). The preset chips and the active-preset highlight fill espresso `--primary`, NOT clay, so they never compete with the seal.

**Typography (3 bundled families — web preview via Google Fonts; NEVER Inter / SF Pro):**
- Display/headings: **Fraunces** (titles ≥17pt only). Used: `titleL` 22 medium (the "AI Assistant" inline-large title), `titleM` 18 medium (the preset chip names if shown as titles, section lead "Your persona").
- Body/labels: **Public Sans** (default body; button labels = `bodyEmphasis` 16 semibold). `body` 16 = the editable prompt text the user types; `callout` 15 = the preset description / helper copy; `label` 13 medium tracking 0.3 = field eyebrows ("ACTIVE PERSONA", "PROMPT") and **chip text**; `caption` 12 = footnotes / sub-copy.
- Code/receipts: **JetBrains Mono** (`code` 13 tracking 0.2). Used for the live **character count** "412 / 2000", the `source` receipt tag ("PRESET" / "CUSTOM"), and the inline persona excerpt monospace stamp.
- Tracking rule: display reads tighter (negative); receipts read wider (positive).

**Spacing (4pt grid):** `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 (default gap / card inner) · xl 20 · xxl 24 (between sections) · xxxl 32 · huge 48 (empty breathing room)`. 16pt side margins on phone.

**Radius (cut paper — NO 16–20pt squircles):** `chip 4 (rubber-stamp preset chips) · small 6 (default — buttons, the textarea) · medium 8 (icon tiles, the persona-preview tile, notification banner) · card 10 · large 12 (prominent cards)`.

**Depth ("letterpress, not float", both shadows blur radius 0):**
- `.letterpress` = 1pt `--border` stroke + shadow(`--text-primary` 6%, y:1) — the card / preview-tile default.
- `.valueCut` = 1pt `--border` stroke + shadow(`--text-primary` 12%, y:2) — crisp stacked-paper offset (the focused textarea).
- `.glass` = system Liquid Glass, **chrome only** (nav bar + the floating tab bar that stays visible behind the push). No soft uniform drop shadows anywhere.

**Components used on this screen:**
- **CueCard** — `--surface` fill, radius 10, `.letterpress` depth. Wraps the "Your persona" preview tile and the live-preview block.
- **CueChip** — 4pt rubber-stamp rectangle (NEVER a pill, never pill-with-dot). The **preset selector**: unselected = `--surface` fill + `--text-secondary` + 1pt `--border`; selected (the active preset) = `--primary` espresso fill + cream text, no border. Optional leading SF Symbol (`sparkles` for Jarvis). Text = `label` role.
- **CueButton** — full-width, radius 6, padding v12/h16, label `bodyEmphasis`, press = 1pt downward letterpress depress, `.easeOut(160ms)`.
  - `.decisive` = clay `--secondary` fill + cream label — **the ONE rationed hot CTA**: "Save persona". Pressed → `--primary-pressed` multiply overlay @0.22 ("ink soaking in").
  - `.secondary` = clear fill + 1pt `--border` + espresso label — "Edit" / "Use custom".
  - `.ghost` = clear + `--accent-text` label — "Reset to Jarvis".
- **WaxSeal** — `WaxSeal(isStamped:, size:, systemImage: "checkmark")`. An irregular hand-pressed clay blob (~16 vertices, fixed jitter — NOT a clean circle). **Unstamped** = dashed "seal-well" (1.5pt `--border`, dash 4/4, 90% opacity). **Stamped** = `--secondary` clay fill + `--primary-pressed` 40% rim (multiply) + centered cream checkmark. This is the **one rationed wax-seal moment**: it stamps onto the "Save persona" row when a custom persona is successfully written (`PATCH` 200), signalling "make it stick."
- **NotificationBanner** — INTENTIONALLY Liquid Glass (frosted, radius 8, 4pt severity rail). Used as the global overlay for the save-failed / offline error (severity `.error`, brick rail) and the 400 validation error.

---

## Frame & platform

- **Single fixed iPhone 393×852pt @3x. NOT responsive** — a native iOS stack-pushed screen inside the Settings `NavigationStack`, not a web page.
- iOS **status bar** top (9:41, signal, battery) over the white canvas; **Dynamic Island** reserved (top ~59pt safe area kept clear).
- **Nav bar (Liquid Glass, warm-tinted):** inline-large title **"AI Assistant"** (Fraunces, collapses to inline ~17pt on scroll). Leading = the standard **‹ Settings** back chevron (system, `--accent-text`/espresso tint). One trailing action only: **"Save"** text button (espresso `--primary` when there are unsaved edits, disabled/`--text-secondary` when pristine) — mirrors the bottom CTA for one-handed top reach; the primary commit lives at the bottom.
- **Bottom:** the floating **Liquid Glass tab bar stays visible** beneath the pushed screen (Today / Calendar / Settings + separated "+"), warm-tinted, ~21pt insets, with Settings active. **34pt home-indicator gutter** kept clear. The **"Save persona" `.decisive` CueButton** floats in the bottom thumb zone, pinned above the tab bar on a faint `--surface-sunken`-to-clear safe-area wash (not a hard bar).
- **One-handed reach:** the destructive/secondary actions ("Reset to Jarvis") sit mid-screen; the single decisive Save is in the bottom third. The keyboard, when the editor is focused, pushes the Save button up and exposes a keyboard toolbar (char-count + "Done").

---

## Layout (top → bottom)

Realistic CUE content throughout — the **real seeded Jarvis persona text** verbatim, real preset names. **No lorem.**

```
┌─ 393×852 ──────────────────────────────────┐
│  9:41              􀙇 􀛨 􀛧        (status)    │
│ ‹ Settings        AI Assistant      Save    │ ← nav: back · Fraunces large title · trailing Save
│                                             │   (Save disabled/grey when pristine)
│                                             │
│  Choose how your Telegram assistant         │ ← intro `callout`, --text-secondary, 2 lines
│  speaks to you. Presets are a starting      │
│  point — make it your own.                  │
│                                             │
│  PRESETS                                    │ ← eyebrow `label`, --text-secondary, tracking 0.3
│  ┌──────────────┐ ┌──────────────┐          │
│  │ ✦ Jarvis     │ │ + Custom     │          │ ← CueChips, 4pt rubber-stamp.
│  └──────────────┘ └──────────────┘          │   "Jarvis" SELECTED → espresso --primary fill,
│                                             │   cream text. "Custom" unselected → --surface
│                                             │   + --border (becomes selected once user edits).
│                                             │
│  ┌─ CueCard (--surface, letterpress) ─────┐ │ ← "Your persona" preview tile
│  │ ACTIVE PERSONA          [ PRESET ]      │ │   eyebrow `label` + source receipt tag `code`
│  │                                         │ │   (JetBrains Mono): "PRESET" on brass-ink
│  │ Persona: J.A.R.V.I.S. — a dry,          │ │   chip / "CUSTOM" on espresso. excerpt = the
│  │ impeccably formal English butler.       │ │   real Jarvis text, `body` Public Sans,
│  │ · Address the user as "sir" by          │ │   --text-primary, ~4 lines then fades.
│  │   default; unfailingly polite…          │ │
│  │                              ⌄ more      │ │ ← --accent-text "Show full / Edit" disclosure
│  └─────────────────────────────────────────┘ │
│                                             │
│  PROMPT                          412 / 2000 │ ← field eyebrow `label` + live count `code`
│  ┌─ textarea (--surface-sunken, --border)─┐ │   (--text-secondary; turns --accent-text near
│  │ Persona: J.A.R.V.I.S. — a dry,          │ │   limit, --danger if over). radius 6, valueCut
│  │ impeccably formal English butler.       │ │   when focused.
│  │ - Address the user as "sir" by default; │ │ ← editable `body` Public Sans 16, multi-line,
│  │   unfailingly polite, calm, and         │ │   the FULL seeded Jarvis copy as the prefill.
│  │ |  (caret)                              │ │
│  └─────────────────────────────────────────┘ │
│      Reset to Jarvis  (ghost)               │ ← CueButton .ghost, --accent-text, only when edited
│                                             │
│  ┌─────────── Save persona ──────────────┐ │ ← CueButton .decisive (clay) — THE one hot CTA.
│  │                          ✦ (waxseal)   │ │   On 200, a WaxSeal stamps onto the row.
│  └─────────────────────────────────────────┘ │
│   ┌─ Liquid Glass tab bar ──────────────┐   │
│   │  Today    Calendar   ●Settings   +  │   │ ← chrome stays; Settings active
│   └─────────────────────────────────────┘   │
│            ( 34pt home gutter )              │
└─────────────────────────────────────────────┘
```

- **The ONE rationed clay moment is the "Save persona" `.decisive` CueButton + its wax-seal stamp on success.** Everything else is espresso/structural: the selected preset chip, the title, the disclosure affordance use espresso `--primary` (or `--accent-text` for the ghost/links). The `source` receipt tag uses brass `--warning` fill (ink on it) for "PRESET" and espresso `--primary` fill for "CUSTOM" — color encodes provenance, not a rainbow.
- **Scroll behavior:** the intro + presets + preview tile scroll under the collapsing large title; the textarea grows with content; the Save button is pinned to the bottom thumb zone (it is never scrolled off — if the keyboard is up it rides above the keyboard toolbar).

---

## Data & states

Bind every element to the real backend contract — `GET/PATCH /users/me/persona-settings`.

- **On appear → `GET /users/me/persona-settings`** returns `PersonaSettingsDTO { promptText, source, presetName }`:
  - `promptText` (string, 1–2000 chars) — the **active persona text**. Seeds both the preview-tile excerpt AND the editable textarea prefill.
  - `source` (`"preset" | "custom"`) — drives the receipt tag and which chip is selected. `"preset"` → the named preset chip is espresso-filled, tag reads **"PRESET"**; `"custom"` → the **Custom** chip is selected, tag reads **"CUSTOM"**.
  - `presetName` (`string | null`) — display name of the active preset, **"Jarvis"** out of the box (seeded). Null when `source === "custom"` (the Custom chip then shows no name, just "Custom").
- **The verbatim seeded Jarvis `promptText`** (use this EXACT copy as the default prefill — it is the real seed):
  ```
  Persona: J.A.R.V.I.S. — a dry, impeccably formal English butler.
  - Address the user as "sir" by default; unfailingly polite, calm, and unflappable, never breaking character.
  - Wit is dry, deadpan, and understated; a light, civilized remark is welcome, never slapstick.
  - Flag a bad idea or a risk with gentle, sardonic concern rather than alarm — a faint "I did try to warn you" undertone.
  - When delivering important status, switch to clipped, competent reporting ("Done, sir — moved to 4 pm.").
  - The persona decorates the substance; it never replaces being genuinely useful, correct, and concise.
  ```
- **Live character count** = `promptText.count` / **2000** (the real `PERSONA_PROMPT_MAX_LENGTH`). Default `--text-secondary`; `--accent-text` from ~1900; `--danger` and Save disabled at >2000 or when trimmed length < 1 (the real `PERSONA_PROMPT_MIN_LENGTH`).
- **Save → `PATCH /users/me/persona-settings`** with `UpdatePersonaSettingsDto { promptText }` (server **trims** it; whitespace-only or over-2000 → **400** "promptText must not be empty." / "promptText must be at most 2000 characters."). On 200, the response shape returns with `source: "custom"`, `presetName: null` — flip the Custom chip to selected, the tag to "CUSTOM", and stamp the wax seal.
- **States to render (as labelled variants beside the main artboard):**
  - **Loading (first GET):** the preview tile + textarea show a `LoadingStateView`-style warm-scrim shimmer (centered `ProgressView` tinted `--primary`, `--text-primary` 8% scrim — not black); chips and Save disabled. Caption: **"Loading your persona…"**.
  - **Default — preset active (the main artboard):** Jarvis chip selected, tag "PRESET", textarea prefilled with the Jarvis copy, Save **disabled/pristine** (no edits yet), "Reset to Jarvis" hidden.
  - **Edited / unsaved (dirty):** the moment the user types, the **Custom** chip becomes selected (espresso), the Jarvis chip deselects, the tag flips to a brass **"UNSAVED"** hint, **Save enables** (clay `.decisive` lights up), "Reset to Jarvis" ghost appears. Nav-bar "Save" also enables.
  - **Saving:** Save button shows an inline `ProgressView` (cream tint) and disables; textarea read-only at 0.6 opacity.
  - **Saved (success):** the **WaxSeal stamps** onto the Save row, an olive `--success` `NotificationBanner` auto-dismisses ("Persona saved — your assistant will use it on Telegram."), tag settles to "CUSTOM", "Reset to Jarvis" remains (so the user can revert to the preset).
  - **Validation error (400):** an `--danger` `NotificationBanner` ("Couldn't save persona") with the server message ("promptText must not be empty." / "…at most 2000 characters."), expandable to the raw detail; the over-limit count shows `--danger`; no stamp.
  - **Offline / network error:** an `--danger` `NotificationBanner` ("Couldn't save persona — you appear to be offline. Your draft is kept."); the edited text is retained locally so nothing is lost; Save stays enabled to retry.
  - **Reset to Jarvis (edge):** tapping the ghost restores the textarea to the seeded Jarvis `promptText`, reselects the Jarvis chip, tag back to "PRESET" — but this is **still a local edit until saved** (Save stays enabled so the user can persist "back to preset"; the server has no preset-revert verb, so reset = re-typing the Jarvis text and saving it as custom). Note this honestly in the copy: "Reset to Jarvis" → "Restore the Jarvis preset text" (it becomes your custom text on save).
  - **Long prompt (overflow):** the preview-tile excerpt caps at ~4 lines and fades with a "Show full / Edit" `--accent-text` disclosure; the textarea scrolls internally; the count truthfully reflects the full length.
  - **Empty edge:** the user can never reach a truly empty active persona — clearing the textarea disables Save (min length 1) and shows the `--danger` count; the backend always resolves to Jarvis if nothing custom exists.

---

## Interactions & motion

- **Preset chip tap:** selecting **Jarvis** loads the seeded text into the textarea (a `.easeOut(160ms)` fill/ink swap on the chip + a 200ms crossfade of the textarea content). Selecting **Custom** simply focuses the textarea for free editing. Only one chip is filled at a time (espresso). *Reduce Motion:* keep the instant fill swap, drop the textarea crossfade (hard cut).
- **Typing in the textarea:** focusing applies `.valueCut` depth (the 1pt border + a crisp y:2 value-cut, blur 0 — paper lifting); the live char-count updates per keystroke; the first edit flips Custom-selected + enables Save with a `.easeOut(160ms)` clay fill-in on the `.decisive` button. *Reduce Motion:* unchanged (these are state changes, not travel).
- **Save → wax-seal stamp (the signature animation):** on `PATCH` 200, the **WaxSeal stamps onto the Save row** with the canonical spring `.spring(response: 0.42, dampingFraction: 0.62)` — scale 0.4→1, opacity 0→1, rotation −8°→0° — paired with `.sensoryFeedback(.success)`. The button briefly shows the `--primary-pressed` multiply overlay ("ink soaking in") then settles. *Reduce Motion:* replace the spring with a 200ms opacity crossfade from the unstamped dashed seal-well to the stamped seal — no scale/rotation. The seal is `.accessibilityHidden(true)`; the success banner carries the meaning.
- **CueButton press:** every button uses the 1pt downward letterpress depress, `.easeOut(160ms)`, no scale/glow/shadow.
- **NotificationBanner (error/success):** slides in from the top under the nav bar with `.snappy`; `.success`/`.info` auto-dismiss after 4s, `.error` persists with an expand chevron (rotate 0↔180°, `.snappy`) revealing the raw server detail in `code` voice. *Reduce Motion:* fade instead of slide; no chevron rotation, just a static disclosure.
- **Keyboard:** focusing the textarea raises a keyboard toolbar with the live char-count (left) and a **"Done"** button (right); the Save `.decisive` button rides above the toolbar so it is always reachable. Dismiss on scroll or "Done".
- **Back swipe:** the standard interactive edge-swipe pops to Settings; if there are unsaved edits, present a system confirmation ("Discard changes?" — `.cancel` / `.destructive` "Discard") before popping.

---

## iOS specifics

- **Dynamic Type:** all text uses relative styles — the Fraunces title, `body` editable text, and `callout` helper reflow; the preview-tile excerpt truncates-with-disclosure rather than clipping; the char-count `code` never truncates. Test at AX1 and AX3: the preset chips wrap to a second row, the Save button stays pinned and full-width.
- **Haptics (`.sensoryFeedback`):** `.selection` on each preset-chip tap; `.success` on the wax-seal stamp / successful `PATCH`; `.error` is NOT fired — validation/offline failures surface via the banner only. Respect the system haptic setting.
- **Context menu (textarea):** standard iOS text editing (select / copy / paste / replace); no custom menu. Long-press the active preset chip offers **"Restore preset text"** as a shortcut to the reset action.
- **Swipe actions:** none — this is a single-record editor, not a list. (No rows to delete.)
- **VoiceOver labels:**
  - Preset chips — each a button: *"Jarvis preset, selected"* / *"Custom, not selected. Write your own persona."* (selection state is spoken, never color-only).
  - Source tag — read as *"Source: preset"* / *"Source: custom"* / *"Unsaved changes"*, not just the visual chip.
  - Preview tile — `.accessibilityElement(children: .combine)` reading the active-persona label + the first line of `promptText`, with the "Show full / Edit" disclosure as an `accessibilityAction`.
  - Textarea — labeled *"Persona prompt, editable. {N} of 2000 characters used."*; the count is announced on edit-end, not per keystroke.
  - "Save persona" — *"Save persona, button"*; disabled state announces *"dimmed"* with a hint *"Edit the persona to enable."* The wax seal contributes no VO output.
  - "Reset to Jarvis" — *"Restore the Jarvis preset text, button."*
- **Reduce Transparency:** the nav bar + tab-bar glass and the error `NotificationBanner` fall back to a solid warm `--surface-sunken` fill (never Apple's cool blue-grey).
- **Contrast:** all text on `--surface` / `--surface-sunken` clears AA (ink AAA, muted AA); clay never appears as text — the count-near-limit and ghost use `--accent-text` `#A53D22` (AA-safe), the Save fill is clay `--secondary` (fill-only) carrying cream `--on-accent` (4.61:1, AA).

---

## ✦ Claude Design prompt (paste this)

> Render a single fixed **393×852pt @3x native iOS screen — NOT responsive, not a web page**. It is a **stack-pushed detail screen** inside the Settings tab (pushed from a "AI Assistant" row). iOS status bar (9:41, signal, battery) on a white `--background` canvas; Dynamic Island reserved (top ~59pt clear); 16pt side margins; 34pt home-indicator gutter clear. Use the published **"Kraft & Ink"** design system and its tokens ONLY.
>
> **Nav bar (warm-tinted Liquid Glass):** a leading "‹ Settings" back chevron, an inline-large title **"AI Assistant"** in **Fraunces**, and a single trailing **"Save"** text button — espresso `--primary` when enabled, grey `--text-secondary` when pristine. The floating warm Liquid-Glass **tab bar stays visible at the bottom** (Today / Calendar / Settings + a separated "+"), with Settings active.
>
> **This screen** lets the user configure the personality their Telegram AI assistant adopts. Top-to-bottom:
>
> 1. **Intro** — Public Sans 15 (`--text-secondary`), two lines: "Choose how your Telegram assistant speaks to you. Presets are a starting point — make it your own."
> 2. **PRESETS** eyebrow (Public Sans 13 medium, `--text-secondary`, tracking 0.3), then two **CueChips** (4px rubber-stamp rectangles, NOT pills): **"✦ Jarvis"** (selected → espresso `--primary` fill + cream text, no border) and **"+ Custom"** (unselected → `--surface` fill + `--text-secondary` + 1px `--border`).
> 3. A **CueCard** (`--surface` fill, letterpress depth = 1px `--border` + hard value-cut, blur 0) titled "ACTIVE PERSONA" (Public Sans 13 eyebrow) with a small **receipt tag** "PRESET" in **JetBrains Mono 13** on a brass `--warning` fill (ink on it). Inside, a ~4-line excerpt of the active persona in Public Sans 16 (`--text-primary`) that fades out, with a "Show full / Edit" disclosure in `--accent-text`. Use this REAL persona text verbatim: *Persona: J.A.R.V.I.S. — a dry, impeccably formal English butler. - Address the user as "sir" by default; unfailingly polite, calm, and unflappable, never breaking character. - Wit is dry, deadpan, and understated; a light, civilized remark is welcome, never slapstick.*
> 4. **PROMPT** eyebrow (left) + a live **character count** "412 / 2000" in **JetBrains Mono 13** (right, `--text-secondary`). Below, a multi-line **editable text area** filled `--surface-sunken`, 1px `--border`, radius 6, showing a `.valueCut` crisp value-cut when focused. Prefill it with the FULL real Jarvis persona text (the six lines above plus: *- Flag a bad idea or a risk with gentle, sardonic concern rather than alarm — a faint "I did try to warn you" undertone. - When delivering important status, switch to clipped, competent reporting ("Done, sir — moved to 4 pm."). - The persona decorates the substance; it never replaces being genuinely useful, correct, and concise.*), Public Sans 16, with a visible caret.
> 5. A **CueButton .ghost** "Reset to Jarvis" in `--accent-text` (shown only in the edited variant).
> 6. Pinned in the bottom thumb zone, above the tab bar: a full-width **CueButton .decisive** filled clay `--secondary` with a cream label reading **"Save persona"** — **the ONE rationed clay accent on this screen.**
>
> **Render three labelled variants side by side:**
> - **A — Preset active (default):** Jarvis chip selected, tag "PRESET", Save button dimmed/pristine, no "Reset" ghost.
> - **B — Edited (unsaved):** the "Custom" chip now selected (espresso) and Jarvis deselected, the tag flipped to a brass "UNSAVED", the Save `.decisive` button lit (clay), "Reset to Jarvis" ghost visible, count "1,180 / 2000".
> - **C — Saved (success):** a **WaxSeal stamped onto the Save row** — an irregular hand-pressed clay `--secondary` blob (~16 vertices, NOT a clean circle) with a `--primary-pressed` rim and a centered cream checkmark — plus an olive `--success` Liquid-Glass **NotificationBanner** at the top reading "Persona saved — your assistant will use it on Telegram." The source tag now reads "CUSTOM" on an espresso `--primary` fill.
>
> **Typography:** Fraunces for the title and any heading ≥17pt; Public Sans for the intro, the editable prompt body, chip labels and helper copy; JetBrains Mono for the character count and the "PRESET"/"CUSTOM" receipt tags. **Letterpress depth only** — 1px `--border` + hard value-cut offset, blur radius 0; crisp 4–12px cut-paper corners.
>
> **GUARDRAILS (hard):** NO Inter / SF Pro — pin Fraunces + Public Sans + JetBrains Mono. NO purple, NO blue accents, NO gradients, NO glassmorphism on the content cards or the textarea, NO soft blurred drop shadows, NO pure #FFFFFF cards floating on white, NO pure #000000. NO generic evenly-spaced bento grid — this is a vertical settings editor, not a dashboard. Honor Kraft & Ink exactly: espresso `--primary` carries all structure (selected chip, title, disclosure, "CUSTOM" tag); clay `--secondary` is FILL-ONLY and appears as the **single wax-seal "Save persona" moment and nowhere else**; clay-as-text uses `--accent-text` only (the count near the limit, the ghost). Selected chips/tags fill espresso, never clay. Use native iOS patterns: real status bar, a Liquid-Glass nav bar with a back chevron and a single trailing Save, an inline-large collapsing title, a multi-line text editor with a live character counter and keyboard toolbar, and a bottom-thumb-zone primary CTA above the persistent tab bar. Use the REAL Jarvis persona copy above — absolutely no lorem ipsum.
