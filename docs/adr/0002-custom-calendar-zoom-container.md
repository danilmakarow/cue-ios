# 0002 — custom-calendar-zoom-container

- **Status**: Accepted
- **Date**: 2026-06-09
- **Deciders**: Danil

## Context

The calendar's year, month, and day scopes were three `NavigationStack`
levels connected by `.navigationTransition(.zoom)`. That transition is a
two-endpoint push/pop: it cannot pause, retarget, or run as a true pinch,
and it only engages when the parent scope has a realized
`matchedTransitionSource` cell — which forced a polling registry
(`ZoomSourceRegistry`) and a multi-push, animation-aware deep-link
choreography on every cold launch and "go to today". The product goal is a
Photos-style *continuous* zoom: pinch out of the day view into the month
view (and month → year) as one smooth, interactive, cancellable gesture.
Cold launch also paid for the year scope (the stack root) before the day
scope the user actually lands on.

## Decision

The calendar's scopes are zoom levels of **one view** — a custom
`CalendarZoomContainer` that owns the active scope, cross-zooms between
adjacent scopes around the anchor cell's frame (tracked by a
`ScopeFrameRegistry`), and drives the transition from a `MagnifyGesture`.
`NavigationStack` remains only for leaf pushes (task detail).

## Consequences

- ✅ Pinch in/out between scopes is continuous, interactive, and
  cancellable; taps animate the same transition, so all scope changes read
  as one motion grammar.
- ✅ Cold launch renders the day scope directly; year/month mount lazily on
  first zoom-out. The seeding choreography, `ZoomSourceRegistry`, and
  `CalendarScopeRoute` are deleted.
- ✅ Programmatic "go to today" is a plain chained zoom — no waiting on lazy
  grids to realize transition sources.
- ⚠️ We own the transition polish (curves, fades, anchor capture) that the
  system zoom gave for free; system back-swipe between scopes is gone
  (zoom-out replaces it).
- ⚠️ Both scopes of a pair render during a gesture, so scope views must stay
  cheap (the ADR depends on the bounded-query/cached-grid work landing
  first).
- ⚠️ Pinch progress is `@State` updated per gesture frame — inherent to any
  interactive SwiftUI transition; acceptable because it only happens during
  the gesture.

## Alternatives considered

### Keep `.navigationTransition(.zoom)` and optimize around it

Lowest effort, system polish for free. Lost because the transition is
structurally incapable of the continuous-pinch UX (fixed endpoints, no
retargeting) and keeps the source-realization handshake that complicated
every programmatic navigation.

### UIKit collection-view core with custom interactive transitions

Full control and mature cell reuse. Lost because it violates
[ADR 0001](0001-swiftui-not-uikit.md), forks the codebase idioms, and the
SwiftUI hot spots were identifiable misuses rather than framework limits.
Remains the documented fallback if a profiled SwiftUI container still
misses frame budget.

## References

- [specs/calendar-performance-and-zoom.md](../specs/calendar-performance-and-zoom.md)
- [ADR 0001 — SwiftUI, not UIKit](0001-swiftui-not-uikit.md)
