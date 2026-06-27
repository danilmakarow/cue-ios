# CUE — Master Design Brief (Kraft & Ink)

**Project:** CUE — an AI-assisted calendar/planner for iOS 26, paired with a Telegram AI assistant.
**Visual system:** "Kraft & Ink" — espresso ink on a white page, one rationed terracotta wax-seal
accent, letterpress depth, Fraunces + Public Sans + JetBrains Mono. Already implemented; see
[`01-DESIGN-SYSTEM.md`](01-DESIGN-SYSTEM.md) for exact tokens.
**This file is the design backbone.** It consolidates six research streams into a final information
architecture, a navigation map, per-page real-data mapping, the Claude Design prompting strategy,
the analogous-app patterns to adopt, and the iOS platform rules. Each per-screen prompt file
(`02-…` onward) is generated against this brief + the design system.

---

## 0. How to use this brief with Claude Design

1. **Seed the system once.** Create/publish a Claude Design system for CUE from the ready-to-paste
   block in [`01-DESIGN-SYSTEM.md` §0](01-DESIGN-SYSTEM.md). Belt-and-suspenders: also upload a
   rendered Kraft & Ink screenshot from the live app so it learns the brand "in the wild," then
   toggle **Published** so every screen inherits it.
2. **Generate one screen at a time.** Each `NN-<page>.md` carries: the page's one-sentence job, the
   iPhone frame contract, the layout top→bottom, named components + named tokens, **real backend
   data** (real field names + plausible real strings), the states to render, and brand guardrails.
3. **Refine with comments, not regenerations.** Regen drifts toward generic defaults; inline
   comments hold the system.
4. **Then "apply across the full flow"** for multi-screen consistency.

---

## 1. Research synthesis (the six streams, distilled)

**A. iOS design system (exact tokens).** Implemented Kraft & Ink lives in
`cue-ios/cue/DesignSystem/`. Light-only, white canvas, espresso `#5A3A24` structural tint, clay
`#BE4A28` rationed accent (FILL only; clay-as-text uses `#A53D22`). Letterpress depth (border +
hard value-cut, blur 0) — **no soft shadows, no gradients, no glassmorphism on content**. Three
bundled fonts: **Fraunces** (display ≥17pt), **Public Sans** (body — NOT Inter/SF Pro),
**JetBrains Mono** (receipt voice: dates/counts/IDs). The **wax seal** is the brand gesture,
reserved for two commit moments (complete task, save event). Stale spec docs claimed a tan canvas
and SF Pro — **code wins**.

**B. iOS screens & navigation (what already exists).** Native iOS 26 `TabView` (Liquid Glass) with
**Calendar / Dashboard / Settings** + a trailing "+" action item that presents the New Event sheet.
The calendar is a **single zoomable UIKit surface** (year↔month↔day via interactive pinch + tap,
not three screens), with a day pager, a heavily-engineered week strip, a timeline⇄to-do toggle,
progressive Jump-to-Today, and wax-seal completion on agenda cards. **Built:** Auth (Sign in with
Apple), CalendarHost, day/month/year scopes + zoom, New Event, Task Detail, Task Edit, Recurrence
editor, Groups list + edit, Settings, Telegram connect. **Stub/missing:** Dashboard (25-line
`ContentUnavailableView`), onboarding (absent), search (absent), report/notification settings
(absent in app though BE supports report settings), Siri/widgets (planned).

**C. Backend data model & API (what data exists).** Calendar-centric:
`User → Calendar → {Task, TaskGroup}`. **Task** is the unified event+todo primitive — a series
anchor (one row even for recurrence), with `title`, `notes`, `startAt`/`endAt`, `isAllDay`,
`requiresCompletion`, `completedAt` (a **timestamp**, enabling reporting), `groupId`,
`recurrenceRuleId`, `timezone`. Occurrences are expanded on read into **`OccurrenceDTO`**
(`occurrenceStart/End`, effective `title`, per-instance `completedAt`, `isRecurring`,
`isException`). Color lives on **`TaskGroup.color`** / `Calendar.color` (Task has none — derived).
Key live endpoints: `GET /tasks` (occurrences in range — the calendar feed),
`GET /tasks/daily-counts` (per-day counts — the "load" metric), `GET /tasks/changes` (delta sync),
`PATCH /tasks/:id/completion`, `POST /tasks/:id/skip`, full task/group CRUD, `GET /auth/me`,
report settings (`GET/PATCH /users/me/report-settings` → `{ enabled, reportTimeLocal }`), persona
settings (`GET/PATCH /users/me/persona-settings` → `{ promptText, source, presetName }`), and
Telegram link (`GET/POST/DELETE /assistant/link` → `{ linked, telegramUsername, linkedAt }`).
**Dashboard has all the data it needs already** — no new BE work for "next task", agenda, or
day-load.

**D. Claude Design prompt playbook.** Claude Design holds a durable design system and renders real
HTML/CSS artifacts. The anti-slop lever is 80% a published `DESIGN.md` (token + rule + rationale in
one file) and 20% prompt wording. A strong single-screen prompt = goal · audience · frame · layout ·
named components · named tokens · **real content** · explicit states. Avoid "modern/clean/beautiful"
(summons the default AI look). Supply iOS frame numbers (393×852pt @3x) and demand "NOT responsive."
Re-map Liquid Glass to a **warm** tint, not Apple's cool blue.

**E. Analogous app patterns.** DayTicker home (Fantastical), unified events+tasks list, "This
Evening" segmentation (Things), day-load/free-gap signal (Amie), morning brief + evening shutdown
ritual (Sunsama — keep optional, Akiflow's lesson). Day: timeline⇄list toggle, proportional blocks,
now-line, all-day band, compress-empty-hours. Month: Apple's **Compact/Stacked/Details** density
modes; avoid the monochrome single dot. Year + month as **one-accent heat-map** (Timepage) — a
perfect marriage with the single-palette constraint. Zoom: tap=in, slide/pull=out, cells are jump
targets, snap-to-day feedback, **scope-preserving Today**. Quick-create: live natural-language
parse with sigils + confirm-before-commit. Event detail leads with the single most-likely action.
Groups: color = membership consistently everywhere; density = shades of one accent; status on a
**separate channel** (shape) from color. Settings: Telegram is the differentiated ingress — make it
the headline integration, don't bury it.

**F. iOS HIG / platform.** Floating Liquid Glass tab bar (3–5 tabs, scroll-to-shrink). Scope
hierarchy via the first-class **zoom navigation transition** (`@Namespace` +
`.matchedTransitionSource` + `.navigationTransition(.zoom)`), with an explicit reverse/rubber-band
path. Create/detail = **sheet with `.presentationDetents([.medium, .large])`**, opened at medium,
keyboard up; detail-over-calendar adds `presentationBackgroundInteraction`. `fullScreenCover` only
for immersive flows (onboarding, export). Gestures: horizontal day paging (inset from the left edge
to protect back-swipe), pinch as a **secondary** accelerator with a tap fallback, `.refreshable`,
`contextMenu`, `.swipeActions` (leading=complete, trailing-full=delete). Dynamic Type everywhere;
respect safe areas + the 34pt home-indicator gutter; put the primary CTA in the **bottom thumb
zone**. Haptics via `.sensoryFeedback` (selection on scope flicks, success on save). Honor Reduce
Motion (zoom→cross-fade) and Reduce Transparency (glass→solid warm fill). **Contrast is hard mode**
on a warm light-only palette — test the *composited* text-over-glass result ≥4.5:1.

---

## 2. Final information architecture (decision + rationale)

**Decision:** keep the founder's four pillars, but (a) split his single "Calendar" item into the
real screens it already is, (b) promote the Dashboard to a genuine "Today" home (it's currently a
stub but all data exists), (c) **add the missing connective tissue** real planners ship —
onboarding, search, group detail/edit (exists, make it first-class), report/AI-assistant settings,
and the empty/loading/error state set — and (d) make every gesture-only capability have a visible
fallback. Nothing is cut; "Create event" and "Create task" **merge into one sheet** (they already
are one `Task` primitive on the backend — a `requiresCompletion` toggle is the only difference).

### Navigation model
- **Root:** native iOS 26 `TabView`, floating Liquid Glass capsule, scroll-to-shrink, warm-tinted.
  **4 tabs + 1 action item:**
  1. **Today** (Dashboard) — `chart.bar.fill`→ reconsider as `house`/`sun.max`; the agenda home.
  2. **Calendar** (default for power users; Today is the friendlier landing) — `calendar`.
  3. **Inbox/Search** — `magnifying.glass` *(new; or fold search into a nav-bar island per HIG)*.
  4. **Settings** — `gearshape`.
  5. **"+" New** — action item (`.search` role separated capsule); presents the Create sheet,
     keeps the current tab. (Matches the implemented pattern.)
- **Stacks:** one `NavigationStack` per tab. Calendar's stack lives inside `CalendarHostView`.
- **Scope zoom** (year→month→day) is **in-place within the Calendar tab** via pinch + tap + the
  `.navigationTransition(.zoom)` machinery — not separate routes.
- **Sheets (medium/large detents):** Create event/task; Event/Occurrence detail; Group edit;
  Telegram connect (also reachable via deep link); Report-settings & Persona-settings editors.
- **Pushes:** Occurrence detail → (Edit sheet); Settings → Groups, Group detail/edit, Telegram,
  Notifications/Report, AI Assistant persona, Account/Profile.
- **Full-screen cover:** Onboarding only.
- **Deep link:** `cue://telegram/link?code=` → Telegram connect sheet (code prefilled).
- **Global overlay:** notification banners (not a route).

### Deltas from the founder's proposal
- **Dashboard** → reframed as **"Today" home** with DayTicker ribbon, next-task card, free-gap +
  day-load (`/tasks/daily-counts`), and the optional morning-brief/evening-shutdown hook. (was a
  stub; data already exists.)
- **Calendar** (one item) → **split into Day / Month / Year** screen specs (they're one zoomable
  surface in code, but each scope needs its own prompt) **+** the zoom/affordance behaviors as a
  cross-cutting spec. His "toggle, jump-to-today, swipe, event detail" all map onto these.
- **Create event/task** → **single merged Create sheet** (event vs task = `requiresCompletion`
  toggle), with **live NL quick-create** as the fast path (CUE's AI is the parser; confirm before
  commit).
- **Settings** → kept, but **expanded** into Account/Profile, Groups (list), Group detail/edit,
  Telegram connect, Notifications/Daily-report settings, and **AI Assistant persona** (BE supports
  it; app doesn't call it yet — a real gap).
- **Added (new):** Onboarding/Auth, Search, Notification/Report settings, AI Assistant persona,
  the Empty/Loading/Error state kit. **Promoted:** Group detail/edit and Telegram connect to
  first-class specs.
- **Merged/cut:** "Create event" + "Create task" → one sheet. Nothing removed outright.

---

## 3. Page list (per-page purpose, nav location, key REAL data)

Page files are numbered from `02`. Status: **exists / partial / new**. Priority: **core / secondary**.

| # | File | Page | Nav location | Status | Pri | Purpose & key real data (entity fields) |
|---|---|---|---|---|---|---|
| 02 | `02-onboarding-auth.md` | Onboarding & Sign-in | full-screen-modal → onboarding; AuthView exists | partial→new | core | BrandMark + value props + **Sign in with Apple** (`POST /auth/apple {identityToken, fullName?, avatarBase64?, timezone?}`). New: a 3–4 screen onboarding flow (calendar value, AI/Telegram, notifications opt-in) before tabs. |
| 03 | `03-today-dashboard.md` | Today (Dashboard home) | tab | partial (stub) | core | Greeting w/ `User.displayName`; **next task** = first `OccurrenceDTO` where `occurrenceStart >= now` (title, occurrenceStart, group color); **free gap** until it; **today's load** from `GET /tasks/daily-counts`; upcoming list (events+tasks unified); "This Evening" section; optional morning-brief / evening-shutdown card (uses `completedAt` for "what you finished"). |
| 04 | `04-calendar-day.md` | Calendar — Day | Calendar tab (day scope) | exists | core | Day pager (±90d); **timeline⇄to-do toggle** (`ViewModeSwitcher`); week strip w/ per-day count badge + today dot; all-day band; `OccurrenceDTO` blocks sized by `occurrenceStart`→`occurrenceEnd`, color from `TaskGroup.color`; wax-seal completion (`PATCH /tasks/:id/completion {isCompleted, occurrenceStart}`); now-line; empty state. |
| 05 | `05-calendar-month.md` | Calendar — Month | Calendar tab (month scope) | exists | core | Infinite vertical month sections; 7-col grid; per-day event titles + **density** (Apple Compact/Stacked/Details modes) from `GET /tasks/daily-counts` + `GET /tasks`; cap to 2–3 titles + "+N more"; tap day → zoom to Day; progressive Jump-to-Today pill. Density as one-accent intensity, not a lone dot. |
| 06 | `06-calendar-year.md` | Calendar — Year | Calendar tab (year scope) | exists | secondary | Infinite year sections; large Fraunces year title; 3×4 mini-month grid; **heat-map** busyness as a clay/espresso intensity ramp from `daily-counts`; tap mini-month → zoom to Month. Validate "1 event" tint vs "0 events" empty in light-only palette; subtle legend. |
| 07 | `07-calendar-zoom-affordances.md` | Scope zoom & navigation (cross-cutting) | Calendar tab behavior | exists | core | The zoom model spec: tap=in / pinch+pull=out; `.navigationTransition(.zoom)` per level w/ reverse path; **scope-preserving Today** control (lands on today *at current zoom*); snap-to-day feedback; `.sensoryFeedback(.selection)` on scope flicks; Reduce-Motion → cross-fade. Visible fallback for every gesture. |
| 08 | `08-create-event-task.md` | Create event/task (merged) | sheet (medium/large) | exists | core | One sheet: `title`, `notes`, `isAllDay` toggle, time (quick duration chips + dual DatePicker), `requiresCompletion` (event vs task), recurrence (`RecurrenceSection`), group picker (`GET /task-groups`), color (from group). **Live NL quick-create** first field → parsed chips, confirm before commit. Save → animated **WaxSeal** (`POST /tasks`). |
| 09 | `09-event-detail.md` | Event / Occurrence detail | sheet (medium, expandable) + push | exists | core | `OccurrenceDTO` → `title`, time range (`occurrenceStart`/`occurrenceEnd`), `notes`, group color, recurrence summary (`GET /tasks/:id` → embedded `recurrence`), `isRecurring` badge. **Lead with the most-likely action** (mark done / edit / navigate). Actions: complete, **Edit** (sheet), **Skip** this occurrence (`POST /tasks/:id/skip {occurrenceStart}`), **Delete** series. Graceful degrade for AI context (travel/weather). |
| 10 | `10-event-edit.md` | Edit series | sheet | exists | core | `TaskEditScreen`: `title`, `notes`, `isAllDay`, `startAt`/`endAt`, `requiresCompletion`, recurrence with `FieldUpdate` tri-state (unchanged/clear/set). `PATCH /tasks/:id`. Recurrence editor (off/daily/weekly/monthly/yearly, interval, weekday grid, end type never/on-date/after-N). |
| 11 | `11-search.md` | Search | tab or nav-bar island | new | secondary | Query across `Task.title`/`notes`; results as unified occurrence rows (date + group color + recurring badge); filter by `TaskGroup`; recent/empty state. (BE: filter `GET /tasks`; a dedicated search endpoint is a flagged gap — see open questions.) |
| 12 | `12-settings-home.md` | Settings home | tab | exists | core | `Form`: profile row (`CueAvatar` from `User.avatarBase64`, `displayName`, `email`), appearance picker (light pinned), language picker, **Groups** link, **Telegram** link (live status), **Notifications/Report** link, **AI Assistant** link, **Account** link, Sign Out. |
| 13 | `13-groups-list.md` | Task groups | Settings → push | exists | core | `@Query EventTaskGroup` from `GET /task-groups`: rows = `name` + recurrence badge + color/icon tile (`color`, `icon` SF Symbol, `sortOrder`); tap → edit; swipe-to-delete (`DELETE /task-groups/:id` ungroups, doesn't delete tasks); `+` → create sheet; empty state. |
| 14 | `14-group-edit.md` | Group create/edit | sheet | exists | secondary | `name`, 6 color swatches (`color`), 12 SF-symbol icons (`icon`), default recurrence (`defaultRecurrenceRuleId` via `RecurrenceSection`). `POST`/`PATCH /task-groups`. |
| 15 | `15-telegram-connect.md` | Connect Telegram | Settings → push, or deep-link sheet | exists | core | 5 states off `TelegramLinkStore.status`: loading / not-connected (code field + paste + Connect, `POST /assistant/link {code}`) / connected (`@telegramUsername` + `linkedAt` + Disconnect `DELETE /assistant/link`) / failed (retry). Headline integration — make it shine. |
| 16 | `16-notifications-report-settings.md` | Notifications & daily report | Settings → push | new | secondary | **Daily report:** `enabled` toggle + `reportTimeLocal` (HH:mm, in `User.timezone`) via `GET/PATCH /users/me/report-settings`. Reminders concept (per-task/group `NotificationRule.offsetMinutes`, `channel` PUSH/TELEGRAM) — **schema-only, no client endpoint yet** (flag). |
| 17 | `17-ai-assistant-persona.md` | AI assistant persona | Settings → push | new | secondary | `GET/PATCH /users/me/persona-settings` → `promptText` (1–2000 chars), `source` (preset/custom), `presetName` (seeded "Jarvis"). Preset chips + editable prompt. App doesn't call this yet — a real gap to close. |
| 18 | `18-account-profile.md` | Account & profile | Settings → push | new | secondary | `User`: `displayName`, `email`, `avatarBase64`, `timezone`. Edit display name/timezone; show linked Apple identity; **Sign Out** (clears auth + telegram); delete-account placeholder. |
| 19 | `19-states-kit.md` | Empty / Loading / Error kit | cross-cutting | partial | core | The reusable state set: empty (per surface — "No tasks today", "No groups yet"), loading (`LoadingStateView` warm scrim), error (`ErrorStateView` / `.networkFailure(retry:)`), inline pagination row, notification banners (4 severities). **FLAG:** ErrorStateView retry uses system button, not `CueButton` — spec the on-brand version. |

**Tab-bar reconciliation:** the implemented bar is Calendar/Dashboard/Settings + "+". This IA adds
**Today** as the friendly landing and **Search** — exceeding 5 slots if all are tabs. Recommended:
**Today · Calendar · Search · Settings + "+"** (4 tabs + action), with Dashboard *becoming* Today.
If 4 tabs feels heavy, fold Search into a nav-bar glass island (HIG pattern) and keep 3 tabs +
"+". Resolve with the founder (open question Q1).

---

## 4. Per-page real-data mapping (entity field cheat-sheet)

Use these EXACT field names in prompts so the rendered UI shows real data shapes, not lorem.

- **Greeting / profile:** `User.displayName` ("Jane Appleseed"), `User.email`, `User.avatarBase64`
  (base64, no data-URL prefix), `User.timezone` ("Europe/Berlin").
- **Calendar feed (the heart):** `OccurrenceDTO { taskId, calendarId, groupId, originalStart,
  occurrenceStart, occurrenceEnd, title, notes, isAllDay, timezone, requiresCompletion, completedAt,
  isRecurring, isException }` from `GET /tasks?calendarId&from&to&includeCompleted&includeTodos`.
- **Day-load / busyness metric:** `GET /tasks/daily-counts` → `{ counts: { "2026-06-24": 5, … } }`
  (zero-count days omitted) — drives month dots, year heat-map, dashboard load.
- **Next task / agenda:** `GET /tasks` with `from=now`; first occurrence by `occurrenceStart`.
- **Completion / "what I did":** `Task.completedAt` / `OccurrenceDTO.completedAt` — a **timestamp**,
  not a bool; powers reports + done state. Toggle via `PATCH /tasks/:id/completion {isCompleted,
  occurrenceStart?}`.
- **Color & icon (never on Task):** `TaskGroup.color` (hex/token e.g. `#E27921`), `TaskGroup.icon`
  (SF Symbol e.g. `cart.fill`), `TaskGroup.sortOrder`; fallback `Calendar.color` / `Calendar.icon`.
- **Recurrence editor:** `RecurrenceRule { frequency DAILY/WEEKLY/MONTHLY/YEARLY, interval,
  byWeekday (ISO 0=Mon…6=Sun), byMonthDay, byMonth, endType NEVER/UNTIL_DATE/COUNT, endDate,
  count }`; inherited group default via `defaultRecurrenceRuleId`.
- **Per-occurrence identity:** `(taskId, originalStart)`. Skip = `POST /tasks/:id/skip
  {occurrenceStart}`. Override fields: `overrideStartAt/EndAt`, `overrideTitle`, per-occ `completedAt`.
- **Telegram:** `TelegramLinkStatusDto { linked, telegramUsername ("jane_doe"), linkedAt }`.
- **Daily report:** `UserReportSettings { enabled, reportTimeLocal ("08:00") }` (in `User.timezone`).
- **AI persona:** `{ promptText (1–2000), source 'preset'|'custom', presetName ("Jarvis") }`.

---

## 5. Analogous-app patterns to adopt (mapped to CUE pages)

| Pattern (source) | CUE page | Note |
|---|---|---|
| DayTicker ribbon over unified events+tasks list (Fantastical) | 03 Today, 04 Day | already have the day-strip foundation |
| "This Evening" later-section (Things 3) | 03 Today | reduces day overwhelm |
| Day-load / free-gap signal (Amie) | 03 Today | from `daily-counts` + agenda gaps |
| Morning brief + evening shutdown ritual (Sunsama) | 03 Today + Telegram | **keep optional** (Akiflow lesson) |
| Timeline⇄list toggle, proportional blocks, compress-empty-hours (Amie/Structured) | 04 Day | `ViewModeSwitcher` exists |
| Now-line + inline subtask complete (Structured) | 04 Day | wax-seal complete in place |
| Compact/Stacked/Details density modes (Apple) | 05 Month | avoid the lone monochrome dot |
| One-accent heat-map for year **and** month (Timepage) | 05 Month, 06 Year | marries the single-palette constraint |
| Tap=in / slide-pull=out, cells as jump targets, snap-to-day (Timepage/Fantastical) | 07 Zoom | with tap fallback for every gesture |
| **Scope-preserving** Today control (Timepage) | 07 Zoom | not a hard reset to Day |
| Live NL parse + sigils + confirm-before-commit (Fantastical) | 08 Create | CUE's AI is the parser; show parsed result |
| Detail leads with the single most-likely action (Cron) | 09 Detail | + graceful AI context degrade |
| Color = membership everywhere; status on a separate (shape) channel (Timepage/Fantastical) | 05/06/13 | don't overload color |
| Capture-from-chat as headline integration (Sunsama/Akiflow lesson) | 15 Telegram | CUE's differentiator |

**Cross-cutting pitfalls to avoid:** monochrome single-dot density; non-obvious create buttons
(keep "+" prominent even with NL); forcing the planning ritual; overloading color with both
identity and status; and (given prior UIKit day-strip landmines) treating every new gesture-driven
scope transition as a clamp/velocity hazard until proven otherwise.

---

## 6. iOS platform rules (apply to every screen prompt)

- **Frame:** single fixed iPhone 393×852pt @3x, **NOT responsive**; iOS status bar (time +
  battery, Dynamic Island reserved); top safe area ~59pt; 34pt home-indicator gutter; 16pt side
  margins; tap targets ≥44pt.
- **Nav:** floating Liquid Glass tab bar (warm-tinted, ~60pt, ~21pt insets, scroll-to-shrink);
  large title (~34pt Fraunces) at root, inline (~17pt) on drill-downs; ≤2 nav-bar trailing actions.
- **Sheets:** create/detail/edit use `.presentationDetents([.medium, .large])`, open at medium,
  keyboard up; grabber visible; detail-over-calendar adds `presentationBackgroundInteraction`.
  `fullScreenCover` for onboarding only.
- **Scope zoom:** `.navigationTransition(.zoom)` year→month→day with explicit reverse/rubber-band;
  pinch is a secondary accelerator, tap is the discoverable path.
- **Gestures:** horizontal day paging inset from the left edge (protect back-swipe); `.refreshable`;
  `contextMenu` for secondary actions; `.swipeActions` leading=complete (calm accent),
  trailing-full=delete (brick). Every gesture has a visible fallback.
- **Input ergonomics (Create):** title auto-focused; inline disclosure rows (no nested sheets);
  compact `DatePicker`; keyboard toolbar (Done + Today/Tomorrow chips); smart defaults (date =
  viewed day, group = last used).
- **Dynamic Type:** relative text styles only; spec reflow at AX sizes (truncate-with-detail,
  stack, wrap) for dense calendar cells. Never clip.
- **Haptics:** `.sensoryFeedback` — `.selection` on scope flicks/day swipe, `.impact` on detent
  snap / swipe commit, `.success` on save/complete. Respect system haptic setting.
- **Motion:** standard zoom/push (interruptible); **Reduce Motion → cross-fade**, drop parallax.
- **Accessibility:** every cell speaks date + weekday + count/state (e.g. "June 24, Wednesday, 3
  events"); selected day/scope marked selected; swipe/context actions exposed as
  `accessibilityActions`; **never color-only** meaning. **Contrast hard mode:** test composited
  text-over-glass ≥4.5:1; Reduce Transparency → solid warm Kraft fill behind chrome.

---

## 7. Claude Design prompting strategy (summary + reusable template)

**Setup once:** publish the Kraft & Ink system from [`01-DESIGN-SYSTEM.md` §0]; upload a live
screenshot; toggle Published. **Per screen:** use the template below; reference tokens + components
by name; supply real data; enumerate states; fix via comments not regens; then "apply across the
flow."

```
SCREEN: <name> — <its one job in a single sentence>
SYSTEM: Use the published "Kraft & Ink" design system and its tokens ONLY. No new colors, fonts,
        gradients, or pure white/black. Wax-seal accent appears at most ONCE (on <primary action>).

FRAME: Single fixed iPhone 393×852pt @3x. NOT responsive — a native iOS screen, not a web page.
       iOS status bar (time + battery, Dynamic Island reserved). Top safe area ~59pt; 34pt
       home-indicator gutter; 16pt side margins. Floating warm-tinted Liquid-Glass tab bar.

AUDIENCE: <who + when/where they use it>

LAYOUT (top → bottom):
  1. <region> — <component>, <token refs e.g. --surface card on --background>
  2. <region> — <component> showing <real content>
  Bottom: floating tab bar (warm Liquid Glass), tabs: Today / Calendar / Search / Settings + "+".

COMPONENTS (by name): CueCard, CueButton(.primary/.decisive/.secondary), CueChip, WaxSeal,
  CueAvatar, NotificationBanner, ...

REAL CONTENT (verbatim, no lorem / no "Item 1"):
  - <actual title / date / OccurrenceDTO row, group color>
  - <actual title / data row>

NATIVE PATTERNS: large-title nav collapsing on scroll; grouped-inset rows; swipe-actions
  (leading=complete, trailing-full=delete); sheet at .medium; compact DatePicker; pull-to-refresh.
  All tap targets ≥44pt.

STATE: Show <default>. Also produce: empty (<copy>), loading (warm-scrim spinner), error (<copy>).

BRAND GUARDRAILS: Fraunces for titles ≥17pt only; Public Sans body; JetBrains Mono for
  dates/counts/IDs. Letterpress depth (1px --border + hard value-cut, blur 0) — NO soft shadows,
  NO gradients, NO glassmorphism on cards, NO blue, NO pure #FFF/#000. Selected chips fill
  espresso --primary, not clay. Density as one-accent intensity, not a rainbow of dots.
```

---

## 8. Open questions for the founder

1. **Tab count.** Today + Calendar + Search + Settings (+"+") is 4 tabs; the app currently ships 3
   (Calendar/Dashboard/Settings). Promote Dashboard→Today and add Search as a 4th tab, or fold
   Search into a nav-bar glass island to stay at 3? Which tab is the default landing — Today or
   Calendar?
2. **Search backend.** There's no dedicated search endpoint today (only `GET /tasks` range
   filtering). Ship client-side filter over the synced window first, or add a BE search endpoint?
3. **Reminders UI vs schema.** `NotificationStrategy`/`NotificationRule` exist schema-only with no
   client controller. Scope page 16 to the **daily report** (which is wired) for v1 and defer
   per-task reminders, or build the reminder UI now and add the BE controller?
4. **Onboarding depth.** Minimal (single Sign-in screen, as today) or a 3–4 screen value/permission
   flow (calendar → AI/Telegram → notifications)?
5. **AI persona surface.** Expose the persona editor (BE-ready) in v1 Settings, or keep persona
   config Telegram-side only for now?
6. **Today vs Telegram ritual.** Should the morning brief / evening shutdown live as an in-app
   Today card, a Telegram message, or both (toggle)?
