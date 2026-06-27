# Settings home

> The hub — a typesetter's "colophon" page: who you are (profile), how the app looks and speaks (appearance + language), and the doors to everything else (Groups, Telegram, Notifications & Report, AI Assistant, Account), ending with Sign Out.

This screen **exists in code** (`Features/Settings/SettingsView.swift`) as a SwiftUI `Form`. Regenerate it faithfully — same sections, same field bindings, same Telegram-status logic — but render it in the **Kraft & Ink** system exactly, binding every element to the **real backend fields** named below. Links push to the per-screen pages noted (13 Groups, 15 Telegram, 16 Notifications/Report, 17 AI Assistant, 18 Account).

---

## Design system (Kraft & Ink)

Use the published **"Kraft & Ink"** system and its tokens ONLY. No new colors, fonts, gradients, or pure white/black. Reference everything by name; never invent hex.

**Color (opaque sRGB; reference by role):**
- `--background #FFFFFF` — app canvas behind everything (the white page; the `Form` background, scroll content background hidden).
- `--surface #FAF6EF` — grouped-inset section blocks, rows (faint warm paper; never whiter than the page).
- `--surface-elevated #FEFCF8` — raised surfaces (not heavily used here).
- `--surface-sunken #F1EADF` — recessed strips: the leading icon tiles on each link row, picker tracks, zebra.
- `--primary #5A3A24` (espresso) — structural tint, row icons, chevrons, the avatar ring, selected segmented control. The backbone.
- `--primary-pressed #43291A` — pressed state of primary.
- `--secondary #BE4A28` (clay) — **FILL ONLY**, rationed. On this screen there is **NO clay fill** — Settings is a calm structural hub with no single "commit" moment. (See "rationed clay placement" — the screen deliberately spends zero clay.)
- `--accent-text #A53D22` — the ONLY clay allowed as **text / icons / thin rules** (AA-safe). Used sparingly for the live "@handle" connected affordance accent if any, and nowhere decorative.
- `--on-accent #FBF5EA` (cream) — ink placed on a primary/secondary fill (e.g. inside the selected segmented control).
- `--text-primary #2E211A` — body + headings (warm near-black): the display name, row labels.
- `--text-secondary #6E5C4C` — supporting / muted text: email, section eyebrows, trailing status values, footers.
- `--separator #D0BA98` — DECORATIVE hairlines only (faint inter-row rules inside a section, never a real edge).
- `--border #8C7142` — FUNCTIONAL edges a user must locate (section block outlines, the avatar ring is `--primary`).
- `--success #466234` (olive) — the Telegram "connected" state read (a finished/agreed state).
- `--warning #C9A24B` (brass) — pending / not-connected hint (FILL only; place INK on it, never cream).
- `--danger #A8331F` (brick) — **Sign Out** label (destructive, text only — no brick fill).
- Discipline: clay is one-hot and here unspent. Olive = connected/done, brass = pending, espresso = structure. **Color presence, not a rainbow.**

**Typography (3 bundled families — substitute via Google Fonts in preview; NEVER Inter/SF Pro):**
- **Fraunces** (display, ≥17pt only): `display-L` 34 semibold −0.4 (the "Settings" large nav title), `title-L` 22 medium −0.2, `title-M` 18 medium −0.2 (the profile display name), `headline` 17 medium.
- **Public Sans** (body/labels): `body` 16 regular (row labels), `body-emph` 16 semibold (the Sign Out label, button labels), `callout` 15 regular (email, supporting), `label` 13 medium +0.3 (section-header eyebrows — `textCase(nil)`, never SCREAMING CAPS; chip text), `caption` 12 regular (footers).
- **JetBrains Mono** (receipt voice — handles, timestamps, IDs, the palette name as a stamp): `code` 13 regular +0.2 (the connected `@jane_doe` handle, `linkedAt` date), `code-small` 11 medium +0.8.
- Rule: Fraunces is the editorial voice for titles ≥17pt — never for dense labels/body. The Telegram handle and any timestamp read in **JetBrains Mono** (receipt voice, wider tracking). Section eyebrows are Public Sans `label` with system uppercasing **suppressed** (`textCase(nil)`) so they read as typeset headings, not iOS shout-caps.

**Spacing (4pt grid):** `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 (default gap / row inner) · xl 20 · xxl 24 (between sections) · xxxl 32 · huge 48`. 16pt side margins (grouped-inset blocks inset from the page edge). Let the paper breathe between sections.

**Radius (crisp cut-paper, never squircle bubbles):** `chip 4 · small 6 (default) · medium 8 (the grouped section blocks + the leading icon tiles) · card 10 · large 12`. Grouped-inset section blocks = `medium 8`, NOT the iOS-default 10–12 squircle.

**Depth — "letterpress, not float" (blur radius 0 always):**
- `letterpress` (default) = 1pt `--border` stroke + hard `--text-primary @6%` value-cut, y:1 — applied to each grouped section block (it reads as a crisp pressed card of rows, not a floating bubble).
- `value-cut` = 1pt `--border` + `--text-primary @12%`, y:2 (reserved; not needed here).
- NO soft uniform drop shadows anywhere. System **Liquid Glass** (frosted) is ONLY the chrome (tab bar, nav bar), re-tinted **warm** toward kraft/clay — never Apple's cool blue-grey. The `Form`/rows themselves are letterpress paper, never glass.

**Components (by name):**
- **CueCard** — the grouped section block: fill `--surface`, radius `medium 8`, letterpress depth; rows divided by faint 1pt `--separator` inset hairlines.
- **CueAvatar** — circle, ~56pt, always ringed by a **1.5pt `--primary` stroke**; placeholder = `--surface-sunken` + `person.fill` glyph in `--text-secondary` (`size*0.42`).
- **CueButton** — used only conceptually for the segmented appearance control; the link rows are native grouped-inset `NavigationLink` rows, not buttons. `.destructive` variant logic governs the Sign Out color (brick label), but Sign Out renders as a centered text row, not a filled button.
- **CueChip** — not present on this screen (no chips here).
- **WaxSeal** — **not present** on this screen. Settings has no commit moment; the seal is reserved for completing a task and saving an event only.
- **Leading icon tiles** — each link row leads with a small `--surface-sunken` rounded-rect tile (radius `medium 8`, ~28pt) holding an SF Symbol in `--primary` (espresso). Tiles, not bare glyphs, give the hub its "labelled drawer" feel.

---

## Frame & platform

- **Single fixed iPhone 393×852pt @3x. NOT responsive** — a native iOS 26 screen, not a web page.
- iOS status bar at top (time left, cellular/wifi/battery right). **Dynamic Island reserved** (don't draw under it). Top safe area ~59pt. 34pt home-indicator gutter at the bottom; keep content + Sign Out clear of it.
- 16pt side margins; grouped-inset section blocks inset from the page edge. All tap targets ≥44pt (every row ≥44pt).
- **Nav chrome:** large-title nav at root — **"Settings"** in Fraunces ~34pt (`display-L`, `--text-primary`), collapsing to an inline ~17pt title on scroll. **No trailing nav-bar action** here (search is NOT offered on Settings — it lives on Today/Calendar only). No back button (root of the Settings tab stack).
- **Bottom: floating warm-tinted Liquid-Glass tab bar**, ~21pt insets from sides/bottom, fully expanded. THREE merged destination tabs + ONE separated trailing action capsule:
  - `Today` (`sun.max`-style), `Calendar` (`calendar`), `Settings` (`gearshape`, **selected** — espresso ink).
  - Separated to the right in its own capsule: **"+"** (`plus.circle.fill`) — an *action item* that opens the Create sheet over the current tab; never a destination, never shows selected.
- **One-handed reach:** the profile + appearance read-only zones sit up top; the most-tapped doors (Groups, Telegram, Notifications, AI Assistant, Account) and the **Sign Out** row sit in the lower thumb arc. Sign Out is last, far from the integrations, to avoid mis-taps.

---

## Layout

Top → bottom. A native grouped `Form` (inset style) over `--background` with the scroll background hidden, 16pt side margins, `--space-xxl (24)`-ish between section blocks. Real CUE content — no lorem.

```
┌──────────────────────────────────────────────┐
│ ●●●  9:41                       ▂▄ 􀙇 100%▐     │  status bar (Dynamic Island reserved)
│                                                │
│  Settings                                      │  large-title nav, Fraunces display-L
│                                                │
│ ┌────────────────────────────────────────────┐ │  PROFILE section (CueCard block)
│ │  ( JA )   Jane Appleseed                    │ │  CueAvatar (1.5pt primary ring) + title-M
│ │  ◯ring    jane.appleseed@icloud.com         │ │  email in callout, --text-secondary
│ └────────────────────────────────────────────┘ │
│                                                │
│  Appearance                                    │  section eyebrow (label, textCase nil)
│ ┌────────────────────────────────────────────┐ │
│ │  Theme               [ Light ]  ⌄           │ │  picker, LIGHT pinned (only option live)
│ │  ─────────────────────────────────────────  │ │  --separator inset hairline
│ │  Palette             Kraft & Ink            │ │  read-only row, value in --text-secondary
│ └────────────────────────────────────────────┘ │
│                                                │
│  Language                                      │
│ ┌────────────────────────────────────────────┐ │
│ │  Language            [ English ]  ⌄         │ │  picker: System / English / Українська
│ └────────────────────────────────────────────┘ │
│  Some changes apply after restart.             │  footer caption, --text-secondary
│                                                │
│  Manage                                        │
│ ┌────────────────────────────────────────────┐ │
│ │  ▦ folder   Groups                      ›   │ │  → page 13 (icon tile + chevron)
│ └────────────────────────────────────────────┘ │
│                                                │
│  Integrations                                  │
│ ┌────────────────────────────────────────────┐ │
│ │  ◰ plane   Telegram      @jane_doe ●done ›  │ │  → page 15, LIVE status trailing
│ │  ─────────────────────────────────────────  │ │
│ │  ◰ bell    Notifications & Report   On   ›  │ │  → page 16
│ │  ─────────────────────────────────────────  │ │
│ │  ◰ wand    AI Assistant         Jarvis   ›  │ │  → page 17, persona presetName
│ └────────────────────────────────────────────┘ │
│                                                │
│  Account                                       │
│ ┌────────────────────────────────────────────┐ │
│ │  ◰ person  Account                      ›   │ │  → page 18
│ └────────────────────────────────────────────┘ │
│                                                │
│ ┌────────────────────────────────────────────┐ │
│ │                 Sign Out                    │ │  centered, --danger (brick) body-emph
│ └────────────────────────────────────────────┘ │  destructive role, NO fill
│                                                │
│        (34pt home-indicator gutter)            │
│   ┌─────────────────────────┐   ┌───┐          │
│   │  Today   Calendar  Settings│  │ + │         │  floating warm Liquid-Glass tab bar
│   └─────────────────────────┘   └───┘          │  Settings selected + separated "+"
└──────────────────────────────────────────────┘
```

**Region detail (top → bottom):**

1. **Profile section** (a single-row CueCard block). Leading **CueAvatar** (~56pt, 1.5pt `--primary` ring) decoded from `UserDTO.avatarBase64` (base64, no data-URL prefix); placeholder = `--surface-sunken` + `person.fill`. To its right, a 2-line stack: the **display name** in Fraunces `title-M` (`--text-primary`, 1 line, tail-truncated) from `UserDTO.displayName` — fall back to *"Signed in"* if nil/empty; and the **email** in Public Sans `callout` (`--text-secondary`, 1 line) from `UserDTO.email` — hidden entirely if nil/empty. The whole row is **not** a navigation link in code today (it's a static summary); render it as a non-chevron row. (If you add a tap target, it should push to page 18 Account — but match the real app: no chevron, read-only.)

2. **Appearance section.** Eyebrow `Appearance` (Public Sans `label`, `--text-secondary`, `textCase(nil)`). Two rows:
   - **Theme** — a menu/segmented picker. **Light is pinned** — it's the only live option (the app pins `.light` at root). Render it as a single-value picker reading `Light`, espresso selection; if shown as a segmented control, `Light` is selected (`--primary` fill + cream `--on-accent` text), no other segment competes.
   - **Palette** — a **read-only** `LabeledContent` row: label `Palette` (`--text-primary`), value `Kraft & Ink` (`--text-secondary`). Kraft & Ink is the sole palette; this row exists only to keep the section meaningful (no picker — there is nothing to choose).

3. **Language section.** Eyebrow `Language`. One picker row: **Language** → values `System` / `English` / `Українська` (`AppLanguage` cases). Selected reads the current choice (e.g. `English`). Footer caption (`--text-secondary`): *"Some changes apply after restart."*

4. **Manage section.** Eyebrow `Manage`. One `NavigationLink` row → **Groups** (page 13): leading `--surface-sunken` icon tile with `folder.fill` (`--primary`), label `Groups` (`body`), trailing disclosure chevron (`--text-secondary`). Only shown when authenticated.

5. **Integrations section.** Eyebrow `Integrations`. Three `NavigationLink` rows, each with a leading sunken icon tile + label + a **trailing live status read** + chevron:
   - **Telegram** (page 15) — tile `paperplane.fill`. Trailing status is **live**, branching on `TelegramLinkStore.Status` (see Data & states): connected → the `@handle` in **JetBrains Mono `code`** with an olive `--success` dot/word; not connected → `Not connected` (`callout`, `--text-secondary`); loading/unknown → a small espresso `ProgressView` spinner; failed → `Not connected` (the row degrades quietly). This is CUE's headline integration — give the connected handle the most presence (mono receipt voice).
   - **Notifications & Report** (page 16) — tile `bell.badge.fill`. Trailing: `On` / `Off` (`callout`, `--text-secondary`) reflecting the daily-report `enabled` flag (or blank if not yet loaded).
   - **AI Assistant** (page 17) — tile `wand.and.stars` (or `sparkles`). Trailing: the persona `presetName` (e.g. `Jarvis`, `code`/`callout`, `--text-secondary`).

6. **Account section.** Eyebrow `Account`. One `NavigationLink` row → **Account** (page 18): tile `person.crop.circle`, label `Account`, chevron.

7. **Sign Out.** A final standalone section block with a single **centered** row: `Sign Out` in Public Sans `body-emph`, `--danger` (brick) — destructive role, **text only, no brick fill** (a filled brick button would over-shout for a reversible action). Tapping clears auth (`AuthStore.signOut()`) and the Telegram link (`TelegramLinkStore.clear()`). Only shown when authenticated.

> **DEBUG-only note (don't render in the founder's mock):** the real app has a `#if DEBUG` "Developer · Notifications" section at the very top for firing test banners. It is compiled out of release builds — **omit it from the design**.

**Rationed clay placement:** **ZERO clay on this screen.** Settings is a structural hub with no single decisive commit — it deliberately spends no `--secondary`. Everything is espresso (structure/icons/chevrons), olive (Telegram connected), brass (pending), brick (Sign Out text), or warm paper. The one place clay-as-**text** (`--accent-text`) may appear is the connected Telegram accent, and even that is optional. No wax seal anywhere.

---

## Data & states

Bind every element to these exact backend shapes (DTOs as defined in `Networking/APIModels.swift`; stores as in `Features/Settings`).

| UI element | Source field / endpoint |
|---|---|
| Avatar | `UserDTO.avatarBase64` (base64, no data-URL prefix; decode → `UIImage`; placeholder if nil/undecodable) via `CueAvatar` |
| Display name | `UserDTO.displayName` (trimmed; fall back to "Signed in" if nil/empty) — only shown when `AuthStore.state == .authenticated(user)` |
| Email | `UserDTO.email` (1 line; row hidden if nil/empty) |
| Theme picker | `ThemeSettings.appearance` (`AppearanceMode`); **Light pinned** — light is the only live value |
| Palette row | static `AppPalette.kraftInk` title ("Kraft & Ink") — read-only, no endpoint |
| Language picker | `LanguageSettings.selected` (`AppLanguage`: `.system` / `.english` / `.ukrainian`) |
| Groups link | pushes `GroupsScreen()` (page 13); shown only when authenticated |
| Telegram status (trailing) | `TelegramLinkStore.status` via `GET /assistant/link` → `TelegramLinkStatusDTO { linked, telegramUsername, linkedAt }`; refreshed in `.task` on appear |
| Telegram handle | `telegramUsername` formatted as `@handle` (prepend `@` if missing); generic "Connected" if linked but username nil |
| Notifications & Report | daily-report `enabled` from `GET /users/me/report-settings` → On/Off (page 16) |
| AI Assistant | persona `presetName` from `GET /users/me/persona-settings` (e.g. "Jarvis") (page 17) |
| Account link | pushes Account/Profile (page 18) using `UserDTO` |
| Sign Out | `AuthStore.signOut()` + `TelegramLinkStore.clear()`; shown only when authenticated |

**Telegram trailing-status branches (the one live cell — match `TelegramLinkStore.Status` exactly):**
- `.unknown` / `.loading` → small espresso `ProgressView` spinner (no text).
- `.connected(username, linkedAt)` → `@jane_doe` in **JetBrains Mono `code`** (`--text-secondary`) + a small olive `--success` dot or "connected" affordance. If `username` is nil → the generic localized "Connected".
- `.notConnected` → `Not connected` (`callout`, `--text-secondary`).
- `.failed(message)` → renders as `Not connected` here (the failure surfaces on page 15, not as a Settings-row error).

**States to render (produce variants):**
- **Default** — populated, authenticated: avatar + "Jane Appleseed" + email; Light theme; English; all five link rows; Telegram **connected** showing `@jane_doe`; Notifications `On`; AI Assistant `Jarvis`; Sign Out present.
- **Signed out / pre-auth** — the profile, Groups, Integrations, Account, and Sign Out sections **disappear** (every authenticated-only section is gated on `AuthStore.state == .authenticated`). Only **Appearance** and **Language** remain. (In practice the user reaches Settings only after auth, but render this variant — it's the real `if case .authenticated` gating.)
- **Telegram loading** — the Telegram row trailing shows the espresso spinner while the cold `GET /assistant/link` resolves; the rest of the page is fully interactive (status load is independent).
- **Telegram not-connected** — trailing reads `Not connected` (brass/muted), inviting a tap to page 15.
- **Avatar fallback** — `avatarBase64` nil or undecodable → `CueAvatar` placeholder (sunken paper + `person.fill`), not a broken image.
- **Edge cases:**
  - *Long display name* → Fraunces `title-M`, 1 line, tail-truncated; full name via VoiceOver. Never clip mid-glyph.
  - *Long email* → `callout`, 1 line, tail-truncated.
  - *Long Telegram handle* → mono `code`, truncates head-or-tail so the `@` stays visible; chevron never pushed off-row.
  - *Offline* → Telegram status keeps the last-known value (no spinner thrash); a transient fetch failure does NOT replace the row — it stays on the prior value or `Not connected`.
  - *Missing report/persona data* → trailing reads blank (no "On/Off"/persona) until loaded; never a placeholder dash that looks like a value.

---

## Interactions & motion

- **Tap a link row** → push the destination onto the Settings `NavigationStack` with the standard iOS push (slide-in, interruptible). Groups→13, Telegram→15, Notifications & Report→16, AI Assistant→17, Account→18. Row press = the native grouped-row highlight (a brief `--surface-sunken` fill), **not** a scale or shadow bounce. **Reduce-Motion fallback:** push becomes a cross-fade; no parallax.
- **Theme / Language pickers** → tapping opens the native menu/wheel; selection commits immediately and re-tints/re-localizes live (`ThemeSettings` / `LanguageSettings` are `@Observable`). The segmented theme control (if rendered as segments) slides the selection capsule `.snappy`; `.sensoryFeedback(.selection)` on change. **Reduce-Motion:** capsule jumps without the slide.
- **Telegram status appear** → on first mount the row trailing animates from spinner → resolved value with a quiet `.easeOut` opacity cross-fade (≤160ms) once `refreshStatus()` lands; never a jarring pop. **Reduce-Motion:** instant swap.
- **Sign Out tap** → presents a native **confirmation** (action sheet / `.confirmationDialog`: *"Sign out of CUE?"* with a destructive *"Sign Out"*). On confirm: `AuthStore.signOut()` + `TelegramLinkStore.clear()`, then the root swaps to the auth/onboarding flow (cross-fade, not a hard cut). `.sensoryFeedback(.impact)` on the destructive confirm. The row itself depresses with the grouped-row highlight, no clay, no seal.
- **Pull-to-refresh** — optional on the form; if present, re-runs `refreshStatus()` for the Telegram row. `.sensoryFeedback(.impact)` on release.
- **No wax-seal animation on this screen** — there is no commit moment. Do not invent one.

---

## iOS specifics

- **Dynamic Type:** every text style is relative (`relativeTo:`) — display name, row labels, the mono handle all scale. At AX sizes: the profile row's name/email stack stays 2 lines (truncate, don't clip); link rows let the trailing status drop **below** the label if the row gets tall (label-over-status stack) rather than squeezing the chevron off; the leading icon tile stays ≥28pt and the row stays ≥44pt.
- **Haptics (`.sensoryFeedback`):** `.selection` on theme/language change and tab switches; `.impact` on the Sign Out destructive confirm and pull-to-refresh release. Respect the system haptic setting. No `.success` here (nothing is "completed").
- **Context menus / swipe actions:** none on the link rows (they're plain `NavigationLink`s; secondary actions live on their destination pages). Do **not** add swipe-to-delete or context menus to Settings rows.
- **VoiceOver labels:**
  - Profile: *"Jane Appleseed, jane.appleseed@icloud.com. Profile."* (avatar reads *"Profile photo"* or *"Default profile photo"* matching which variant renders).
  - Theme: *"Theme, Light. Button."* Palette: *"Palette, Kraft & Ink."* Language: *"Language, English. Button."*
  - Groups: *"Groups. Button."* Telegram (connected): *"Telegram, connected as at jane underscore doe. Button."* (not-connected): *"Telegram, not connected. Button."* (loading): *"Telegram, checking status."*
  - Notifications: *"Notifications and Report, On. Button."* AI Assistant: *"AI Assistant, Jarvis. Button."* Account: *"Account. Button."*
  - Sign Out: *"Sign Out. Button."* (trait: destructive.)
  - Never convey meaning by color alone — the Telegram connected/not-connected state has both a word/handle and (for connected) an olive dot; Sign Out reads its destructive trait, not just brick color.

---

## ✦ Claude Design prompt (paste this)

```
SCREEN: Settings home — CUE's Settings tab: a calm structural hub for profile, appearance, language,
and the doors to Groups, Telegram, Notifications & Report, AI Assistant, and Account, ending with Sign Out.

SYSTEM: Use the published "Kraft & Ink" design system and its tokens ONLY. No new colors, fonts,
gradients, or pure white/black surfaces. This screen spends ZERO clay --secondary and has NO wax
seal — it is a structural hub with no commit moment. Reference tokens and components by NAME.

FRAME: Single fixed iPhone 393×852pt @3x. NOT responsive — a native iOS 26 screen, not a web page.
iOS status bar (time + battery; Dynamic Island reserved). Top safe area ~59pt; 34pt home-indicator
gutter; 16pt side margins; all tap targets >=44pt. Root large-title nav: "Settings" in Fraunces ~34pt
collapsing to inline ~17pt on scroll, NO trailing nav action (search is NOT on Settings). Bottom:
floating WARM-tinted Liquid-Glass tab bar (never minimizes) — three merged tabs Today / Calendar /
Settings (Settings SELECTED, espresso ink), plus a SEPARATED trailing "+" action capsule
(plus.circle.fill) that opens the Create sheet over the current tab.

AUDIENCE: a signed-in user managing their account, appearance, the Telegram AI-assistant link, and
notification preferences — visiting occasionally, not daily.

LAYOUT (top -> bottom, native grouped-inset Form on --background, ~24pt between section blocks; each
section block is a CueCard: --surface fill, radius 8, letterpress depth (1px --border + hard value-cut),
rows divided by faint 1pt --separator inset hairlines):
  1. PROFILE block — a single non-chevron row: leading CueAvatar (~56pt, 1.5pt --primary ring) +
     a 2-line stack: display name "Jane Appleseed" (Fraunces title-M, --text-primary, 1 line) and
     email "jane.appleseed@icloud.com" (Public Sans callout, --text-secondary, 1 line). Read-only.
  2. "Appearance" eyebrow (Public Sans label 13, --text-secondary, NOT uppercased). Block, two rows:
       - Theme            [ Light ]   (picker; Light is the only live option — light-only app)
       - Palette          Kraft & Ink (READ-ONLY LabeledContent, value in --text-secondary, no picker)
  3. "Language" eyebrow. Block, one picker row: Language [ English ] (options: System / English /
     Українська). Footer caption (--text-secondary): "Some changes apply after restart."
  4. "Manage" eyebrow. Block, one NavigationLink row: a leading --surface-sunken rounded icon tile
     (radius 8, ~28pt) with folder.fill in --primary + label "Groups" (body) + trailing disclosure chevron.
  5. "Integrations" eyebrow. Block, three NavigationLink rows (each: sunken icon tile + label + LIVE
     trailing status + chevron):
       - paperplane.fill  Telegram      trailing "@jane_doe" in JetBrains Mono code + a small olive
                          --success dot  (CUE's headline integration — give the handle the most presence)
       - bell.badge.fill  Notifications & Report   trailing "On" (callout, --text-secondary)
       - wand.and.stars   AI Assistant             trailing "Jarvis" (the persona presetName)
  6. "Account" eyebrow. Block, one NavigationLink row: person.crop.circle tile + "Account" + chevron.
  7. Sign Out — a final standalone block, ONE centered row: "Sign Out" in Public Sans body-emph,
     --danger (brick) — destructive, TEXT ONLY, no brick fill.
  Bottom: floating warm Liquid-Glass tab bar — Today / Calendar / Settings (selected) + separated "+".

COMPONENTS (by name): CueCard (the grouped section blocks), CueAvatar (profile), native grouped-inset
NavigationLink rows with leading --surface-sunken icon tiles holding espresso SF Symbols. NO CueChip,
NO WaxSeal, NO CueButton fill — the link rows are rows, Sign Out is a destructive text row.

REAL CONTENT (verbatim — no lorem, no "Item 1"): name "Jane Appleseed"; email
"jane.appleseed@icloud.com"; theme "Light"; palette "Kraft & Ink"; language "English"; rows "Groups",
"Telegram" + "@jane_doe", "Notifications & Report" + "On", "AI Assistant" + "Jarvis", "Account";
"Sign Out". Section eyebrows: Appearance / Language / Manage / Integrations / Account.

NATIVE PATTERNS: grouped-inset Form; tappable NavigationLink rows pushing onto the Settings stack with
the standard iOS push; native menu/segmented pickers for Theme & Language committing immediately;
a .confirmationDialog on Sign Out ("Sign out of CUE?", destructive "Sign Out"); leading icon tiles;
trailing disclosure chevrons in --text-secondary. All rows >=44pt.

STATE: Show the populated, authenticated default (Telegram CONNECTED as "@jane_doe"). ALSO produce:
Telegram LOADING (trailing = small espresso spinner, rest of page interactive); Telegram NOT-CONNECTED
(trailing "Not connected", muted); avatar FALLBACK (sunken paper + person.fill when avatarBase64 is nil);
signed-out (only Appearance + Language sections remain — profile/Groups/Integrations/Account/Sign Out
gone, all gated on authentication).

ANTI-AI-SLOP GUARDRAILS (hard): Fraunces for titles >=17pt ONLY (the "Settings" large title + the
profile name); Public Sans for all row labels/body; JetBrains Mono for the Telegram @handle and any
timestamp — NEVER Inter or SF Pro. Section eyebrows are Public Sans label with uppercasing SUPPRESSED
(typeset, not iOS shout-caps). Letterpress depth = 1px --border + hard value-cut (blur 0) on the
section blocks — NO soft drop shadows, NO gradients, NO glassmorphism on content (glass is chrome-only
and WARM-tinted, never Apple cool blue). NO purple, NO neon, NO blue accents, NO pure #FFFFFF
cards-on-white, NO pure #000000. Grouped blocks + icon tiles use crisp 8px cut-paper corners, NEVER
16–20px squircle bubbles. SPEND ZERO clay --secondary and NO wax seal — Settings has no commit moment;
do NOT invent one. Telegram connected = olive --success (word + dot, never color-only); Sign Out =
--danger brick TEXT ONLY (no filled button). Native iOS 26 patterns throughout. Don't describe it as
"modern/clean/sleek/beautiful".
```
