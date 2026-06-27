# Task groups

The shelf of labels — every group a colored, icon-stamped paper tab that lends its hue and (optionally) its recurrence to the tasks filed under it. List, create, edit, and ungroup-by-deleting.

> Status in code: **exists** (`cue/Features/Groups/GroupsScreen.swift` + `GroupEditSheet.swift`, model `cue/Models/EventTaskGroup.swift`). This prompt designs the **as-built** screen, faithful to the real layout, field names, and behaviors. The only Kraft & Ink uplift over today's plain `List`: render each row as a **letterpress row on warm paper** (not a system inset cell) and use the **real 36pt icon tile** (`--surface` fill + 1pt `--border`, `medium 8` corner, glyph tinted by the persisted group color). The list is pushed from **Settings**; `+` is a nav-bar trailing toolbar item that opens the Group-edit sheet (`14-group-edit.md`). Swipe-to-delete **ungroups** tasks — it does not delete them. Mirror the real field names and endpoints below.

---

## Design system (Kraft & Ink)

Use the published **"Kraft & Ink"** system and its tokens ONLY — no invented palette, fonts, gradients, or pure white/black surfaces. Reference everything by name.

**Color (opaque sRGB; semantic roles, never raw hex in app):**
- `--background #FFFFFF` — app canvas behind the list.
- `--surface #FAF6EF` — each **group row** + the **icon tile** fill (faint warm paper).
- `--surface-elevated #FEFCF8` — reserved for the Create/Edit **sheet** (lives in `14-group-edit.md`); not on this list.
- `--surface-sunken #F1EADF` — the swipe-revealed delete tray backing / any recessed strip.
- `--primary #5A3A24` (espresso) — structural tint: the `+` glyph, the row chevron weight, the **fallback icon tint** when a group has no color, the nav title ink.
- `--primary-pressed #43291A` — pressed primary.
- `--secondary #BE4A28` (clay) — **FILL ONLY**, rationed. On THIS screen the wax-seal "make it stick" moment is **the floating `+` Create affordance** (the one decisive act — minting a new label). Used at most ONCE. (Note: the persisted clay `#BE4A28` may ALSO appear as a *group's own color* on a tile — that is **data**, not the rationed accent.)
- `--accent-text #A53D22` — the ONLY clay allowed as **text / icons / thin rules** (AA-safe); used for the empty-state's "Tap +" emphasis hint, nowhere else here.
- `--on-accent #FBF5EA` (cream) — ink/glyph on a primary or clay fill (the `+` glyph on the clay seal).
- `--text-primary #2E211A` — group names, headings.
- `--text-secondary #6E5C4C` — the "Recurring" sub-label, the chevron, captions.
- `--separator #D0BA98` — **decorative hairlines ONLY** (~1.88:1) — the faint rule between stacked rows if any.
- `--border #8C7142` — **functional edges** — the 1pt outline on each row card AND the 1pt outline on every icon tile (a tile the user must locate).
- `--success #466234` (olive) — not used here.
- `--warning #C9A24B` (brass) — not used here (no draft state on this list).
- `--danger #A8331F` (brick) — the **trailing swipe Delete** action fill + cream label (and the only place brick appears).
- **Group color** (per `TaskGroup.color`, e.g. `#3E6B57` sage, `#C9A24B` brass, `#A8331F` brick) is **backend-supplied membership data** — it tints the row's **icon glyph**, NOT the tile background. Absent a color it falls back to espresso `--primary`. It is data, not the rationed accent.

**More-accent discipline (hard rule):** terracotta `--secondary` is the one-hot moment — here, the **`+` Create** affordance (its wax seal), once. Every group's own hue is membership data on its glyph; the structure (tiles, rows, chevrons, names) stays espresso/ink. Color presence, not a rainbow — even though groups carry many hues, they live only inside the small tiles, never bleeding into row chrome.

**Typography (3 bundled families — substitute via Google Fonts in web preview):**
- Display/headings: **Fraunces** (≥17pt only — NEVER dense labels). The large nav title **"Groups"** is Fraunces.
- Body/labels: **Public Sans** (explicitly NOT Inter / SF Pro).
- Code/receipts: **JetBrains Mono** (not needed on this list — no dates/IDs surfaced; reserve it should a count badge appear).
- Ramp used here: `displayL` Fraunces 34 semibold (-0.4) = the **"Groups"** large nav title · `titleM` Fraunces 18 medium (-0.2) = each **group name** (the row title) · `caption` Public Sans 12 = the **"Recurring"** sub-label · `body`/`callout` Public Sans = empty-state copy · `label` Public Sans 13 medium (+0.3) = any eyebrow. Display reads tighter (negative tracking).

**Spacing (4pt grid):** `xxs 2` (name → "Recurring" sub-label gap) · `sm 8` · `md 12` (**icon tile → text gap**, intra-row rhythm) · `lg 16` (default gap; row inner padding; side margins) · `xl 20` · `xxl 24` (between sections, around the empty state) · `huge 48` (empty-state breathing). 16pt side margins.

**Radii (crisp cut-paper, never 16–20 squircle bubbles):** `chip 4` · `small 6` · `medium 8` = **the icon tile corner** (the real value in code) · `card 10` = each **group row** treated as a cut-paper card. No squircle bubbles.

**Depth ("letterpress, not float"):** each group row = `.letterpress` (1pt `--border` stroke + hard value-cut shadow `--text-primary` 6%, **blur radius 0**, y:1). The icon tile carries its own 1pt `--border` (no shadow — it's inside the row). NO soft uniform drop shadows anywhere. System **Liquid Glass** is chrome-only — the floating tab bar + the nav bar; re-tint it **warm** toward kraft/clay, never Apple's cool blue-grey.

**Components (by name):**
- **CueCard** — the visual basis for each **group row**: fill `--surface`, radius `card 10`, `.letterpress`. (Rendered as tappable rows, not a system grouped-inset `List` cell.)
- **CueButton** — full-width, radius 6, label `bodyEmphasis`, press = 1pt downward letterpress offset, `.easeOut(0.16)`. Used only in the **empty state** as a `.decisive` "Create your first group" (the single rationed clay CTA there) — or the `+` toolbar item carries the seal when rows exist. Variants available: `.primary` / `.decisive` / `.secondary` / `.destructive` / `.ghost`.
- **CueChip** — not used on the list itself (chips live in the edit sheet's color/icon pickers).
- **WaxSeal** — the signature mark: an irregular hand-pressed clay blob (16 vertices, fixed jitter, NOT a clean circle). On THIS screen the seal is the **`+` Create** affordance's gesture — the `+` glyph sits in a small clay seal-well in the nav bar / floating action, the one "make it stick" act of minting a label. Stamped = `--secondary` clay fill + `--primary-pressed` 40% rim (multiply) + centered cream `+` glyph.
- **CueAvatar** — not used here.
- **ContentUnavailableView** (system, themed) — the empty state ("No Groups").

---

## Frame & platform

Single fixed iPhone **393 × 852 pt @3x**, **NOT responsive** — a native iOS 26 screen, not a web page.

- **Presentation:** a **stack-pushed** screen inside the **Settings** `NavigationStack` (Settings → Groups). Inline back chevron + "Settings" back label at top-leading. **Large title "Groups"** (Fraunces `displayL`) that collapses to an inline title on scroll.
- **Status bar / Dynamic Island:** full status bar (time + battery) at top; Dynamic Island reserved — no content beneath it. Top safe area ~59pt.
- **Nav chrome:** standard iOS nav bar (warm-tinted Liquid Glass). **Trailing toolbar item = `+`** (`plus` SF Symbol) — opens the Group-edit sheet (`GroupEditSheet`, create mode). This `+` is the screen's single rationed clay/seal moment — render its glyph inside a small clay wax-seal well (cream `+`), not a bare system button. ≤1 trailing action; no leading action beyond the system back.
- **Below:** the floating warm Liquid-Glass **3-tab bar** (Today / Calendar / Settings) + separated `+` remains visible at the bottom — but this screen is *inside the Settings tab's stack*, so the Settings tab reads selected. (The list's own `+` is the contextual create; the tab-bar `+` is the global Create-task sheet — they are different actions.)
- **Safe areas:** 16pt side margins; respect the **34pt home-indicator gutter** — the last row never sits under the home indicator or the floating tab bar; bottom content inset accounts for both.
- **One-handed reach:** rows are tap-anywhere targets; the most-used act (Create) is a top-trailing `+` *and* (in the empty state) a thumb-zone `.decisive` button. Destructive delete is hidden behind a deliberate trailing swipe — never a primary, never one-tap-exposed.

---

## Layout

Top → bottom (a `List`/`ScrollView` of letterpress group rows, sorted by `sortOrder`). The icon glyph color = each group's persisted `TaskGroup.color`; the tile + row chrome stay espresso/paper.

Real content: a personal planner's groups — **Work** (sage `#3E6B57`, `briefcase.fill`, recurring weekly), **Errands** (brass `#C9A24B`, `cart.fill`), **Workout** (brick `#A8331F`, `dumbbell.fill`, recurring), **Reading** (espresso, `book.fill`), **Family** (clay `#BE4A28`, `heart.fill`).

```
┌─────────────────────────────────────────────┐
│  ●●●  9:41                          ▂▂ 📶 🔋 │  ← status bar, Dynamic Island reserved
│ ‹ Settings                                ⊕  │  ← back · trailing + (clay wax-seal well, cream +)
│                                              │
│  Groups                                      │  ← large title, Fraunces displayL, espresso
│                                              │
│ ┌──────────────────────────────────────────┐ │  ← group row = CueCard, --surface, letterpress
│ │ ┌────┐  Work                          ›   │ │     tile 36×36 (--surface + 1pt border, r8)
│ │ │ 💼 │  ⟳ Recurring                       │ │     glyph briefcase.fill tinted SAGE #3E6B57
│ │ └────┘                                    │ │     name titleM · "Recurring" caption (repeat)
│ └──────────────────────────────────────────┘ │     chevron.right --text-secondary
│ ┌──────────────────────────────────────────┐ │
│ │ ┌────┐  Errands                       ›   │ │     cart.fill tinted BRASS #C9A24B
│ │ │ 🛒 │                                     │ │     (no recurrence → no sub-label, name centers)
│ │ └────┘                                    │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ ┌────┐  Workout                      ›    │ │     dumbbell.fill tinted BRICK #A8331F
│ │ │ 🏋 │  ⟳ Recurring                       │ │
│ │ └────┘                                    │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ ┌────┐  Reading                      ›    │ │     book.fill — NO color → espresso fallback
│ │ │ 📖 │                                     │ │
│ │ └────┘                                    │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │  ◀─ mid-swipe-left reveals the delete tray:
│ │ Family                    ›  │ 🗑 Delete  │ │     trailing full-swipe, --danger brick + cream
│ └──────────────────────────────────────────┘ │
│                                              │
│······································ (scroll) │
└─────────────────────────────────────────────┘
     [ floating warm-glass tab bar ]              ← Today · Calendar · [Settings] · + (separated)
              ⎯⎯⎯ (34pt home gutter) ⎯⎯⎯
```

**Region by region:**
1. **Nav bar** — back ("‹ Settings") leading; **`+`** trailing rendered as a small clay **wax-seal** well with a cream `+` glyph (the rationed moment — minting a label "makes it stick"). Large title **"Groups"** (Fraunces `displayL`) collapses to inline on scroll.
2. **Group row** (repeats, sorted by `sortOrder`) — a `CueCard`-style letterpress row, tap-anywhere → opens the **Edit** sheet for that group:
   - **Icon tile** (leading): a **36×36** rounded square, `medium 8` corner, fill `--surface`, **1pt `--border`** outline; centered SF Symbol from `TaskGroup.icon` (fallback `folder.fill`) at ~16pt, tinted by `TaskGroup.color` resolved via `Color(hex:)` — **fallback `--primary` espresso** when color is nil.
   - **Text column** (gap `md 12` from tile): **name** in `titleM` Fraunces, `--text-primary`; below it (gap `xxs 2`), ONLY when the group has a default recurrence (`defaultRecurrenceRuleId != nil`), a **`⟳ Recurring`** sub-label — `repeat` SF Symbol + the word "Recurring" in `caption`, `--text-secondary`.
   - **Chevron** (trailing): `chevron.right`, `caption` weight, `--text-secondary` — the affordance that the row pushes to edit.
3. **Trailing swipe action** — full-swipe-left reveals a single **Delete** (`trash` + "Delete"), `--danger` brick fill + cream label. Full-swipe triggers `DELETE /task-groups/:id` — which **ungroups its tasks, does not delete them** (no destructive-data confirmation needed, but a brief undo affordance is welcome — see states).
4. **Empty state** — when there are no groups: a centered, themed `ContentUnavailableView`: a `folder` glyph in `--text-secondary`, title **"No Groups"** (`titleM`/`headline` Fraunces, `--text-primary`), description **"Tap + to create your first group."** (`callout`, `--text-secondary`) with the **+** rendered in `--accent-text` clay so the eye finds the real toolbar `+`. Optionally a single `.decisive` **"Create your first group"** button in the thumb zone (which then carries the wax seal instead of the toolbar `+`).

**The ONE wax-seal / clay moment:** the **`+` Create** affordance (toolbar seal-well, or the empty-state `.decisive` button) — minting a label is the "make it stick" act. Every group's own color lives only inside its small icon-tile glyph as membership data; the Delete swipe uses brick (destructive role), not clay. No other terracotta on the screen.

---

## Data & states

Bound to the real backend + on-device shapes (`GET /task-groups` → `[TaskGroupDTO]`, mirrored on-device as `@Model EventTaskGroup`, `@Query(sort: \.sortOrder)`):

- **Row order** → `TaskGroup.sortOrder` (ascending). The list is the SwiftData `@Query` sorted by `sortOrder`; the network fetch upserts into it (SWR pattern — cached rows show instantly, refresh in background).
- **Name** → `TaskGroup.name` (`EventTaskGroup.name`). Row title.
- **Icon** → `TaskGroup.icon` (SF Symbol string, e.g. `briefcase.fill`, `cart.fill`, `dumbbell.fill`, `book.fill`, `heart.fill`); **fallback `folder.fill`** when nil.
- **Color** → `TaskGroup.color` (hex string, e.g. `#3E6B57`), resolved via `Color(hex:)`; tints the **glyph only**; **fallback `--primary` espresso** when nil/malformed.
- **Recurrence badge** → presence of `TaskGroup.defaultRecurrenceRuleId` (non-nil) → show the `⟳ Recurring` sub-label. (The full rule lives in `TaskGroupDTO.recurrence`; the list only needs the boolean presence.)
- **Tap row** → open `GroupEditSheet(existingDTO:)` for that group (`14-group-edit.md`) — edit name / color / icon / default recurrence.
- **`+`** → open `GroupEditSheet(existingDTO: nil)` (create); on save → `POST /task-groups` (the sheet resolves a `calendarId` via `GET /calendars`, creating a "Default" calendar if none).
- **Swipe Delete** → `DELETE /task-groups/:id` → `DeletedIDResponse { id }`; locally removes the `EventTaskGroup` and its cached DTO. **Server-side this ungroups the tasks** (sets their `groupId` to null); the tasks themselves persist.

**States:**
- **Default (populated):** the rows above, sorted by `sortOrder`, cached-then-refreshed.
- **Loading (first run, no cache):** a centered `ProgressView` tinted `--primary` over the warm `--background` (the screen's real overlay). If cached `@Query` rows exist, show them immediately and refresh silently (no blocking spinner) — SWR.
- **Empty:** the **"No Groups" / "Tap + to create your first group."** `ContentUnavailableView` + `folder` glyph (the real strings). Optional thumb-zone `.decisive` create button.
- **Load error:** rows fall back to whatever is cached in SwiftData; a transient **NotificationBanner** (`.error`, brick rail) titled **"Couldn't load groups"** (the real `groups.error.load` string) appears as global chrome — NOT a full-page error (the list keeps cached content).
- **Delete error:** the optimistically-removed row **returns** (re-insert), and a **NotificationBanner** (`.error`, brick) titled **"Couldn't delete group"** (`groups.error.delete`) fires. Never silently swallow.
- **Long group name:** wraps to ≤2 lines in `titleM` (never truncated mid-row); the icon tile stays top-aligned, the row grows. At AX Dynamic Type sizes the name may wrap to 3 lines — the chevron stays vertically centered to the text block.
- **Many groups (overflow):** the list simply scrolls; no "+N more" here (this IS the full management surface — every group is a row). Bottom inset clears the floating tab bar + 34pt gutter.
- **No icon / no color (edge):** glyph = `folder.fill`, tint = espresso `--primary` — a valid, calm default (see "Reading" row).
- **Offline:** cached `@Query` rows render fully (SwiftData is the source of truth offline). `+` and tap-to-edit still open the sheet; **save / delete** queue or surface a banner "You're offline — try again when connected." until reachable. The list never blanks offline.

---

## Interactions & motion

- **Push in / pop:** standard `NavigationStack` push from Settings; large "Groups" title slides up + collapses to inline on scroll (system). Back swipe from the left edge pops to Settings. Reduce Motion → the push becomes a **cross-fade**, title collapse is instantaneous.
- **Tap a row → Edit sheet:** the row depresses 1pt (letterpress, `.easeOut(0.16)`), then the `GroupEditSheet` presents at `.medium` (sheet motion owned by `14-group-edit.md`). `.sensoryFeedback(.selection)` on tap.
- **`+` Create (the signature):** tapping the **clay wax-seal `+`** stamps — `WaxSeal` `.spring(response: 0.42, dampingFraction: 0.62)`, scale 0.4→1, rotation −8°→0° (~450ms settle) — then the create sheet rises. `.sensoryFeedback(.success)` fires. **Reduce Motion fallback:** the seal **cross-fades** (opacity only) from well to stamped, no spring/rotation; the sheet still presents. (If you use a plain toolbar `+` instead of the seal-well, the press is a simple 1pt depress with `.selection` haptic — but prefer the seal for the rationed moment.)
- **Swipe-to-delete:** trailing swipe reveals the brick **Delete**; full-swipe commits. On commit the row **collapses** (`.snappy` height + opacity) and `DELETE /task-groups/:id` fires optimistically. `.sensoryFeedback(.impact)` on commit. **Offer a brief undo** (3s) via a banner ("Group removed — tasks kept · Undo") since delete only ungroups (recoverable). Reduce Motion → the row removal is instant (no collapse animation), undo banner still appears.
- **Reorder (if/when enabled):** `sortOrder` implies drag-to-reorder is the natural extension — long-press a row → lift (`.snappy` scale to 1.02 + value-cut shadow deepens to `.valueCut`), drag, drop snaps to slot; persists new `sortOrder`. **Not in the as-built screen** — list only if the founder wants it; otherwise omit and keep rows static.
- **Pull-to-refresh:** `.refreshable` re-runs `GET /task-groups` (SWR upsert); a small spinner tinted `--primary`. Reduce Motion unaffected.
- **Button press (empty-state CTA):** the `.decisive` "Create your first group" depresses 1pt downward (`.easeOut(0.16)`) with the `--primary-pressed` multiply overlay @0.22 ("ink soaking in").

The **160ms ease-out** (every press) and the **single seal spring** (the `+` create) are the two recurring signatures — do not invent new curves.

---

## iOS specifics

- **Dynamic Type:** all roles are relative type styles — group names, the "Recurring" sub-label, and empty-state copy scale. At AX sizes the name wraps (never clips), the row grows, the icon tile stays fixed at 36pt (a glyph anchor), and the chevron stays centered to the text block.
- **Haptics (`.sensoryFeedback`):** `.selection` on row tap (open edit) · `.success` on the `+` create-seal stamp · `.impact` on swipe-delete commit. Respect the system haptic setting.
- **Context menu:** long-press a row → `contextMenu` exposing **Edit** and **Delete** (`role: .destructive`) — a discoverable mirror of the tap + trailing-swipe, so delete isn't swipe-only.
- **Swipe actions:** trailing, **full-swipe enabled** → **Delete** (`trash`, `--danger` brick, cream). No leading swipe on this management list (there's no "complete a group" concept — leading=complete belongs to task rows, not groups).
- **VoiceOver labels:**
  - Row: "Work, group, briefcase icon, sage. Recurring." (icon **color is never the sole signal** — the recurrence is spoken as the word "Recurring," and the group is identified by name, not hue). For a non-recurring group: "Errands, group, cart icon, brass." Trait: button; hint: "Opens group editor."
  - The icon tile is folded into the row label (decorative on its own → `.accessibilityHidden(true)` as a separate element; its meaning lives in the spoken row label).
  - Delete: exposed as an `accessibilityAction(named: "Delete")` and via the context menu — never swipe-only for VoiceOver users. Spoken consequence: "Deletes the group and ungroups its tasks; tasks are kept."
  - `+`: "New group." (The wax seal itself is `.accessibilityHidden(true)`; the button carries the label.)
  - Empty state: "No groups. Tap the plus button to create your first group." with the `+` reachable as a labeled element.
  - Never color-only meaning: recurrence = the badge **text** ("Recurring") + the `repeat` glyph, never the icon hue; group identity = its **name**, never its color alone.

---

## ✦ Claude Design prompt (paste this)

```
Design a single native iOS 26 screen: "Task groups" for CUE, an AI-assisted calendar + Telegram-
assistant app. Use the published "Kraft & Ink" design system and its tokens ONLY — no new colors,
fonts, gradients, or pure white/black surfaces.

FRAME: Fixed iPhone 393×852pt @3x, NOT responsive — a native iOS screen, not a web page. This is a
STACK-PUSHED screen inside Settings: a "‹ Settings" back chevron at top-leading, a large Fraunces
title "Groups" that collapses to inline on scroll, and a TRAILING "+" toolbar action. Full iOS
status bar (time + battery), Dynamic Island reserved (no content beneath it), top safe area ~59pt,
34pt home-indicator gutter, 16pt side margins, all tap targets ≥44pt. A warm-tinted Liquid-Glass
3-tab bar (Today / Calendar / Settings, with Settings selected) + a separated "+" floats at the
bottom; the last row clears it.

PURPOSE: List, create, edit, and delete the task GROUPS that lend their color + icon (and optional
recurrence) to tasks. Each group is a colored, icon-stamped paper tab.

LAYOUT (top → bottom):
  1. Nav bar: back "‹ Settings" left; trailing "+" rendered as a SMALL CLAY WAX-SEAL WELL with a
     cream "+" glyph (the ONE rationed accent — minting a label "makes it stick"). Large Fraunces
     title "Groups" (displayL 34) below, collapsing inline on scroll.
  2. A vertical list of GROUP ROWS, each a CueCard-style letterpress row on warm paper (--surface,
     radius 10, 1pt --border + hard value-cut shadow at --text-primary 6%, BLUR RADIUS 0, y:1),
     tap-anywhere to edit. Each row, left→right:
       • a 36×36 ICON TILE: rounded square, corner radius 8 (medium), fill --surface, 1pt --border
         outline, centered SF Symbol at ~16pt whose GLYPH is tinted by that group's own color
         (data — NOT the rationed accent); fallback glyph folder.fill tinted espresso --primary
         when no color.
       • gap 12, a text column: the group NAME in Fraunces titleM (18, medium), --text-primary;
         and ONLY when the group has a default recurrence, a sub-label below (gap 2): a "repeat"
         SF Symbol + the word "Recurring" in Public Sans caption (12), --text-secondary.
       • a trailing chevron.right (caption weight, --text-secondary).
  3. Trailing SWIPE action on each row (full-swipe enabled): a single "Delete" (trash icon +
     "Delete"), --danger brick fill + cream label. Deleting UNGROUPS the tasks (keeps them).
  4. EMPTY-STATE variant: a centered ContentUnavailableView — a "folder" glyph in --text-secondary,
     title "No Groups" (Fraunces), description "Tap + to create your first group." (Public Sans
     callout, --text-secondary) with the "+" emphasized in --accent-text clay.

COMPONENTS (by name): CueCard (--surface, radius 10, letterpress depth as above), WaxSeal (the
"+" create affordance — an irregular hand-pressed CLAY blob, NOT a clean circle, --secondary fill
+ --primary-pressed 40% rim multiply + centered cream "+" glyph), CueButton .decisive (used ONLY
in the empty-state as "Create your first group" — full-width, radius 6, clay fill + cream label,
press = 1pt downward letterpress offset). System themed ContentUnavailableView for empty.

REAL CONTENT (verbatim, no lorem, no "Group 1"): rows in sortOrder —
  • Work — briefcase.fill, glyph SAGE #3E6B57, "⟳ Recurring"
  • Errands — cart.fill, glyph BRASS #C9A24B, no recurrence
  • Workout — dumbbell.fill, glyph BRICK #A8331F, "⟳ Recurring"
  • Reading — book.fill, NO color → espresso fallback glyph, no recurrence
  • Family — heart.fill, glyph CLAY #BE4A28, no recurrence (shown mid-swipe revealing Delete)

DATA BINDINGS (real backend fields): name = TaskGroup.name; icon = TaskGroup.icon (SF Symbol,
fallback folder.fill); color = TaskGroup.color (hex → tints glyph only, fallback espresso);
recurrence badge = presence of TaskGroup.defaultRecurrenceRuleId; order = TaskGroup.sortOrder. Tap
row → edit sheet; "+" → create sheet (POST /task-groups); swipe Delete → DELETE /task-groups/:id
(ungroups tasks, keeps them).

STATES to render alongside the default populated list: (a) EMPTY — the "No Groups" /
"Tap + to create your first group." ContentUnavailableView with folder glyph; (b) MID-SWIPE — the
"Family" row swiped left to reveal the brick Delete action; (c) LONG NAME — a row whose name wraps
to 2 lines without truncation, icon tile top-aligned, chevron centered to the text block.

MOTION: the "+" wax seal stamps with spring(response 0.42, damping 0.62) — scale 0.4→1, rotation
−8°→0° (~450ms) — then the create sheet rises; Reduce-Motion = seal cross-fades opacity-only, no
rotation. Rows depress 1pt on tap (160ms ease-out) before pushing to edit. Swipe-delete collapses
the row (snappy height + opacity) then offers a 3s "Group removed — tasks kept · Undo" banner;
Reduce-Motion = instant removal, undo banner still shown. Haptics: .selection on row tap, .success
on the "+" seal, .impact on delete commit.

iOS PATTERNS: NavigationStack push from Settings; large-title collapse on scroll; .swipeActions
trailing full-swipe = Delete (brick); context menu on each row mirrors Edit + Delete so delete is
not swipe-only; .refreshable pull-to-refresh; Dynamic Type with relative styles (names wrap, never
clip); VoiceOver speaks the group NAME + "Recurring" word + icon, never color alone, and exposes
Delete as an accessibility action.

ANTI-AI-SLOP GUARDRAILS (hard): NO Inter / Helvetica / SF Pro — pin Fraunces (the "Groups" title +
group names, ≥17pt), Public Sans (the "Recurring" sub-label + empty copy), JetBrains Mono reserved
for receipts (not needed here). NO purple, NO blue accents, NO gradients, NO glassmorphism on the
content rows (glass is chrome-only — the nav + tab bar — re-tinted WARM, never Apple cool blue).
NO soft uniform drop shadows — letterpress only (1px --border + hard value-cut, blur 0). NO pure
#FFFFFF surface-on-white, NO pure #000000. NO generic evenly-spaced bento grid and NO multi-column
card grid — this is a single-column stacked list of paper rows that breathes. Crisp 8–10px
cut-paper corners (tile 8, row 10), never 16–20px squircle bubbles. The terracotta wax seal appears
EXACTLY ONCE — on the "+" Create affordance; every GROUP'S OWN COLOR is membership data living only
inside its small icon-tile glyph (it may even be clay — that is data, not the accent); the Delete is
brick (destructive), structure is espresso/ink. Color presence, not a rainbow of row chrome. Do not
say "modern / clean / sleek / beautiful". Honor Kraft & Ink exactly; native iOS, not a web page.
```
