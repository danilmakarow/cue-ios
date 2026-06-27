# CUE — Claude Design Prompt Pack (Kraft & Ink)

This folder is a **per-screen Claude Design prompt pack** for the CUE iOS app. CUE is an
AI-assisted calendar/planner for iOS 26, paired with a Telegram AI assistant; its visual system is
**"Kraft & Ink"** — espresso ink on a clean white page, one rationed terracotta wax-seal accent,
letterpress depth, Fraunces + Public Sans + JetBrains Mono. The system is already implemented in
code (`cue-ios/cue/DesignSystem/`).

Each `NN-<page>.md` file is a self-contained prompt you feed to **Claude Design** to render one
screen as a real HTML/CSS artifact that mirrors the native iOS screen. Two files are the backbone —
[`00-MASTER-BRIEF.md`](00-MASTER-BRIEF.md) (consolidated brief + information architecture) and
[`01-DESIGN-SYSTEM.md`](01-DESIGN-SYSTEM.md) (exact tokens + paste-ready `DESIGN.md` block) — and
[`20-ANIMATIONS.md`](20-ANIMATIONS.md) is the consolidated motion spec. Everything else is one
screen per file.

---

## Product decisions (apply consistently across every screen)

These resolve the open questions in the master brief. Treat them as fixed for v1 — every screen
prompt must honor them.

- **Navigation — 3 tabs + a separated "+".** A warm Liquid Glass tab bar with exactly three tabs:
  **Today / Calendar / Settings**. The **"+" is a SEPARATED action item** (not a tab) that opens the
  Create sheet over whatever tab is showing. **Search is NOT a tab** — it is a nav-bar icon (glass
  island) reachable from **Today** and **Calendar**. The **default landing tab is Today.**
- **Onboarding — a 3-screen value + permission flow** before the tabs: (1) calendar value →
  (2) AI / Telegram assistant → (3) notifications opt-in, then **Sign in with Apple**, then drop into
  the tabs landing on **Today**. Presented as a `fullScreenCover` (immersive, pre-tabs).
- **AI ritual — both surfaces, one toggle.** The morning brief / evening shutdown appears **both** as
  an in-app card on **Today** **and** as an optional **Telegram** message. A **single toggle** controls
  both, and it lives in **Notifications settings** (file 16).
- **Reminders — in v1 design scope.** Per-task reminders **are** designed for v1: include reminder UI
  in the **Create sheet** (file 08) and the **Notifications screen** (file 16). The backend controller
  is a follow-up — the `NotificationRule` schema already exists, the client endpoint does not yet — so
  design the UI now and flag the wiring as pending.

### Visual base (non-negotiable)

Use **Kraft & Ink** with the **EXACT tokens from [`01-DESIGN-SYSTEM.md`](01-DESIGN-SYSTEM.md)**.
**Light-only.**

- **Espresso `#5A3A24`** (`--primary`) carries structure — key actions, the structural tint,
  selected chips/toggles.
- **Clay `#BE4A28`** (`--secondary`) is rationed **FILL-ONLY**, reserved for the single wax-seal
  "make it stick" moment (one decisive CTA / the wax seal / the TODAY-now marker) **per screen**.
- **Clay-as-text only `#A53D22`** (`--accent-text`) — never the fill clay as text.
- **Fonts:** **Fraunces** (display, titles ≥17pt), **Public Sans** (body — explicitly NOT Inter/SF
  Pro), **JetBrains Mono** (receipt voice: dates, counts, IDs).
- **Depth:** letterpress (1px `--border` + a hard value-cut value-step, blur radius 0) — never a soft
  drop shadow. **Cut-paper radii** (4–12px), never 16–20px squircle bubbles.

---

## Workflow — DESIGN-SYSTEM-FIRST

Claude Design holds a **durable design system** and renders against it. Seed the system **before**
any screen so the agent self-corrects on uncovered cases instead of drifting to generic defaults.

1. **Seed the system first.** Upload or paste [`01-DESIGN-SYSTEM.md`](01-DESIGN-SYSTEM.md) — or, at
   minimum, the **ready-to-paste `DESIGN.md` block** in its **§0** — as the very first thing.
   Let Claude Design build the *system* before it builds any screen. Belt-and-suspenders: also upload
   one rendered Kraft & Ink screenshot from the live app so it learns the brand "in the wild," then
   toggle the system **Published** so every screen inherits it.
2. **Then feed each screen file one at a time.** Generate **one screen per prompt**, in the
   recommended order below. Each `NN-<page>.md` already carries the frame contract, layout, named
   tokens/components, real backend data, and the states to render.
3. **Refine with comments, not regenerations.** Regen drifts toward the default AI aesthetic; inline
   comments hold the system in place.
4. **Then "apply across the full flow"** for multi-screen consistency once the individual screens
   look right.

---

## Recommended generation order

1. **`01-DESIGN-SYSTEM.md` first** — seed + publish the system (this is the gate; do not skip).
2. **`19-states-kit.md`** — the empty / loading / error vocabulary every other screen reuses.
3. **`03-today-dashboard.md`** — the default landing tab and the densest composition of components.
4. **`04` → `05` → `06`** — Calendar Day, Month, Year (the core surface, day-out to year-out).
5. **`07-calendar-zoom-affordances.md`** — the cross-cutting zoom/navigation behavior tying 04–06.
6. **`08-create-event-task.md`** — the "+" Create sheet (includes reminder UI).
7. **`09-event-detail.md` → `10-event-edit.md`** — detail then edit-series.
8. **`11-search.md`** — the nav-bar glass island.
9. **`12-settings-home.md`**, then its drill-downs **`13` → `14` → `15` → `16` → `17` → `18`**.
10. **`02-onboarding-auth.md`** — the pre-tabs flow (generate late; it reuses BrandMark + buttons
    already validated elsewhere).
11. **`20-ANIMATIONS.md`** — apply the motion/transition pass across the finished flow last.

---

## File index

| # | File | Page | Nav location |
|---|---|---|---|
| 00 | [`00-MASTER-BRIEF.md`](00-MASTER-BRIEF.md) | Full consolidated brief & IA | backbone (read first for context) |
| 01 | [`01-DESIGN-SYSTEM.md`](01-DESIGN-SYSTEM.md) | Exact Kraft & Ink tokens + paste-ready DESIGN block | backbone (seed the system first) |
| 02 | [`02-onboarding-auth.md`](02-onboarding-auth.md) | Onboarding & Sign-in | `fullScreenCover` (before tabs) |
| 03 | [`03-today-dashboard.md`](03-today-dashboard.md) | Today (Dashboard home) | tab (DEFAULT landing tab) |
| 04 | [`04-calendar-day.md`](04-calendar-day.md) | Calendar — Day | Calendar tab, Day scope |
| 05 | [`05-calendar-month.md`](05-calendar-month.md) | Calendar — Month | Calendar tab, Month scope |
| 06 | [`06-calendar-year.md`](06-calendar-year.md) | Calendar — Year | Calendar tab, Year scope |
| 07 | [`07-calendar-zoom-affordances.md`](07-calendar-zoom-affordances.md) | Scope zoom & navigation (cross-cutting) | Calendar tab (behavior + affordance UI) |
| 08 | [`08-create-event-task.md`](08-create-event-task.md) | Create event/task (merged) | sheet (medium/large detents), opened by "+" |
| 09 | [`09-event-detail.md`](09-event-detail.md) | Event / Occurrence detail | sheet |
| 10 | [`10-event-edit.md`](10-event-edit.md) | Edit series | sheet |
| 11 | [`11-search.md`](11-search.md) | Search | nav-bar glass island (NOT a tab) |
| 12 | [`12-settings-home.md`](12-settings-home.md) | Settings home | tab |
| 13 | [`13-groups-list.md`](13-groups-list.md) | Task groups | stack-push (from Settings) |
| 14 | [`14-group-edit.md`](14-group-edit.md) | Group create/edit | sheet |
| 15 | [`15-telegram-connect.md`](15-telegram-connect.md) | Connect Telegram | stack-push (from Settings) + deep-link sheet |
| 16 | [`16-notifications-report-settings.md`](16-notifications-report-settings.md) | Notifications & daily report | stack-push (from Settings) |
| 17 | [`17-ai-assistant-persona.md`](17-ai-assistant-persona.md) | AI assistant persona | stack-push (from Settings) |
| 18 | [`18-account-profile.md`](18-account-profile.md) | Account & profile | stack-push (from Settings) |
| 19 | [`19-states-kit.md`](19-states-kit.md) | Empty / Loading / Error kit | cross-cutting kit |
| 20 | [`20-ANIMATIONS.md`](20-ANIMATIONS.md) | Consolidated motion & transitions spec | cross-cutting spec |

---

## Anti-AI-slop guardrails (keep in every prompt)

A clean render is ~80% the published `DESIGN.md` and ~20% prompt wording. Carry these in every
screen prompt so the output never drifts to the generic AI look:

- **Tokens by NAME, never raw hex.** Reference `--surface`, `--primary`, `--accent-text`, Fraunces —
  not `#FAF6EF` — so the palette can't drift.
- **Ration the clay.** The wax-seal accent (`--secondary`) appears **at most once per screen**, on the
  single decisive commit moment. **Selected chips/toggles fill espresso `--primary`, not clay**, so
  they never compete with the seal.
- **Real content, no lorem.** Real task titles, real dates, real EN/UK strings, real entity field
  shapes — never "Task 1" / "Item 1" / lorem.
- **Fraunces is the editorial voice** for titles ≥17pt only — never for dense UI labels or body.
  Body is **Public Sans**; dates/counts/IDs are **JetBrains Mono**. **Never let Inter / SF Pro / Helvetica
  be the display face.**
- **Letterpress depth only** (1px `--border` + hard value-cut, blur radius 0). **NO soft drop shadows,
  NO gradients, NO glassmorphism on content cards, NO blue accents, NO pure `#FFFFFF` surfaces on
  white, NO pure `#000000`.**
- **Density as one-accent intensity, not a rainbow of dots.** Busyness = shades of one accent; status
  on a separate (shape) channel; olive = done, brass = pending, espresso = structure.
- **Crisp cut-paper corners** (4–12px), never 16–20px squircle bubbles. Chips are 4px rubber-stamp
  rectangles, never pills, never pill-with-a-dot.
- **Native iOS, NOT responsive.** Single fixed iPhone frame **393×852pt @3x**, iOS status bar
  (Dynamic Island reserved), ~59pt top safe area, 34pt home-indicator gutter, 16pt side margins, tap
  targets ≥44pt. Re-tint Liquid Glass **warm** toward kraft/clay — never Apple's cool blue-grey.
- **Banned adjectives.** Don't say "modern / clean / sleek / beautiful" in prompts — they summon the
  generic AI aesthetic.
- **Always render the states the screen needs** — empty, loading (warm-scrim spinner), error (with
  on-brand retry, not the system button).

---

## Screen status — exists in code vs new

The Kraft & Ink **design system itself is fully implemented**; screen *coverage* varies. From the
master-brief IA:

**Already exist in code (the prompt re-skins / documents the implemented screen):**
- `04` Calendar — Day, `05` Month, `06` Year, and `07` the zoom/affordance behavior (one zoomable
  UIKit surface).
- `08` Create event/task (New Event), `09` Event/Occurrence detail, `10` Edit series + recurrence
  editor.
- `12` Settings home, `13` Groups list, `14` Group edit.
- `15` Connect Telegram.
- `02` Auth (Sign in with Apple) exists — but the **3-screen onboarding flow in front of it is new**.

**New or partial (no real screen yet — design from the brief):**
- `03` Today (currently a ~25-line `ContentUnavailableView` stub — all backend data already exists).
- `11` Search (new; nav-bar glass island).
- `16` Notifications & daily report (new — daily-report endpoint is wired; per-task reminder UI is in
  scope but its client controller is a follow-up).
- `17` AI assistant persona (new — backend is ready, the app doesn't call it yet; a real gap to close).
- `18` Account & profile (new).
- `19` Empty / Loading / Error kit (partial — primitives exist; `ErrorStateView` retry uses the system
  button, a flagged DS gap to spec on-brand).

> Note: files `15`, `16`, and `20` are indexed here per the pack plan; generate any not yet present
> on disk from this brief before feeding them to Claude Design.
