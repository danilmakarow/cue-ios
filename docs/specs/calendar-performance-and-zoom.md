# Calendar performance refactor + continuous scope zoom

- **Status**: Draft
- **Last updated**: 2026-06-09
- **Owner**: Danil
- **Related ADRs**: [0001](../adr/0001-swiftui-not-uikit.md)
- **BE counterpart**: n/a (read path unchanged — `GET /tasks?calendarId&from&to`)

## Context

On a physical iPhone 17 Pro Max the app is slow to cold-launch (noticeable
delay before even the loading screen appears) and drops frames while
scrolling the month and year scopes. Separately, the product goal is a
*continuous* zoom between scopes — pinch out of the day view into the month
view (and month → year) with one smooth, interactive animation, the way
Photos zooms between grid densities.

Today the three scopes are three `NavigationStack` levels
(`YearScopeView` → `MonthScopeView` → `CalendarView`) connected by
`.navigationTransition(.zoom)`. That gives a zoom *push* and an interactive
zoom-*pop* (pinch/swipe-down), but it is a navigation transition, not a
zoom: it only animates between two fixed endpoints, requires a realized
`matchedTransitionSource` cell in the parent (hence `ZoomSourceRegistry`
and the cold-launch deep-link choreography in `CalendarRootView`), and
cannot pause mid-way or retarget.

### Identified hot spots (code inspection)

Ranked by expected impact.

**Scroll FPS (month + year scopes)**

1. **Per-frame `@State` writes during scroll.** Both scope views do
   `onScrollGeometryChange(for: ScrollGeometry.self, of: { $0 })` and write
   `currentOffsetY` on every scrolled frame. Each write invalidates the
   whole scope view, so every frame re-runs `body`, re-diffs the `ForEach`
   over a *growing* anchor array, and rebuilds the `FlingClampBehavior`.
   This alone is enough to break 120 Hz. The data is only needed at gesture
   start (`flingStartOffsetY`) and rarely (`pointsPerMonth`), neither of
   which requires per-frame observation.
2. **`MonthPage` queries the entire task table.** Its `@Query` predicate is
   just `occurrenceStart != nil`; the month filter happens in `body`. Every
   realized month page holds a live full-table query, so any
   `context.save()` (month sync upserts, completion toggles — including the
   saves `syncAround` fires *while scrolling settles*) re-runs N full-table
   fetches and N in-body `Set` reductions. Note `DayEventsProvider` already
   proves a bounded predicate works (`(occurrenceStart ?? sentinel) >= from`),
   so the "predicate can't do this" comment in `MonthPage` is stale.
3. **Year mini-months are built from ~450 `Text` views per year page.**
   Each `YearMonthCell` runs `CalendarMath.monthGridCells` (31×
   `calendar.date(byAdding:)`) and formats every day number with
   `.formatted(...)` at render time; a `YearPage` realizes 12 of those at
   once inside the `LazyVStack`. Realizing one year mid-fling ≈ 450 views +
   450 date computations + 450 format calls on the main actor.
4. **Anchor windows grow without bound** (`extendIfNeeded` only ever
   inserts). After a long session the `ForEach` diff and
   `firstIndex(of:)` costs keep climbing, and `LazyVStack` keeps realized
   pages alive.
5. **Matched-source density.** Every realized `MonthDayCell` (35/month ×
   realized months) and every `YearMonthCell` registers a
   `matchedTransitionSource` in one namespace, plus two registry closures
   (`onAppear`/`onDisappear`) per day cell.

**Cold launch**

6. `cueApp` synchronously builds six stores + the `ModelContainer`
   (SQLite open, schema validation, and a destroy-and-recreate fallback
   path) and a keychain read before the first frame can render. The
   loading screen itself paints only after all of that plus dyld/pre-main.
7. First-frame work for the calendar tab is the *year* scope (~25 anchors
   seeded; visible pages realize hundreds of texts), even though the user
   lands on the day scope. Then `deepLinkToDay` plays two animated pushes
   with an up-to-1 s polling wait between them (`ZoomSourceRegistry`)
   purely to arm the interactive zoom-out.
8. `AuthStore.bootstrap()` blocks the UI on `GET /auth/me` before showing
   the tabs even when a valid token + cached user exist. (Bug, found while
   reading: the generic-error branch sets `.unauthenticated` although the
   comment says an offline launch should keep the session.)
9. `TimelineDayPage` hides itself (`opacity 0`) and sleeps 60 ms + 20 ms
   before revealing, so each day page realized during horizontal swiping
   blinks in late.

## Goals

- Month and year scopes scroll at device refresh rate on hardware.
- Cold launch shows the loading screen immediately and the day scope
  without a visible multi-push choreography.
- Pinch-out from day → month and month → year is a single smooth,
  interactive, cancellable gesture; pinch-in goes the other way.
- The data layer stays SwiftData + month-window sync (no BE changes).

## Non-goals

- Redesign of the day timeline/list pages.
- Week scope, multi-calendar visuals, or any new calendar features.
- Replacing SwiftData.

## Options

### Option A — Targeted optimization of the current architecture

Keep `NavigationStack` + `.navigationTransition(.zoom)`. Fix the hot
spots in place:

- Drop per-frame scroll observation: read the gesture-start offset from
  `onScrollPhaseChange`'s context geometry; derive `pointsPerMonth/Year`
  from `onScrollGeometryChange(of:)` projecting **only** `contentSize`
  (changes rarely, not per frame).
- Give `MonthPage` a real bounded predicate (sentinel-coalescing pattern
  already used by `DayEventsProvider`), or hoist day-dots into a
  `CalendarStore`-maintained `[monthAnchor: Set<dayKey>]` index updated
  once per sync instead of N live queries.
- Precompute month grids: a cached value-type `MonthGridModel`
  (`[Int?]` day numbers + pre-formatted strings, keyed by month anchor)
  shared by `MonthGrid` and `YearMonthCell`; no `Calendar` math or
  `FormatStyle` calls in any cell `body`. Optionally render the year
  mini-month as a single `Canvas`/`Text` instead of ~37 views.
- Slide the anchor windows (trim the far edge when extending) so arrays
  stay ~40 elements.

**Gain**: fixes FPS and most of launch jank with small, local diffs; no UX
change. **Limit**: the zoom stays a two-endpoint navigation transition —
`ZoomSourceRegistry` and the deep-link choreography remain.

### Option B — Option A + data/view-model restructure ("dumb views")

Everything in A, plus restructure so scope views are pure functions of
value types:

- `CalendarStore` owns an `EventDayIndex` (`@Observable`, month → set of
  day keys with events) maintained at sync time; `MonthPage` loses its
  `@Query` entirely. Only the day scope keeps live `@Query`s.
- All grid geometry/labels come from cached `MonthGridModel`s.

**Gain**: render cost becomes O(visible cells) with zero model-layer
coupling, which is also the *prerequisite* for Option C — a custom zoom
container has to render two scopes simultaneously during the gesture,
which is only cheap if pages are value-type-driven. **Limit**: still the
navigation-transition zoom.

### Option C — Custom continuous zoom container (target UX)

Replace inter-scope navigation with **one** zoomable container owning a
`zoomLevel` state machine (`day ↔ month ↔ year`). A `MagnifyGesture`
(plus pinch on trackpad) drives an interactive transition: the outgoing
scope scales/fades toward the incoming scope's geometry, anchored at the
cell under the pinch centroid (day cell ↔ day page; month cell ↔ month
page), with `matchedGeometryEffect` *within one view tree* instead of
navigation matched sources. Gesture end (or velocity) commits or cancels;
taps still work as instant zoom-ins. `NavigationStack` remains only for
leaf pushes (task detail/edit), so back-swipe and toolbars are unaffected.

Consequences:

- `ZoomSourceRegistry`, `waitUntilPresent`, and the entire
  `deepLinkToDay` push choreography are deleted — cold launch renders the
  day scope directly (year/month never realize until first zoom-out).
  This is also a launch-time win (hot spot 7).
- The container needs its own scope state (`centered` anchors per level
  survive zooming), and both adjacent scopes render during a gesture —
  hence the Option B prerequisite.
- More code we own; the system zoom transition's free polish (shadow,
  chrome morphing) must be reproduced or accepted as different.

### Option D — UIKit `UIScrollView`/collection-view core (rejected for now)

A `UIViewRepresentable` calendar core (the Apple-Calendar approach) would
give cell reuse and fully custom interactive transitions, but violates the
SwiftUI-first ADR, forks the codebase idioms, and Options A–C are expected
to hit the targets without it. Revisit only if a profiled SwiftUI
implementation of C still misses frame budget.

## Proposed plan (recommendation)

Phased: **B first, then C** — B is small, de-risks immediately, and C
depends on it.

1. **Phase 1 (perf, ~1 short PR each)**: scroll-observation fix; bounded
   month query / `EventDayIndex`; cached `MonthGridModel` + cheap year
   cells; window trimming. Verify with Instruments (SwiftUI + Time
   Profiler) on device, Release config.
2. **Phase 2 (launch)**: render `LoadingView` before heavy init where
   possible; fix the offline-bootstrap bug + show cached session
   optimistically and validate `/auth/me` in the background; remove the
   `TimelineDayPage` sleep-and-reveal in favor of `defaultScrollAnchor`.
3. **Phase 3 (zoom UX)**: build the zoom container behind the existing
   navigation (feature-flagged), port scopes onto it, delete
   `ZoomSourceRegistry` + deep-link choreography when it lands.

Phase 1 and 2 are pure wins regardless of whether Phase 3 happens.

## Open questions

- [ ] Phase 3 gesture grammar: pinch only, or also keep swipe-down-to-zoom-out?
- [ ] Should launch land on day scope with month/year mounted lazily on
      first zoom-out (recommended), or pre-warm month in the background?
- [ ] Is the offline-bootstrap fix (stay signed in on network error) the
      desired behavior? Code and comment currently disagree.

## References

- `cue/Features/Calendar/` — current implementation.
- WWDC24 "Enhance your UI animations and transitions" (zoom navigation
  transitions); WWDC23 "Demystify SwiftUI performance".
- `docs/specs/calendar-view.md` — original calendar spec.
