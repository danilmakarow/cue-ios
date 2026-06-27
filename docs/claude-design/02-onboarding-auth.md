# Onboarding & Sign-in

A 3-screen value + permission flow (calendar → AI/Telegram assistant → notifications) that ends in **Sign in with Apple**, then drops the user into the tabs landing on **Today**. The whole flow is a `fullScreenCover` shown before the tab UI ever appears.

> **For Claude Design:** this is ONE prompt that should render **four artboards side by side** — Value Screen 1, Value Screen 2 (with the wax-seal moment), Value Screen 3, and the Sign-in screen. They share one paged container. Use the published **"Kraft & Ink"** system and its tokens ONLY. The literal token restatement below makes this prompt self-sufficient; do not invent a palette, fonts, gradients, or pure white/black surfaces.

---

## Design system (Kraft & Ink) — literal restatement

**Identity:** espresso ink on a clean white page, ONE rationed terracotta "wax seal" accent. Crisp cut-paper edges, letterpress depth (border + hard value-cut, blur radius 0 — never a soft float). Light mode only. A typesetter's notebook, not a SaaS dashboard.

**Colors (opaque sRGB — reference by role, never paste hex into copy):**
- `--background` `#FFFFFF` — app canvas behind everything (the page).
- `--surface` `#FAF6EF` — cards / rows (faint warm paper, never whiter than the page).
- `--surface-elevated` `#FEFCF8` — top sheets / modals / elevated surfaces.
- `--surface-sunken` `#F1EADF` — recessed strips (header bands), the paged-dots track, zebra.
- `--primary` `#5A3A24` — espresso hero; structural tint, key actions, selected chips, page-dot active.
- `--primary-pressed` `#43291A` — pressed state of primary.
- `--secondary` `#BE4A28` — rationed **clay**, **FILL ONLY** (the ONE decisive CTA fill, the wax seal). Never as text.
- `--accent-text` `#A53D22` — the ONLY clay allowed as **text / icons / thin rules** (AA-safe).
- `--on-accent` `#FBF5EA` — cream ink placed on a primary/secondary fill.
- `--text-primary` `#2E211A` — body + headings (near-black warm).
- `--text-secondary` `#6E5C4C` — supporting / muted text.
- `--separator` `#D0BA98` — DECORATIVE hairlines only (~1.88:1, never a real edge).
- `--border` `#8C7142` — FUNCTIONAL edges a user must locate (card outlines, the unstamped seal-well).
- `--success` `#466234` olive (done) · `--warning` `#C9A24B` brass (pending; ink on it, never cream) · `--danger` `#A8331F` brick (destructive) · `--info` `#5A3A24` (= primary).
- **One-hot rule:** clay `--secondary` is the single decisive moment per screen — the wax seal OR the one CTA, never both lit at once, never decoration. Selected chips/dots fill espresso `--primary`, NOT clay, so they never compete with the seal.

**Typography (3 bundled families — web preview via Google Fonts; NEVER Inter / SF Pro):**
- Display/headings: **Fraunces** (use for titles ≥17pt only).
- Body/labels: **Public Sans** (default body; button labels = semibold).
- Code/receipts: **JetBrains Mono** (dates, counts, IDs, stamps, eyebrows).
- Ramp used on this screen: `displayL` Fraunces 34 semibold (tracking −0.4) · `displayM` Fraunces 27 semibold (−0.4) · `titleL` Fraunces 22 medium (−0.2) · `titleM` Fraunces 18 medium (−0.2) · `headline` Fraunces 17 medium · `body` Public Sans 16 · `bodyEmphasis` Public Sans 16 semibold (button labels) · `callout` Public Sans 15 · `label` Public Sans 13 medium (tracking 0.3 — eyebrows / chip text) · `caption` Public Sans 12 · `code` JetBrains Mono 13 (tracking 0.2) · `codeSmall` JetBrains Mono 11 medium (tracking 0.8). The "Cue" wordmark is Fraunces ~50 semibold (one-off display).
- Tracking rule: display reads tighter (negative); receipts read wider (positive).

**Spacing (4pt grid):** `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 (default gap / card inner) · xl 20 · xxl 24 (between cards) · xxxl 32 · huge 48 (hero / empty breathing room)`. 16pt side margins on phone; the onboarding pages use `xxxl 32` horizontal insets and `huge 48` bottom padding to feel ceremonial.

**Radius (cut paper — NO 16–20pt squircles):** `chip 4 (rubber-stamp) · small 6 (default — buttons, fields, the SIWA button) · medium 8 (icon tiles, banners) · card 10 · large 12 (sheets / prominent cards)`.

**Depth ("letterpress, not float", both shadows blur radius 0):**
- `.letterpress` = 1pt `--border` stroke + shadow(`--text-primary` 6%, y:1) — card default.
- `.valueCut` = 1pt `--border` stroke + shadow(`--text-primary` 12%, y:2) — crisp stacked-paper offset.
- `.glass` = system Liquid Glass, **chrome only** (here: nothing — onboarding is immersive, no tab bar). No soft uniform drop shadows anywhere.

**Components used on this screen:**
- **BrandMark** — the logo: a clay wax seal (`WaxSealShape`, irregular hand-pressed blob, ~16 vertices) with a cream Fraunces "C" monogram. Brand literals fixed: clay `#BE4A28`, rim `#8A2F18`, cream `#FBF5EA`. Rendered at `size: 96` on the value screens and `size: 96` on sign-in (with the "Cue" wordmark beneath).
- **WaxSeal** — `WaxSeal(isStamped:, size:, systemImage:)`. **Unstamped** = dashed empty "seal-well" (1.5pt `--border` stroke, dash 4/4, 90% opacity). **Stamped** = `--secondary` clay fill + `--primary-pressed` 40% rim stroke (multiply) + centered cream SF Symbol. This is the **one rationed wax-seal moment**, on Value Screen 2 (the AI/Telegram screen), illustrating "make it stick."
- **CueButton** — full-width, radius 6, padding v12/h16, label `bodyEmphasis`, press = 1pt downward letterpress depress (no scale/glow/shadow), `.easeOut(160ms)`. `.primary` = espresso fill + cream label (the "Continue" advance button on value screens). `.secondary` = clear fill + 1pt `--border` + espresso label. `.ghost` = clear + `--accent-text` label ("Skip" / "Not now").
- **CueChip** — 4pt rubber-stamp rectangle (NEVER a pill, never pill-with-dot). Selection by fill+ink: unselected = `--surface` fill + `--text-secondary` + 1pt `--border`; selected = `--primary` espresso fill + cream text, no border. Used here only as small static feature tags ("Recurring", "All-day", "Telegram") in the illustrative card — none selected.
- **CueAvatar** — circle, 1.5pt `--primary` ring; placeholder = `--surface-sunken` + `person.fill`. Not central here, but the Apple-derived photo lands on it post-auth (illustrate faintly in the sign-in copy, not rendered).
- **Sign in with Apple button** — Apple's native `SignInWithAppleButton` (`.black` style in light mode), 52pt tall, clipped to radius `medium 8`. **Do NOT restyle Apple's button** — it is the one element that intentionally breaks the palette (HIG requirement). Everything around it is Kraft & Ink.

---

## Frame & platform

- **Single fixed iPhone 393×852pt @3x. NOT responsive** — a native iOS `fullScreenCover`, not a web page. Render each of the 4 artboards at this exact frame.
- iOS **status bar** top (9:41, signal, battery) over the white canvas; **Dynamic Island** reserved (top ~59pt safe area kept clear — the BrandMark sits below it).
- **34pt home-indicator gutter** at the bottom is kept clear; the primary CTA sits in the bottom thumb zone just above it.
- **No tab bar, no nav bar** — onboarding is immersive (`fullScreenCover`). The ONLY chrome is: a top-trailing **"Skip" ghost button** on the two value screens that don't carry the seal, and a **paged dots indicator** ( • • • , three dots) centered low on the value screens. Sign-in has no Skip and no dots (it is terminal).
- **One-handed reach:** primary "Continue" / "Allow Notifications" / Apple button all live in the bottom third. The page swipes horizontally; nothing critical is in the top corners except the optional Skip.
- Page transitions are a horizontal pager (`TabView .page` style, indicator hidden — we draw our own dots).

---

## Layout (top → bottom, per artboard)

Realistic CUE content throughout — real-sounding tasks/groups, real product copy. **No lorem.**

### Artboard A — Value Screen 1 of 3: "Calendar"
Eyebrow + hero + a faint illustrative agenda card. Establishes the unified calendar+task model.

```
┌─ 393×852 ──────────────────────────────┐
│  9:41          􀙇 􀛨 􀛧          (status)  │
│                                  Skip ›  │  ← ghost, --accent-text, top-trailing
│                                          │
│              ▓ BrandMark ▓               │  ← clay wax seal, size 96, centered
│                                          │
│   ONE PLACE FOR EVERY                    │  ← eyebrow `label`, --text-secondary, tracking 0.3
│   Your day, in one timeline.             │  ← `displayM` Fraunces 27, --text-primary
│   Events and to-dos live together —      │  ← `body` Public Sans, --text-secondary,
│   all-day, timed, or repeating.          │     2 lines, generous leading
│                                          │
│  ┌─ CueCard (--surface, letterpress) ─┐  │
│  │ 􀉉  Standup with design         9:00 │  │  ← row: SF glyph + title `body` + time `code`
│  │ 􀐫  Dentist — Dr. Alvarez      11:30 │  │     (JetBrains Mono), olive group tick
│  │ 􀈕  Submit Q3 expense report   16:00 │  │
│  │ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄ separator ┄┄┄┄ │  │
│  │ [Recurring] [All-day] [Telegram]    │  │  ← static CueChips, unselected
│  └─────────────────────────────────────┘  │
│                                          │
│              • ○ ○   (page dots)         │  ← active dot --primary, rest --separator
│                                          │
│  ┌───────────── Continue ─────────────┐  │  ← CueButton .primary (espresso), full-width
│  └─────────────────────────────────────┘  │
│            ( 34pt home gutter )           │
└──────────────────────────────────────────┘
```
- NO wax-seal/clay-CTA lit here — the advance button is espresso `.primary`, dots active is espresso. The only clay on this artboard is the **BrandMark** logo (sanctioned brand literal).

### Artboard B — Value Screen 2 of 3: "AI + Telegram assistant" ← **the wax-seal moment**
The differentiator screen. Shows a Telegram-style message being "stamped" into the calendar — the wax seal illustrates "make it stick."

```
┌─ 393×852 ──────────────────────────────┐
│  9:41          􀙇 􀛨 􀛧                    │
│                                  Skip ›  │
│                                          │
│              ▓ BrandMark ▓               │  ← size 96
│                                          │
│   YOUR ASSISTANT, ON TELEGRAM            │  ← eyebrow `label`
│   Just tell Cue what's next.             │  ← `displayM` Fraunces 27
│   Message the bot in plain words and     │  ← `body`, --text-secondary
│   it schedules, reminds, and reports     │
│   back — morning brief, evening recap.   │
│                                          │
│  ┌─ CueCard (--surface-elevated) ──────┐  │
│  │  ┌ chat bubble (--surface-sunken) ┐ │  │  ← inbound Telegram message, mono-ish
│  │  │ "Lunch with Priya Fri 1pm,     │ │  │     `body`, quoted
│  │  │  remind me 30 min before"      │ │  │
│  │  └────────────────────────────────┘ │  │
│  │             ↓  parsed               │  │  ← thin --accent-text arrow + `code` "parsed"
│  │   ┌──────────────┐                  │  │
│  │   │  ✦ WaxSeal   │  Lunch with Priya│  │  ← STAMPED clay seal, size 56, cream ✓ glyph
│  │   │   (stamped)  │  Fri · 13:00     │  │     title `titleM` Fraunces + time `code`
│  │   └──────────────┘  reminder −30m   │  │     `caption` --text-secondary
│  └─────────────────────────────────────┘  │
│                                          │
│              ○ • ○   (page dots)         │
│                                          │
│  ┌───────────── Continue ─────────────┐  │  ← CueButton .primary (espresso, NOT clay)
│  └─────────────────────────────────────┘  │
│            ( 34pt home gutter )           │
└──────────────────────────────────────────┘
```
- **THE one rationed clay moment of the entire flow is the STAMPED WaxSeal here.** Because the seal is the hot accent on this artboard, the "Continue" button stays espresso `.primary` (never `.decisive` clay) — only one clay element lit. The BrandMark logo at top is the sanctioned brand literal and doesn't count against the ration.

### Artboard C — Value Screen 3 of 3: "Notifications" (permission opt-in)
The notifications value + the single combined toggle that governs reminders AND the morning-brief/evening-shutdown ritual (in-app card + optional Telegram message).

```
┌─ 393×852 ──────────────────────────────┐
│  9:41          􀙇 􀛨 􀛧                    │
│                                  Skip ›  │
│                                          │
│              ▓ BrandMark ▓               │  ← size 96
│                                          │
│   STAY ONE STEP AHEAD                    │  ← eyebrow `label`
│   Gentle nudges, never noise.            │  ← `displayM` Fraunces 27
│   Reminders before tasks, plus your      │  ← `body`, --text-secondary
│   optional morning brief and evening     │
│   shutdown — in Cue and on Telegram.     │
│                                          │
│  ┌─ CueCard (--surface) ───────────────┐  │
│  │ 􀝆 Task reminders                    │  │  ← row: SF glyph + `titleM` + `caption` sub
│  │    "30 min before Dentist"          │  │
│  │ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄ │  │
│  │ 􀉭 Morning brief & evening recap [ON]│  │  ← row + a system Toggle (espresso tint)
│  │    Delivered in-app and on Telegram │  │
│  └─────────────────────────────────────┘  │
│                                          │
│              ○ ○ •   (page dots)         │
│                                          │
│  ┌──────── Allow Notifications ───────┐  │  ← CueButton .primary (espresso) — triggers
│  └─────────────────────────────────────┘  │     the system permission prompt
│           Not now   (ghost)              │  ← CueButton .ghost, --accent-text, centered
│            ( 34pt home gutter )           │
└──────────────────────────────────────────┘
```
- No clay-fill CTA here either — "Allow Notifications" is espresso `.primary`; "Not now" is a `.ghost`. The toggle, when ON, fills espresso `--primary` (selected = espresso, never clay).

### Artboard D — Sign-in (terminal screen, no Skip, no dots)
The real `AuthView`. BrandMark + Fraunces "Cue" wordmark + tagline, then the native Apple button and the disclaimer.

```
┌─ 393×852 ──────────────────────────────┐
│  9:41          􀙇 􀛨 􀛧                    │
│                                          │
│                  (spacer)                │
│              ▓ BrandMark ▓               │  ← clay wax seal, size 96, centered
│                                          │
│                  Cue                     │  ← Fraunces ~50 semibold, --text-primary
│        Your day, cued just right.        │  ← `callout` Public Sans, --text-secondary
│                  (spacer)                │
│                                          │
│  ┌─  Sign in with Apple ─────────────┐  │  ← NATIVE Apple button, black, 52pt, radius 8
│  └─────────────────────────────────────┘  │
│   We use your Apple ID to create your     │  ← `caption`, --text-secondary, centered,
│   Cue account. No password required.      │     2 lines
│            ( 34pt home gutter )           │
└──────────────────────────────────────────┘
```
- **No clay accent here at all** except the BrandMark logo — the Apple button is the only CTA and it must stay Apple-black per HIG. The wax-seal ration was spent on Artboard B.

---

## Data & states

Bind every element to the real backend contract.

- **BrandMark / wordmark / tagline:** static brand — `BrandMark(size: 96)`, wordmark verbatim "Cue" (Fraunces 50 semibold), tagline string `auth.tagline` = **"Your day, cued just right."** (EN) / "Ваш день — точно за сигналом." (UK).
- **Disclaimer:** string `auth.disclaimer` = **"We use your Apple ID to create your Cue account. No password required."**
- **Sign in with Apple** → `SignInWithAppleButton(.signIn)` requesting `[.fullName, .email]`. On success the app calls **`POST /auth/apple`** with body:
  ```
  AppleSignInRequest { identityToken, fullName?, avatarBase64?, timezone? }
  ```
  where `identityToken` = Apple's JWT, `fullName` = formatted `PersonNameComponents` (Apple returns it only on first sign-in), `avatarBase64` = best-effort "Me" contact photo, and **`timezone` = `TimeZone.current.identifier`** (e.g. "Europe/Berlin") — this device timezone is persisted into **`User.timezone`** and drives all later time math (daily report time, reminders). Response = `AuthResponse { accessToken, user: UserDTO }`; the JWT is stored in keychain, `state → .authenticated(user)`, and the cover dismisses into the tabs landing on **Today**.
- **UserDTO** the response carries: `{ id, appleUserId, email?, displayName?, avatarBase64?, timezone, createdAt, updatedAt }` — `displayName` ("Jane Appleseed") and `avatarBase64` seed the Today greeting and the Settings `CueAvatar`.
- **Notifications opt-in (Artboard C):** the "Allow Notifications" button triggers the system `UNUserNotificationCenter` permission prompt (render the screen *before* the iOS system alert; the alert itself is OS chrome, not designed here). The single **"Morning brief & evening recap" toggle** maps to the same setting governing the in-app Today ritual card AND the optional Telegram message (later persisted via `GET/PATCH /users/me/report-settings → { enabled, reportTimeLocal }` in `User.timezone`). Per-task reminders are illustrated as the "Task reminders" row (schema: `NotificationRule.offsetMinutes`, `channel` PUSH/TELEGRAM — UI in scope; client controller is a follow-up).
- **States to render (as labelled variants beside the main artboards):**
  - **Signing-in (loading):** Apple button disabled at 0.5 opacity; below it a small `ProgressView().controlSize(.small)` + `auth.signingIn` = **"Signing you in…"** in `caption` / `--text-secondary`. No full-screen scrim — the page stays.
  - **Sign-in error:** native `.alert` titled `auth.alert.signInFailed.title` = **"Couldn't sign in"** with the API/Apple error message and an "OK" cancel button. (Render a small inset showing the alert copy — do not restyle the system alert.) User cancellation is silently ignored (no error).
  - **Permission already-granted edge:** if notifications were granted earlier, Artboard C's primary button reads "Continue" instead of "Allow Notifications" and the system prompt is skipped.
  - **Skip path:** tapping "Skip ›" on any value screen jumps straight to Artboard D (sign-in is mandatory; only the value/permission pages are skippable).
  - **Offline at sign-in:** `POST /auth/apple` fails → same "Couldn't sign in" alert with a network message; the user stays on Artboard D and can retry. No tab access without a token.
  - **Long display name / long localization (UK):** Fraunces hero and `body` copy must wrap to up to 3 lines without clipping; the illustrative card rows truncate task titles with a tail ellipsis (`Submit Q3 expense report…`), times in `code` never truncate.
  - **First-launch only:** the whole `fullScreenCover` shows once (no persisted token). On a returning launch with a valid keychain JWT, `bootstrap()` validates `/auth/me` and the cover is skipped entirely — note this so the flow isn't designed as recurring.

---

## Interactions & motion

- **Page advance:** horizontal swipe or "Continue" tap moves A→B→C with a standard `.page` pager slide (~350ms, iOS default ease). The **paged dots** crossfade their active fill (espresso `--primary`) to the new index with `.easeOut(160ms)`. *Reduce Motion:* keep the slide but drop any parallax on the card/BrandMark; dots still crossfade.
- **Wax-seal stamp (Artboard B, the signature animation):** when Screen 2 becomes the active page, the inbound chat bubble is already present; the **WaxSeal stamps in** with the canonical spring `.spring(response: 0.42, dampingFraction: 0.62)` — scale 0.4→1, opacity 0→1, rotation −8°→0° — synchronized with a faint downward settle of the parsed-event row (8pt → 0, same spring). Pair with `.sensoryFeedback(.success, …)` haptic. *Reduce Motion:* replace the spring with a 200ms opacity crossfade from the unstamped dashed seal-well to the stamped seal; no scale/rotation, no settle. The seal is `.accessibilityHidden(true)` (the row text carries the meaning).
- **CueButton press:** every primary/ghost button uses the letterpress depress — a 1pt downward offset, `.easeOut(160ms)`, no scale/glow/shadow. *Reduce Motion:* unchanged (it's a 1pt translate, not motion-sickness territory) but it may be dropped to a fill-darken if the system flag is set.
- **Sign in with Apple tap:** Apple presents its own system sheet (Face ID / confirm) — OS-owned, not animated by us. On return, the page enters the **signing-in** state (button → 0.5 opacity, spinner + "Signing you in…" fade in, `.easeOut(160ms)`).
- **Cover dismissal → tabs:** on `.authenticated`, the `fullScreenCover` dismisses with the standard cover slide-down, revealing the Today tab. *Reduce Motion:* the system already crossfades covers under Reduce Motion — no custom work.
- **"Not now" / "Skip":** instant navigation, no special transition beyond the pager/cover defaults.

---

## iOS specifics

- **Dynamic Type:** all text uses relative styles (`relativeTo:` is baked into the ramp) — Fraunces heroes scale, `body` copy reflows to 3 lines, illustrative card rows truncate-with-ellipsis rather than clip. Test at AX1 and AX3: the BrandMark and a single Continue button must always remain on-screen (let the middle card scroll if needed, never the CTA).
- **Haptics (`.sensoryFeedback`):** `.success` on the wax-seal stamp (Artboard B); `.selection` on each page advance / dot change; `.success` again on a successful `POST /auth/apple` return; `.error` is NOT used — sign-in failure shows the alert only. Respect the system haptic setting.
- **VoiceOver labels:**
  - BrandMark — decorative, `.accessibilityHidden(true)`; the "Cue" wordmark is the accessible app name.
  - Value screens — each is one `.accessibilityElement(children: .combine)` page reading e.g. *"Your assistant, on Telegram. Just tell Cue what's next. Message the bot in plain words and it schedules, reminds, and reports back."* The stamped seal contributes no VO output; the parsed row reads *"Lunch with Priya, Friday 1 PM, reminder 30 minutes before."*
  - Page dots — `.accessibilityValue("Page 2 of 3")`.
  - Continue / Allow Notifications / Not now / Skip — plain button labels; "Skip" hints *"Skips to sign in."*
  - Sign in with Apple — Apple's native accessibility (do not override).
- **No swipe-to-delete / context menus** here — onboarding is linear. The only gesture is the horizontal pager; the visible "Continue" / dots are the discoverable fallback (no gesture is the sole path forward).
- **Reduce Transparency:** no glass on this flow anyway (immersive, white canvas) — nothing to solidify.
- **Contrast:** all text on the white `--background` / `--surface` clears AA; the cream "C" on the clay seal is brand-fixed (logo, exempt). Do not place clay as text — eyebrows and the "Skip"/"Not now" use `--accent-text` `#A53D22` (AA-safe), never `--secondary`.

---

## ✦ Claude Design prompt (paste this)

> Render **four iPhone artboards side by side**, each a fixed **393×852pt @3x native iOS screen — NOT responsive, not a web page**. iOS status bar (9:41, signal, battery) on a white canvas; Dynamic Island reserved (top ~59pt clear); 34pt home-indicator gutter clear; 32pt side margins. **No tab bar, no nav bar** — this is an immersive `fullScreenCover` onboarding flow. Use the published **"Kraft & Ink"** design system and its tokens ONLY.
>
> This is CUE's onboarding: a 3-screen value/permission flow that ends in Sign in with Apple, then drops into the app. The four artboards are: **(A) Calendar value**, **(B) AI + Telegram assistant value**, **(C) Notifications permission**, **(D) Sign-in**.
>
> **Artboard A — "Calendar":** centered **BrandMark** (clay wax-seal logo with a cream Fraunces "C", size 96). Eyebrow in Public Sans 13 medium (`--text-secondary`): "ONE PLACE FOR EVERYTHING". Hero in **Fraunces 27 semibold** (`--text-primary`): "Your day, in one timeline." Body in Public Sans 16 (`--text-secondary`): "Events and to-dos live together — all-day, timed, or repeating." Below, a **CueCard** (`--surface` fill, letterpress depth = 1px `--border` + hard value-cut, blur 0) listing real agenda rows: "Standup with design · 9:00", "Dentist — Dr. Alvarez · 11:30", "Submit Q3 expense report · 16:00" (titles Public Sans 16, times in **JetBrains Mono 13**), a `--separator` hairline, then three static **CueChips** (4px rubber-stamp rectangles, NOT pills): "Recurring", "All-day", "Telegram". Three **page dots** (active = espresso `--primary`, rest = `--separator`). Bottom: a full-width **CueButton .primary** (espresso `--primary` fill, cream label) reading "Continue". Top-trailing **ghost** "Skip ›" in `--accent-text`.
>
> **Artboard B — "AI + Telegram assistant" (THE ONE WAX-SEAL MOMENT):** same BrandMark, eyebrow "YOUR ASSISTANT, ON TELEGRAM", hero "Just tell Cue what's next.", body "Message the bot in plain words and it schedules, reminds, and reports back — morning brief, evening recap." Below, a **CueCard** (`--surface-elevated`) showing an inbound Telegram chat bubble (`--surface-sunken` fill, rounded radius 8) quoting: "Lunch with Priya Fri 1pm, remind me 30 min before" — then a thin `--accent-text` downward arrow labeled "parsed" in JetBrains Mono, then a parsed event row: a **STAMPED WaxSeal** (irregular hand-pressed clay `--secondary` blob, ~16 vertices, with a `--primary-pressed` rim and a centered cream checkmark, size 56) beside "Lunch with Priya" (Fraunces 18) / "Fri · 13:00" (JetBrains Mono 13) / "reminder −30m" (Public Sans 12, `--text-secondary`). This stamped seal is the screen's single clay accent — keep the "Continue" button espresso `.primary`, never clay. Page dots (2nd active). Skip ghost top-trailing.
>
> **Artboard C — "Notifications":** BrandMark, eyebrow "STAY ONE STEP AHEAD", hero "Gentle nudges, never noise.", body "Reminders before tasks, plus your optional morning brief and evening shutdown — in Cue and on Telegram." **CueCard** (`--surface`) with two rows: "Task reminders" (Fraunces 18) + sub "30 min before Dentist" (Public Sans 12); a `--separator` rule; "Morning brief & evening recap" (Fraunces 18) + sub "Delivered in-app and on Telegram" with a system **Toggle ON** filled espresso `--primary` (NOT clay). Page dots (3rd active). Bottom: **CueButton .primary** "Allow Notifications" (espresso), and centered beneath it a **CueButton .ghost** "Not now" in `--accent-text`. Skip ghost top-trailing.
>
> **Artboard D — "Sign-in":** centered **BrandMark** (size 96), the wordmark "Cue" in **Fraunces ~50 semibold** (`--text-primary`), tagline "Your day, cued just right." in Public Sans 15 (`--text-secondary`). Then the **native Apple "Sign in with Apple" button** — black, full-width, 52pt tall, radius 8, **left exactly as Apple ships it, do NOT restyle it**. Beneath, small print in Public Sans 12 (`--text-secondary`), centered: "We use your Apple ID to create your Cue account. No password required." No Skip, no page dots — this screen is terminal. The only clay on this artboard is the BrandMark logo.
>
> **Also show a small "signing-in" variant** of Artboard D: Apple button at 50% opacity with a small spinner + "Signing you in…" (Public Sans 12, `--text-secondary`) below it.
>
> **Typography:** Fraunces for all headings/wordmark (titles ≥17pt only), Public Sans for body and button labels, JetBrains Mono for times/counts/the "parsed" label. **Letterpress depth only** — 1px `--border` + hard value-cut offset, blur radius 0; crisp 4–12px cut-paper corners.
>
> **GUARDRAILS (hard):** NO Inter / SF Pro — pin Fraunces + Public Sans + JetBrains Mono. NO purple, NO blue accents, NO gradients, NO glassmorphism on content cards, NO soft blurred drop shadows, NO pure #FFFFFF cards floating on white, NO pure #000000 (the Apple button's black is Apple's own, exempt). NO generic evenly-spaced bento grid — this is a vertical, ceremonial onboarding, not a dashboard. Honor Kraft & Ink exactly: espresso `--primary` carries structure; clay `--secondary` is FILL-ONLY and appears as the **single wax-seal moment on Artboard B and nowhere else** (the BrandMark logo is the sanctioned brand literal); clay-as-text uses `--accent-text` only. Selected chips/toggles/dots fill espresso, never clay. Use native iOS patterns: real status bar, immersive fullScreenCover, a horizontal page indicator we draw ourselves, the unmodified system Sign in with Apple button, and a bottom-thumb-zone primary CTA. Use the real CUE copy and task names above — absolutely no lorem ipsum.
