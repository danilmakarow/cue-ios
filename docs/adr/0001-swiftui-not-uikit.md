# 0001 — swiftui-not-uikit

- **Status**: Accepted
- **Date**: 2026-05-31
- **Deciders**: @danil

## Context

iOS apps can be built in three modern UI paradigms:

1. **UIKit** with `UIViewController` + storyboards or programmatic views.
2. **UIKit + SwiftUI hybrid** — UIKit shell, SwiftUI for individual screens via `UIHostingController`.
3. **SwiftUI-only** — `@main App`, `WindowGroup`, `NavigationStack`, declarative all the way down.

Cue targets iOS 26.4, which means:
- Full availability of `@Observable` (iOS 17+), `NavigationStack` value-based routing (iOS 16+), the `Tab(_:systemImage:content:)` DSL (iOS 18+), `ContentUnavailableView` (iOS 17+), and Liquid Glass chrome (iOS 26+).
- No legacy-OS pressure to keep UIKit fallbacks around.
- SwiftData (iOS 17+) is the data layer of choice; integrates cleanly only with SwiftUI's `@Query` / `@Environment(\.modelContext)`.

Cue is also a small team (1 person at this stage) with no existing UIKit codebase to interop with.

## Decision

All new view code is **SwiftUI**. UIKit is used only as a last-resort escape hatch via `UIViewRepresentable` / `UIViewControllerRepresentable` when a needed primitive genuinely does not exist in SwiftUI.

## Consequences

- ✅ Less code for the same UI; declarative composition; tight integration with `@Observable`, SwiftData, and Liquid Glass.
- ✅ Live previews accelerate iteration.
- ✅ Future-aligned: Apple's investment is in SwiftUI; new framework features (Liquid Glass, `Tab` DSL, App Intents UI) land in SwiftUI first.
- ⚠️ A handful of UIKit-only primitives still exist (rich-text editing, certain map customizations, low-level scroll-view hacks). For those we wrap via `UIViewRepresentable` — but treat each wrap as a code smell, not a default tool.
- ⚠️ SwiftUI debugging tooling is less mature than UIKit's (view diffing, performance attribution). Acceptable cost at our scale.

## Alternatives considered

### UIKit-only

Mature, well-tooled, every team member knows it. Rejected because:
- It would forfeit SwiftData / Liquid Glass / App Intents ergonomics.
- Cue has no legacy UIKit code to amortize the investment.
- More code per screen, slower iteration.

### Hybrid UIKit shell + SwiftUI screens

Common in apps migrating from UIKit. Useful when there's an existing UIKit codebase to preserve. Rejected for Cue because **there is no existing UIKit code** — the hybrid model only adds complexity for no benefit. We'd own two navigation stacks (UIKit's `UINavigationController` and SwiftUI's `NavigationStack`) and the bridge between them.

### React Native / Flutter / KMP

Rejected because:
- Native is required for tight Siri / App Intents / WidgetKit / Live Activities integration — all of which are core to the Cue roadmap.
- No cross-platform deployment planned (iOS only at launch).
- Single-developer overhead of a native-only stack is lower than maintaining a JS toolchain.

## References

- [`cue/App/cueApp.swift`](../../cue/App/cueApp.swift)
- [Apple — SwiftUI](https://developer.apple.com/documentation/swiftui)
- iOS deployment target: 26.4 (`IPHONEOS_DEPLOYMENT_TARGET`)
