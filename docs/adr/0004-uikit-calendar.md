# 0004 — uikit-calendar

- **Status**: Accepted
- **Date**: 2026-06-20
- **Deciders**: @danil
- **Supersedes (scoped)**: [0002 — custom-calendar-zoom-container](0002-custom-calendar-zoom-container.md); supersedes [0001 — swiftui-not-uikit](0001-swiftui-not-uikit.md) **for the calendar scope surfaces only**.

## Context

The calendar's three scopes (day, month, year) and the continuous pinch-zoom
between them were built in SwiftUI per [ADR 0002](0002-custom-calendar-zoom-container.md).
ADR 0002 already named the exit: *"UIKit collection-view core … remains the
documented fallback if a profiled SwiftUI container still misses frame budget."*
It has.

Three structural problems proved to be framework limits, not misuses:

1. **Gesture fighting.** The pinch (`MagnifyGesture`) and each scope's scroll
   pan contend for the same touches. SwiftUI gives no `require(toFail:)` /
   `shouldRecognizeSimultaneouslyWith` arbitration, so zoom starts swallow
   scrolls and vice-versa; `scrollDisabled(transition != nil)` is a blunt patch.
2. **Per-frame body invalidation.** Interactive zoom drives `innerVisibility`
   as `@State` updated every gesture frame, re-evaluating the container body
   (and both mounted scopes) each tick. Infinite scroll needs the same per-frame
   geometry the scopes are forbidden from observing, forcing brittle
   `onScrollPhaseChange` / `scrollPosition(id:)` workarounds.
3. **A correctness bug rooted in the scroll model.** `MonthScopeView.syncAround`
   synced only the centered month ±1, but a fling can travel ~10 months
   (`maxMonthsPerFling`). Gap-months never sync → their windowed query is empty
   → recurring occurrences silently vanish. The SwiftUI scroll model gave no
   per-section "became visible" hook to drive idempotent per-unit syncing.

UIKit solves all three at the framework level: `UIGestureRecognizerDelegate`
arbitration; `UICollectionViewDiffableDataSource` snapshots that mutate without
invalidating a view tree; `prefetchDataSource` / `willDisplay` per-section
visibility callbacks; and `setContentOffset` correction for jump-free prepend.

The data layer (`CalendarStore`, `TaskItem`, `CalendarMath`) and the SwiftUI
design-token system stay; only the three scope surfaces and their zoom move to
UIKit.

## Decision

The calendar's day, month, and year scopes are rebuilt in **UIKit** —
`UICollectionViewController` + `UICollectionViewCompositionalLayout` +
`UICollectionViewDiffableDataSource` each — hosted in a
`CalendarContainerViewController` that uses child-view-controller containment
and owns a **custom interactive zoom controller** (pinch + tap, anchored on the
tapped/pinched cell). The whole surface is bridged into the SwiftUI app through
a single `UIViewControllerRepresentable`. The data layer and design tokens are
unchanged; the SwiftUI tokens are projected into a plain `CalendarTheme` value
the UIKit side consumes.

## Consequences

- ✅ Proper gesture arbitration (`require(toFail:)`,
  `shouldRecognizeSimultaneouslyWith`, delegate) ends the pinch-vs-scroll
  fighting; the active scope's scroll is disabled cleanly for the duration of a
  transition.
- ✅ Diffable snapshots mutate the data without re-evaluating a view tree;
  infinite scroll uses native `contentOffset` correction on prepend (no
  identity-pinned-id hack) and far-edge trimming to bound memory.
- ✅ The recurrence bug is structurally fixed: each section syncs itself via
  `prefetchItemsAt` / `willDisplay`, so coverage is independent of scroll speed.
- ✅ Mature reuse, prefetch, and scroll tooling; no per-frame body invalidation
  during the zoom.
- ⚠️ This is a deliberate, **scoped** exception to [ADR 0001](0001-swiftui-not-uikit.md):
  the rest of the app stays SwiftUI-only. The boundary is one
  `UIViewControllerRepresentable`; everything outside it is unchanged.
- ⚠️ UIKit can't read SwiftUI `@Environment`, so the theme and Dynamic Type must
  be bridged explicitly (`CalendarTheme`) and re-pushed on every theme/trait
  change — new plumbing the SwiftUI version got for free.
- ⚠️ The zoom polish (curves, fades, anchor capture, cancel/retarget) is hand-
  owned, as it already was under ADR 0002 — but now with UIKit primitives.
- ⚠️ Two codebase idioms now coexist in `Features/Calendar/`; contributors must
  know which side of the representable they are on. Leaf pushes (task detail)
  and the new-event/sheet flows stay SwiftUI, reached back through the host.

## Alternatives considered

### Stay in SwiftUI (keep ADR 0002), optimize around the limits

Lowest churn, single idiom, honors ADR 0001. Lost because the three problems
above are framework limits: SwiftUI exposes no gesture-failure arbitration, no
zero-invalidation list mutation, and no per-section visibility hook. ADR 0002
itself pre-authorized this fallback once profiling confirmed the miss.

### Stock UIKit `.zoom` navigation transition (`UINavigationController`)

Free system polish. Lost for the same reason ADR 0002 rejected
`.navigationTransition(.zoom)`: it is a two-endpoint push/pop that cannot pause,
retarget, or run as a true bidirectional pinch anchored on an arbitrary cell.
The product requires a continuous, cancellable, velocity-aware pinch between
adjacent scopes — only a custom interactive controller delivers it.

### `UICalendarView` (system calendar component)

Batteries-included month/decoration rendering. Lost because it is month-only
(no day timeline, no year-of-mini-months), is not infinitely scrollable, gives
no cell-anchored interactive cross-scope zoom, and can't host the Kraft & Ink
event cards / timeline. It solves a different, smaller problem.

## References

- [specs/calendar-uikit.md](../specs/calendar-uikit.md)
- [ADR 0001 — SwiftUI, not UIKit](0001-swiftui-not-uikit.md)
- [ADR 0002 — custom calendar zoom container](0002-custom-calendar-zoom-container.md)
- [ADR 0003 — design token system](0003-design-token-system.md)
- Apple — `UICollectionViewDiffableDataSource`, `UICollectionViewCompositionalLayout`, `UIViewControllerRepresentable`, `UIGestureRecognizerDelegate`
