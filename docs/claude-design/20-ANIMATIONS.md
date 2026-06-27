# CUE — Motion & Transitions (consolidated, cross-screen)

> **Single source of truth for motion.** This file consolidates every cross-screen animation,
> transition, and haptic into one implementation-ready spec. It is the motion sibling of
> [`01-DESIGN-SYSTEM.md`](01-DESIGN-SYSTEM.md) (tokens, wax seal) and is governed by
> [`00-MASTER-BRIEF.md`](00-MASTER-BRIEF.md) (IA, navigation, platform rules). Per-screen prompts
> (`02-…` onward) reference this file for any motion they describe; where a per-screen doc and this
> file disagree, **this file wins** for motion, **`01-DESIGN-SYSTEM.md` wins for visual tokens**.
>
> Constants below are **extracted verbatim from the implemented app** where code exists
> (`cue/DesignSystem/`, `cue/Features/Calendar/UIKit/`), and **specified** where the behavior is
> designed-but-not-yet-wired. Each entry flags which it is. The two recurring signatures are the
> **160ms ease-out** (every press/selection) and the **single seal spring** `.spring(0.42, 0.62)`
> (the two commit moments). Light-only, iOS 26, SwiftUI chrome + one UIKit calendar surface.

---

## 0. Product decisions this motion spec serves

These are fixed across every screen; the motion below assumes them.

- **Navigation:** a 3-tab warm Liquid-Glass tab bar — **Today / Calendar / Settings** — plus a
  **SEPARATED "+" action item** (its own glass capsule, `.search`-role separation) that presents
  the **Create sheet** over whichever tab is active. **Default landing tab = Today.**
- **Search is NOT a tab.** It is a **nav-bar glass island** (trailing icon) reachable from **Today**
  and **Calendar**. Tapping it pushes/presents Search; it is not a root destination.
- **Onboarding:** a **3-screen value+permission flow** — (1) calendar value → (2) AI/Telegram
  assistant → (3) notifications — then **Sign in with Apple**, then drop into the tabs **landing on
  Today**. Presented as a `fullScreenCover` (the one immersive cover).
- **AI ritual:** the morning brief / evening shutdown appears **both** as an in-app card on **Today**
  **and** as an optional **Telegram** message, controlled by **one toggle** in **Notifications**
  settings.
- **Reminders:** per-task reminders **are in v1 design scope** — reminder UI lives in the Create
  sheet and the Notifications screen (the backend controller is a follow-up; `NotificationRule`
  schema already exists). Their motion is ordinary row/picker motion (see §7, §3).
- **Visual base:** Kraft & Ink, exact tokens from `01-DESIGN-SYSTEM.md`. Light-only. Espresso
  `#5A3A24` carries structure; clay `#BE4A28` is **rationed FILL-ONLY** for the single wax-seal
  "make it stick" moment per screen; clay-as-text only `#A53D22`. Fonts: Fraunces / Public Sans /
  JetBrains Mono — **never Inter / SF Pro**. Letterpress depth (border + value-step), cut-paper radii.

---

## 1. Motion tokens (the shared vocabulary)

Reference these by **name** in every per-screen prompt; never hand-pick a one-off curve. All but the
calendar UIKit constants are SwiftUI `Animation` values.

| Token name | Value (exact) | Where it lives in code | Job |
|---|---|---|---|
| `press` | `.easeOut(duration: 0.16)` | `CueButton.swift:54`, `CueChip.swift:62` | every button press (1pt letterpress depress) + chip fill/ink swap. The **160ms ease-out** signature. |
| `seal` | `.spring(response: 0.42, dampingFraction: 0.62)` | `WaxSeal.swift:79` | the **two commit moments** — complete a task, save an event. scale 0.4→1, opacity 0→1, rotation −8°→0°. ~450ms felt; deliberate overshoot ("ink settling"). |
| `decisiveInk` | `press` + `--primary-pressed` multiply overlay @0.22 | `CueButton.swift` (`.decisive`) | the ONE hot clay CTA's press — "ink soaking in", no scale/glow/shadow. |
| `snappy` | `.snappy` (system: ~0.3s, high damping) | `LoadingStateView.swift:108`, `NotificationStore.swift:77/90`, `NotificationBanner.swift:159`, `NotificationHost.swift:38`, `ViewModeSwitcher.swift:30`, `NewEventScreen.swift:145` | crisp UI state swaps: overlay show/hide, banner in/out, view-mode capsule, detent-driven sublayout, chip pivots. |
| `zoomSettle` | UIKit `UIViewPropertyAnimator(duration: 0.32, dampingRatio: 0.9)` | `CalendarZoomController.swift:62/302` | the year↔month↔day cross-scale settle (the `.navigationTransition(.zoom)` analog). |
| `stripPill` | UIKit spring `duration: 0.28, damping: 0.86, initialVelocity: 0` | `WeekStripView.swift:104/105/460/485` | week-strip espresso pill + week-page offset tracking and settle. |
| `todayPill` | UIKit spring `duration: 0.3, damping: 0.8, initialVelocity: 0.5` | `DayJumpToTodayButton.swift:126` | Jump-to-Today pill fade + scale show/hide. |
| `pageSlide` | system `.page` pager (~350ms, iOS default ease) | onboarding pager; day pager (UIKit `UIScrollView` paging) | horizontal page advance. |
| `sectionReveal` | `.easeOut`, ≤200ms, ~40ms stagger | per-screen (Today) | quiet staggered card fade-in on first appear. |

**Felt-duration note:** `seal` reads as ~450ms because of the low damping (0.62) overshoot, even
though `response` is 0.42. Per-screen docs say "(~450ms felt)" — same animation, do not retune.

---

## 2. The global Reduce-Motion rule (apply everywhere)

**Rule:** when `accessibilityReduceMotion` is on (SwiftUI `@Environment(\.accessibilityReduceMotion)`
/ UIKit `UIAccessibility.isReduceMotionEnabled`), **replace every scale / translate / parallax /
spring-overshoot transition with a cross-fade** (`.opacity`, ~120–200ms, ease-out). Keep the
information change; drop the movement. Specifics:

- **Scale/zoom/parallax → opacity cross-fade.** Calendar zoom keeps the **same 0.32s** but
  cross-fades only (no scale). Wax seal cross-fades dashed-well → stamped clay (no scale/rotation).
- **Pager slides** stay (a page turn is not motion-sickness territory) but **drop parallax** on
  inner content / BrandMark. System covers/sheets already cross-fade under Reduce Motion — no custom
  work.
- **1pt letterpress depress stays** — it is a value change (a 1pt translate), not vestibular motion.
  Optionally degrade to a fill-darken if the flag is set; never remove the press feedback entirely.
- **Spinners** (`ProgressView`) are system-standard indeterminate motion and honor Reduce Motion
  automatically — never hand-roll a spin.
- **Staggered reveals → all-at-once opacity** (no stagger, no offset).

> **Landmine (from `01-DESIGN-SYSTEM.md` §8.6):** `WaxSeal.swift` currently applies its
> `.spring(0.42, 0.62)` **unconditionally** — Reduce-Motion honoring is aspirational in code. Every
> screen that stamps a seal MUST gate it on `accessibilityReduceMotion` and fall back to the
> cross-fade below. This is a spec requirement, not yet enforced by the component.

**Reduce Transparency** (separate flag): glass chrome (tab bar, nav island, banner, Today pill,
scope capsule) → **solid warm Kraft fill** (`--surface-elevated` / `--surface-sunken`) behind the
content, no frost. Motion timings are unchanged.

---

## 3. Cross-screen animations (the eleven)

Each entry: trigger · default motion (exact constant) · Reduce-Motion fallback · status
(**implemented** / **specified**). "Specified" = designed here, not yet wired.

### 3.1 Tab switches on the Liquid-Glass bar
- **Trigger:** tap a tab (Today / Calendar / Settings) on the warm glass bar.
- **Default:** system `TabView` cross-fade between tab roots (~0.2s, iOS-owned); the **glass tab bar
  itself does not animate** between tabs (it is persistent chrome). Optional
  `.tabBarMinimizeBehavior(.onScrollDown)` shrinks the bar while scrolling within a tab — deferred
  until tabs have real scroll content. The **"+" action item is separated** and does **not**
  participate in tab selection (tapping it presents the Create sheet — see §3.3 — and keeps the
  current tab selected).
- **Reduce Motion:** system already cross-fades tab content — no custom work; ensure no parallax is
  added on tab roots.
- **Haptic:** `.sensoryFeedback(.selection, trigger: selectedTab)`.
- **Status:** implemented (system `TabView`); haptic **specified**.

### 3.2 Scope zoom — year ↔ month ↔ day (`.navigationTransition(.zoom)` analog)
The calendar is **one zoomable UIKit surface**, not three routes. Constants are the real in-code
values (`CalendarZoomController`).

- **Zoom IN** (year→month→day): *gesture* pinch-OUT, or **tap a cell** (month/day cell is the
  jump target); *visible fallback* tap the **inner segment** of the scope control.
- **Zoom OUT** (day→month→year): *gesture* pinch-IN, or a **downward pull / rubber-band**; *visible
  fallback* tap the **outer segment**. The segmented control is the always-visible equivalent of
  every pinch.
- **Cross-zoom settle (`zoomSettle` = 0.32s, damping 0.9):** the inner scope scales from its
  **anchor-cell footprint** (`collapsedScale = max(cell.w / size.w, 0.06)`) up to full and fades in
  (smoothstep opacity 0.15→0.45); the outer scope **counter-magnifies** into the same cell
  (`min(size.w / cell.w, 3.5)`) and fades out (smoothstep 0.3→0.75). Reads as **one continuous
  magnification anchored on the tapped/pinched cell.**
- **Interactive pinch:** tracks the finger 1:1 (magnification → `innerVisibility` 0…1).
  Direction locks once magnification clears a **0.04** noise threshold. On release,
  **commit-or-cancel** from rest progress (zoom-in commits >0.45, zoom-out commits <0.55) **plus**
  fling velocity (**>1.0/s force-commits**). Interruptible / retargetable: a new gesture or tap
  mid-animation interrupts the running animator and starts fresh.
- **Rubber-band on over-pull:** an over-pinched or under-pulled gesture that doesn't meet the commit
  threshold **springs back to the origin scope** (cancel path) at the same damping 0.9.
- **Snap-to-day:** the Day pager settles to the nearest day on release.
- **Reduce Motion:** **cross-fade only** (opacity 0→1, no scale, no parallax) at the **same 0.32s**;
  rubber-band cancel becomes a cross-fade back; snap-to-day becomes an instant settle.
- **Haptics (specified — not yet wired):** `.sensoryFeedback(.selection, trigger: scopeKind)` on a
  committed scope change; `.sensoryFeedback(.selection, trigger: selectedDate)` on snap-to-day;
  `.sensoryFeedback(.impact)` on zoom commit.
- **Status:** cross-zoom, gesture arbitration, scope-preserving `jump(to:)`, progressive Today are
  **implemented** in UIKit (`CalendarZoomController` / `ZoomGestureArbiter` /
  `CalendarContainerViewController`). The `.sensoryFeedback` haptics and the explicit Reduce-Motion
  cross-fade are **specified-but-not-yet-wired**.

  Companion behaviors on the Day surface (same UIKit container):
  - **Day paging:** horizontal swipe, **inset from the left edge** to protect the system
    back-swipe; the week-strip espresso pill and the strip's own week-page offset slide **in
    lockstep with the finger** (one geometry function of pager offset — they cannot desync). On
    settle the new day commits and the pill springs to the landed tile via `stripPill`
    (0.28 / 0.86). Crossing a week boundary slides the whole strip by exactly the dragged fraction.
  - **Jump-to-Today pill:** appears (fade + scale, `todayPill` 0.3 / 0.8) when off today; tap
    recenters to today's page (animated paging + pill spring) then hides. When **already on today**,
    tapping asks the host to zoom **one level out** toward today (scope-preserving — lands on today
    *at the current zoom*, not a hard reset to Day). Reduce Motion → instant page set + fade.

### 3.3 The "+" Create sheet — present / dismiss + detent changes
- **Trigger:** tap the **separated "+"** action item; the Create sheet presents **over the current
  tab** (which stays mounted underneath).
- **Default:** `.sheet` with `.presentationDetents([.medium, .large])`, **opens at `.medium`** with
  the **keyboard up and the title field auto-focused**. Visible grabber, top-corners-only system
  radius, on `--surface-elevated`. The presenting tab dims behind a static-ish parallax scrim.
  Detent changes (drag grabber / scroll) use the system interactive detent animation; sublayout that
  responds to the detent (e.g. revealing recurrence/group/reminder at `.large`) uses `snappy`.
  Dismiss = system sheet slide-down.
- **Detent snap haptic:** `.sensoryFeedback(.impact, weight: .light)` on a detent settle.
- **Reduce Motion:** detent drag remains (system); the **behind-sheet parallax dimming drops to a
  static scrim**; any height-driven sublayout reveal becomes an instant swap (no height animation).
- **Status:** sheet present/detents **implemented** (`NewEventScreen`); detent haptic **specified**.
  See §4 for the save-seal that lives inside this sheet, and §5 for completion.

### 3.4 Wax-seal press save + the LOCKED settle (THE commit moment)
- **Trigger:** press the `.decisive` Save button in the Create sheet (`POST /tasks`).
- **Press:** `decisiveInk` — 1pt downward letterpress depress, clay → `--primary-pressed` multiply
  overlay @0.22 ("ink soaking in"), `press` (160ms). No scale, no glow, no shadow.
- **Stamp (`seal` = `.spring(response: 0.42, dampingFraction: 0.64)` per the prompt's
  `cubic-bezier(0.34, 1.3, 0.64, 1)` overshoot intent; in-code spring is `0.42 / 0.62` — use the
  code spring as the canonical SwiftUI expression of the **450ms cubic-bezier(0.34,1.3,0.64,1)**
  back-ease-out brief):** the saving-overlay `WaxSeal` stamps — scale **0.4 → 1**, opacity
  **0 → 1**, rotation **−8° → 0°**, clay fill soaking in + centered cream checkmark. ~450ms felt.
- **The LOCKED settle:** after the overshoot resolves, the seal **rests** — no idle/loop animation.
  The rim stroke (`--primary-pressed` @40%, `.multiply`) and the cut-paper value-step read as
  pressure that has *set*. On success the overlay fades (`snappy`) and the sheet dismisses. This
  "locked" rest IS the make-it-stick payoff — the seal must look pressed-and-done, never pulsing.
- **Reduce Motion:** replace the spring with a **150ms opacity + scale-from-0.9 cross-fade** stamp
  (no rotation, no overshoot). Seal still appears and rests; it just doesn't bounce.
- **Haptic:** `.sensoryFeedback(.success)` on the save commit; `.sensoryFeedback(.impact)` on the
  `.decisive` press.
- **Status:** seal stamp **implemented** (`WaxSeal`); save overlay **implemented**; Reduce-Motion
  gate **specified**.

> **Naming note on the brief's curve:** the prompt specifies `450ms cubic-bezier(0.34,1.3,0.64,1)`
> (a back-ease-out with ~30% overshoot). SwiftUI has no raw cubic-bezier with >1 control point that
> overshoots cleanly, so the **canonical expression is the existing spring** `.spring(response:
> 0.42, dampingFraction: 0.62)`, whose overshoot + ~450ms felt duration match the curve's intent.
> Do **not** introduce a literal `Animation.timingCurve(0.34, 1.3, 0.64, 1, duration: 0.45)`
> alongside the spring — keep one seal motion across the app.

### 3.5 Task completion (seal stamp + strike-through)
- **Trigger:** complete a task — tap its seal-well, tap the row checkbox/ring, or leading-swipe →
  Complete (`PATCH /tasks/:id/completion`).
- **List / card mode (the literal seal):** the unstamped dashed `WaxSeal` **stamps** with `seal`
  (0.4→1 / 0→1 / −8°→0°, clay fill in, cream check). The card's leading **spine cross-fades espresso
  → olive `--success`**, the title **strikes through**, the card eases to **62% opacity**, then
  **re-sorts to the bottom** (incomplete chronological first).
- **Timeline mode (the terse ring):** the cream completion ring fills `circle →
  checkmark.circle.fill`; the block drops to **45% opacity** with a strikethrough title. Same
  `PATCH`; no clay seal in this dense mode (the ring is the completion mark).
- **Today / Dashboard inline:** identical stamp; additionally the **LOAD bar nudges** and an
  optional `.success` banner may post.
- **Reduce Motion:** drop the spring/rotation; **cross-fade dashed-well → stamped clay over
  ~120–150ms** (no scale); **no re-sort animation** (the row simply appears in its sorted position).
- **Haptic:** `.sensoryFeedback(.success)` on the completed seal/ring.
- **Status:** seal/ring + opacity **implemented**; re-sort + LOAD nudge **specified** per screen.

### 3.6 The now-line behavior
- **Trigger:** time, on **today's page only**.
- **Default:** a full-width **clay `--secondary`** rule + clay dot in the time gutter at the current
  time. It **advances silently each minute** — **no animation** (an animated creep would be noise).
  The clay here is **structural** (the "now / today" marker), not a competing CTA — it does not
  count against the one-seal-per-screen ration.
- **Reduce Motion:** unchanged (there is no motion to reduce).
- **Haptic:** none.
- **Status:** **implemented** (Day timeline). Decorative → `accessibilityHidden(true)`; the time is
  spoken via the surrounding agenda, not the line.

### 3.7 List insert / delete / reorder
- **Trigger:** create (insert), delete/skip (remove), completion re-sort or group reorder (move).
- **Default:** SwiftUI `List` / `ForEach` default animations driven by identity
  (`(taskId, originalStart)` composite, or group `id`), wrapped in `withAnimation(.snappy)` for
  inserts/removes so rows slide+fade rather than pop. **Delete** = trailing **full-swipe**
  (brick `--danger`); for a recurring **series** a confirm precedes the removal animation.
  **Complete** = leading-swipe (calm — olive/seal). Reorder (Groups) = standard `.onMove` lift +
  settle; the dragged row gets the `valueCut` depth (crisp stacked-paper offset) while lifted.
  UIKit calendar lists apply diffable snapshots `animatingDifferences: true` only for genuine data
  changes; mid-gesture and structural-window edits use `animatingDifferences: false` (see the
  WeekStrip/Month/Year landmine notes in code — never re-snapshot mid-gesture).
- **Reduce Motion:** rows **cross-fade** in/out (no slide), reorder settles without the lift
  parallax.
- **Haptic:** `.sensoryFeedback(.impact)` on a swipe commit (delete/complete); `.selection` on a
  reorder drop.
- **Status:** swipe actions + diffable snapshots **implemented**; `withAnimation(.snappy)` wrapping
  **specified** per screen.

### 3.8 Pull-to-refresh
- **Trigger:** `.refreshable` pull on Today and the Calendar Day body.
- **Default:** system pull-to-refresh; espresso (`--primary`)-tinted `ProgressView`; on release,
  re-fetch (`GET /tasks` + `/tasks/daily-counts`, or the visible day + week counts). Spinner is
  system indeterminate motion.
- **Reduce Motion:** system spinner already honors the flag — no custom work.
- **Haptic:** `.sensoryFeedback(.impact)` on the refresh release.
- **Status:** `.refreshable` **specified** per screen (Today/Day); haptic **specified**.

### 3.9 NotificationBanner in / out
- **Trigger:** a transient `AppNotification` posts (`.info`/`.success`/`.warning`/`.error`),
  expands, or dismisses.
- **Default:** **in/out** = `.move(edge: .top).combined(with: .opacity)` driven by `snappy`
  (`NotificationStore`/`NotificationHost`/`NotificationBanner`). The banner is **intentionally
  Liquid Glass** (frosted, warm-tinted) — chrome, distinct from letterpress cards. **Expand/collapse**
  (error/warning with `detail`): the `detail` block reveals and the chevron rotates **0↔180°**,
  `snappy`. **Dismiss:** trailing `xmark` **or swipe up** (DragGesture, threshold ~30pt upward).
  `.info`/`.success` auto-dismiss after **4s** (cancellable timer; any manual dismiss cancels it);
  `.warning`/`.error` are permanent.
- **Reduce Motion:** **fade only** (drop the slide); expand **cross-fades the detail block** with no
  chevron rotation; dismiss fades.
- **Haptic:** `.sensoryFeedback(.success)` when a success banner posts; `.warning` / `.error` notch
  for those severities; `.selection` on expand toggle.
- **Status:** **implemented** (`NotificationBanner` / `NotificationStore` / `NotificationHost`);
  haptics **specified**.

### 3.10 Onboarding screen-to-screen
- **Trigger:** advance through the **3 value/permission screens** (calendar → AI/Telegram →
  notifications), then Sign in with Apple, then into the tabs (landing on Today). Presented in a
  `fullScreenCover`.
- **Default:** horizontal swipe or "Continue" tap moves screen→screen with a standard `.page` pager
  slide (`pageSlide`, ~350ms, iOS default ease). **Paged dots** cross-fade their active fill
  (espresso `--primary`) to the new index with `press` (160ms). The AI/Telegram screen (screen 2)
  may demo a **wax-seal stamp** as the signature flourish: the inbound chat bubble is present, the
  `WaxSeal` stamps with `seal`, synchronized with a faint **8pt → 0 downward settle** of the parsed
  row (same spring). **Sign in with Apple** presents Apple's OS-owned system sheet (Face ID /
  confirm — not animated by us); on return the page enters a **signing-in** state (button → 0.5
  opacity, spinner + "Signing you in…" fade in, `press`). On `.authenticated` the `fullScreenCover`
  dismisses with the standard cover slide-down, revealing **Today**.
- **Reduce Motion:** keep the pager slide but **drop parallax** on the card / BrandMark; dots still
  cross-fade; the screen-2 seal demo → 200ms opacity cross-fade (no scale/rotation/settle); the
  system already cross-fades the cover.
- **Haptic:** `.sensoryFeedback(.selection)` on each page advance / dot change;
  `.sensoryFeedback(.success)` on the screen-2 seal demo and on a successful `POST /auth/apple`
  return. `.error` is **not** used (sign-in failure shows the alert only).
- **Status:** onboarding flow is **new** (per brief); motion **specified**.

### 3.11 Skeleton / loading reveals
- **Trigger:** first paint while a fetch resolves (`GET /tasks`, `/tasks/daily-counts`, group/list
  loads), and blocking actions.
- **Default — three tiers:**
  1. **Skeleton placeholders** (preferred for content-shaped surfaces, e.g. Today cards, lists):
     **sunken-paper** (`--surface-sunken`) placeholder bars in the real layout, revealed → real
     content with a **`snappy` opacity cross-fade** once data lands. **Greeting + avatar render
     immediately** (already cached) — **never a blank white flash.** A subtle shimmer is optional
     and **must honor Reduce Motion** (static placeholder, no sweep) — default to no shimmer.
  2. **`LoadingStateView`** (whole-surface first load): centered espresso `ProgressView` (.large) +
     optional `callout` label; warm-ink scrim is **not** used here (it is for blocking overlays).
  3. **`.loadingOverlay(isLoading:)`** (blocking action, e.g. save): **warm-ink scrim**
     `--text-primary @8%` (never black) + glass-backed spinner; show/hide via `snappy` + `.opacity`
     (`LoadingStateView.swift:108`).
- **Reduce Motion:** skeleton → real content is an **instant cross-fade** (no shimmer, no stagger);
  overlay show/hide is an instant cross-fade; spinners honor the flag automatically.
- **Haptic:** none on reveal (haptics fire on the *action*, not the load).
- **Status:** `LoadingStateView` + `.loadingOverlay` **implemented**; skeleton placeholders
  **specified** per screen.

---

## 4. Haptics map (`.sensoryFeedback`)

One table for the whole app. Use SwiftUI `.sensoryFeedback(_:trigger:)`; respect **Settings →
Sounds & Haptics** (the system already gates these). Never fire a haptic without a matching visible
change. Most are **specified-but-not-yet-wired** — only the components' own behaviors are
implemented.

| Action | Feedback | Trigger source |
|---|---|---|
| Tab switch (Today / Calendar / Settings) | `.selection` | `selectedTab` change |
| Open Search island | `.selection` | search presented |
| Scope change committed (year↔month↔day) | `.selection` + `.impact` on commit | `scopeKind` change |
| Day-page settle / week-tile tap / snap-to-day | `.selection` | `selectedDate` change |
| View-mode toggle (Timeline ⇄ List) | `.selection` | `mode` change |
| Jump-to-Today pill tapped | `.impact` (light) | pill tap |
| "+" Create sheet opened | `.impact` | sheet present |
| Sheet detent snap (`.medium` ↔ `.large`) | `.impact` (light/weak) | detent settle |
| Create-sheet chip / channel / Use·Dismiss select | `.selection` | chip selection |
| Quick-create parse low-confidence | `.warning` | parse result |
| `.decisive` CTA press (Save / Plan my day) | `.impact` | button press |
| **Task completion (seal stamp / ring)** | **`.success`** | completion toggle |
| **Save commit (`POST /tasks`)** | **`.success`** | save success |
| Sign in with Apple success (`POST /auth/apple`) | `.success` | auth success |
| Onboarding page advance / dot change | `.selection` | page index change |
| Onboarding screen-2 seal demo | `.success` | seal stamp |
| Swipe-action commit (complete / delete) | `.impact` | swipe commit |
| Reorder drop (Groups) | `.selection` | move commit |
| Pull-to-refresh release | `.impact` | refresh fired |
| Banner posts — success | `.success` | banner enqueue |
| Banner posts — warning / error | `.warning` / `.error` | banner enqueue |
| Banner expand toggle | `.selection` | expand state |
| Retry tap (error state) | `.impact` | retry commit |

**Discipline:** `.success` is reserved for the **two commit moments** (complete, save) and their
echoes (auth success, success banner). Sign-in **failure** uses the alert only — **no** `.error`
haptic. Do not stack haptics: one action → one feedback.

---

## 5. Per-screen motion index (where each animation appears)

| Screen / surface | Animations in play (§) |
|---|---|
| **Onboarding (`02`)** | 3.10 (screen-to-screen), 3.4 (screen-2 seal demo), 3.11 (signing-in) |
| **Today / Dashboard (`03`)** | 3.1 (tab), 3.3 ("+"), 3.5 (inline complete), 3.7 (list), 3.8 (pull-to-refresh), 3.9 (banner), 3.11 (skeleton), 3.2 (deep-link to Calendar zoom) |
| **Calendar — Day (`04`)** | 3.2 (paging / pill / jump-to-today), 3.5 (complete: seal + ring), 3.6 (now-line), 3.7 (swipe), 3.8 (refresh), view-mode toggle (`snappy`) |
| **Calendar — Month (`05`)** | 3.2 (zoom in/out, tap-cell jump, jump-to-today), diffable density repaint |
| **Calendar — Year (`06`)** | 3.2 (zoom to month, heat-map repaint) |
| **Zoom & affordances (`07`)** | 3.2 in full (this is its canonical spec) |
| **Create event/task (`08`)** | 3.3 (present/detent), 3.4 (save seal + locked settle), event⇄task pivot (`snappy`), chip select (`press`), quick-create parse (`snappy`) |
| **Event / Occurrence detail (`09`)** | 3.5 (complete), nav push/cross-fade, 3.9 (banner) |
| **Edit series (`10`)** | recurrence row reveals (`snappy`), 3.7 (field-driven), save → 3.4 |
| **Search (`11`)** | island present (3.1 haptic), 3.7 (results), 3.11 (skeleton) |
| **Settings home (`12`)** | nav pushes, 3.1 (tab), row press (`press`) |
| **Groups list (`13`)** | 3.7 (insert/delete/**reorder**), 3.11 (skeleton) |
| **Group edit (`14`)** | swatch/icon select (`press`), save → 3.9 banner |
| **Telegram connect (`15`)** | state cross-fades (`snappy`), connect success → 3.9 + `.success` |
| **Notifications & report (`16`)** | toggle (`snappy`), reminder picker rows (3.7), report-time picker |
| **AI persona (`17`)** | preset-chip select (`press`), save → 3.9 |
| **Account / profile (`18`)** | row press, sign-out → cover/cross-fade back to onboarding |
| **States kit (`19`)** | 3.9 (banner in/out/expand), 3.11 (loading/overlay), retry press |

---

## 6. Implementation checklist (per animated surface)

1. Reference a **named token from §1** — never a one-off curve.
2. Gate every scale/translate/spring on `@Environment(\.accessibilityReduceMotion)` and provide the
   **cross-fade fallback** (§2). The `WaxSeal` gate is mandatory and **not** provided by the
   component.
3. Attach the **haptic from §4** via `.sensoryFeedback(_:trigger:)`, tied to the same state value
   that drives the animation.
4. For the **calendar UIKit surface**, never apply a fresh diffable snapshot mid-gesture; use
   `reconfigureItems` + `animatingDifferences: false` for in-place repaints (real values in code).
5. The **seal is rationed**: at most **one** stamping seal per screen (the single commit). The
   now-line clay and the Today/now marker are structural, not seals — they do not animate as commits.
6. Keep **one seal motion** app-wide (`.spring(0.42, 0.62)`); do not add a parallel literal
   cubic-bezier even though the brief names `cubic-bezier(0.34,1.3,0.64,1)` — the spring is its
   canonical expression (§3.4 note).
7. Verify composited **text-over-glass ≥ 4.5:1** on animated chrome (tab bar, banner, island, Today
   pill) — motion must not be the excuse for a contrast regression.
