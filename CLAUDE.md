# Cue iOS

## Product

Cue is an iOS planner / TODO app. Backend at `~/personal-projects/cue-api` (NestJS + Postgres + Redis) — consult its `CLAUDE.md` for the domain model and API plans.

Feature goals:
- Calendar-centric org model (a user owns multiple Calendars; everything hangs off a Calendar).
- Tasks and events unified — optional start/end or all-day, optional completion.
- Recurring tasks (daily/weekly/monthly/yearly) with per-instance overrides.
- Reporting screen — "what did I complete in the past N days".
- Deep Siri integration via App Intents (planned).
- Telegram integration (planned — linked account + bot-driven reminders).
- Local + push notifications; per-task / per-group notification strategies.

## Tech stack

- **Language**: Swift (Swift Concurrency — `async`/`await`, actors; `default-isolation=MainActor`)
- **UI**: SwiftUI only. Liquid Glass (iOS 26) is the chrome.
- **Persistence**: SwiftData (currently only the Xcode-template `Item` stub; to be replaced with real `@Model` types mirroring the BE).
- **Deployment target**: iOS 26.4 (iPhone). Adjust `IPHONEOS_DEPLOYMENT_TARGET` carefully — liquid-glass APIs + `Tab` DSL + `ContentUnavailableView` require recent versions.
- **Bundle ID**: `makarov.cue`
- **Testing**: Swift Testing (macro-based, not XCTest)
- **IDE**: Xcode 16+ (project uses `PBXFileSystemSynchronizedRootGroup` — files dropped into `cue/` auto-register; no `project.pbxproj` editing needed)

## Project layout

```
cue-ios/
├── cue.xcodeproj/                ← Xcode project (synchronized groups)
├── cue/                          ← source root (all nested files auto-registered by sync group)
│   ├── App/                      ← @main entry + root composition
│   │   ├── cueApp.swift
│   │   └── RootView.swift
│   ├── Features/                 ← one folder per user-facing flow
│   │   ├── Calendar/
│   │   │   ├── CalendarView.swift
│   │   │   └── NewEvent/         ← nested sub-flow (add-event sheet)
│   │   │       ├── NewEventView.swift
│   │   │       └── NewEventViewModel.swift
│   │   ├── Dashboard/
│   │   │   └── DashboardView.swift
│   │   └── Settings/
│   │       └── SettingsView.swift
│   ├── DesignSystem/             ← reusable UI primitives + components
│   │   └── Components/
│   │       └── FloatingAddButton.swift
│   ├── Networking/               ← HTTP client + wire DTOs
│   │   ├── APIClient.swift
│   │   └── APIModels.swift
│   ├── Models/                   ← domain models; SwiftData @Models go here
│   │   └── Item.swift            ← legacy Xcode-generated stub (to be replaced)
│   └── Resources/
│       └── Assets.xcassets/
├── cueTests/                     ← Swift Testing target
└── cueUITests/                   ← UI test target
```

## Folder organization

Swift folders carry **no** semantic meaning — the compiler treats every `.swift` file in the app target as one module. Folders exist purely for humans. (True modularization happens via Swift Package targets; not used yet.)

**Pattern: feature-first + shared layers.**

- **`Features/<FeatureName>/`** — each user-facing flow is a folder. Colocate its views, view models, and feature-only components. Sub-flows nest (e.g. `Features/Calendar/NewEvent/`).
- **`DesignSystem/`** — reusable UI primitives and components used by (or reserved for) multiple features: button styles, color/typography tokens, shared controls.
- **`Networking/`** — HTTP client + wire DTOs.
- **`Models/`** — domain models and SwiftData `@Model` classes.
- **`Extensions/`** — general-purpose Foundation / SwiftUI extensions (create when the first one appears).
- **`App/`** — `@main` entry point and root composition only. Not a feature.

**Rule for placement:**
- Used by exactly one feature → lives inside that feature's folder.
- Used by two or more features → hoist to the appropriate shared layer (`DesignSystem/`, `Networking/`, etc.).
- Design primitive (color, typography, button style) → `DesignSystem/` from day one regardless of caller count.

**When to extract:** default to feature-local; hoist on the third caller. Don't pre-organize for hypothetical reuse.

**Sub-feature nesting:** a modal or sub-screen that is logically part of a parent feature (e.g. "Add event" inside Calendar) nests under the parent. Promote to top-level `Features/` only if it becomes a standalone destination.

**When to modularize further (SPM targets):** not yet. Consider when any `Features/X/` exceeds ~15 files and has clear one-way dependencies on shared layers. Until then, enforced folder discipline is enough.

## UI architecture

### Root navigation

`TabView` using the iOS 18+ `Tab(_:systemImage:content:)` DSL. Each tab wraps its view in `NavigationStack`. Three tabs:
1. **Calendar** (`calendar` SF Symbol) — day/week/month task views (planned)
2. **Dashboard** (`chart.bar.fill`) — completion reports (planned)
3. **Settings** (`gearshape`) — account, integrations, notifications (planned)

### Liquid Glass — DO NOT hand-roll it

On iOS 26, `TabView` + `NavigationStack` chrome renders with Liquid Glass **automatically**. Do NOT add any of:
- `.background(.ultraThinMaterial)` on nav/tab bars
- `UITabBar.appearance()` / `UINavigationBar.appearance()` mutation
- Custom blur layers, custom transparency overrides
- Any "sticky floating bar" reimplementation

Those are pre-iOS 26 workarounds and now produce wrong visuals. For custom elements that should look like Liquid Glass, use `.glassEffect()` (iOS 26+).

Optional polish reserved for when scroll content exists: `.tabBarMinimizeBehavior(.onScrollDown)` on the `TabView` — bar shrinks while scrolling. Defer until tabs have real content.

## Patterns to use

- **Local state**: `@State`.
- **Shared state**: `@Observable` class (iOS 17+ macro). Inject via `@Environment` or pass explicitly. Do NOT use `ObservableObject` / `@Published` / `@StateObject` / `@ObservedObject` — all legacy pre-iOS 17.
- **Data**: SwiftData `@Model` classes; `@Query` in views for reactive reads; `@Environment(\.modelContext)` for writes.
- **Navigation**: `NavigationStack` + value-based `navigationDestination(for:destination:)`. One stack per tab.
- **Concurrency**: `async`/`await` + structured concurrency (`Task`, `async let`, `TaskGroup`). Views run on `@MainActor` by default in Swift 6. Hop to background actors only when you actually need parallelism.
- **Sendability**: respect `Sendable`. The compiler enforces it — don't work around it with `@unchecked Sendable`.
- **Error/empty states**: `ContentUnavailableView` (iOS 17+).
- **View composition**: small structs, `@ViewBuilder` helpers; no ViewModel class unless there's genuine shared state or side effects to isolate.

## What NOT to do

- ❌ UIKit unless forced (e.g. a feature SwiftUI genuinely can't express — wrap via `UIViewRepresentable`).
- ❌ Manual transparency / blur on system chrome.
- ❌ Singletons for app state (use `@Observable` + `@Environment`).
- ❌ Combine in new code — use `async`/`await` + `AsyncSequence`.
- ❌ Force-unwrap (`!`) outside of bootstrap / previews / `fatalError` paths.
- ❌ `AnyView` as a convenience escape hatch — it erases performance characteristics. Use `@ViewBuilder` / `some View`.
- ❌ A view model / manager class when plain SwiftUI primitives (`@State`, `@Observable`, `@Environment`) work.

## Code style (Swift)

Global repo rules in `~/.claude/CLAUDE.md` are JS/TS-oriented. The Swift-relevant subset, plus Swift-specific conventions:

- **Naming**: PascalCase types and protocols, camelCase funcs/vars/properties, `UPPER_SNAKE_CASE` avoided (Swift prefers camelCase for constants too). No single-letter names.
- **Functions**: short, single responsibility. Early-exit with `guard` before main logic.
- **Documentation**: short `///` doc comment on each public type and non-trivial function. Skip on `body` / obvious SwiftUI boilerplate.
- **Optionals**: unwrap with `if let` / `guard let` / `?.` / `??`. Never force-unwrap (`!`) in production paths.
- **Types**: strong typing; `some View` / `some Protocol` for opaque returns; avoid `Any` / `AnyObject`.
- **Closures**: trailing closure syntax. Single-param one-liners can use `$0`; anything longer should name the parameter.
- **Structs vs classes**: prefer `struct` (value semantics). Use `class` only when you need reference semantics or Objective-C interop; use `final class` unless subclassing is intended.
- **Extensions**: group methods by conformance or concept; one extension per protocol conformance is idiomatic.

## Commands

```bash
# Command-line build (useful for CI / verification — what agents should run after edits)
xcodebuild -project cue.xcodeproj -scheme cue \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build

# Filter for errors/warnings
xcodebuild ... build 2>&1 | grep -iE '(warning|error):'

# In Xcode:
#  ⌘R       — Build & Run on selected simulator/device
#  ⌘B       — Build only
#  ⌘⇧K      — Clean Build Folder (clears phantom errors from stale DerivedData)
#  ⌘5       — Issue Navigator (all errors + warnings)
#  ⌘⌥↵     — Toggle Canvas / Live Preview
```

When agents make code changes, always run the CLI xcodebuild + grep once before reporting success. `xcodebuild` catches compilation errors; **SwiftUI Preview errors are separate and require Xcode to surface** — if the user sees a red error banner and CLI build is clean, check the preview macro or ask them to paste from ⌘5.

## Documentation

The `docs/` tree is the **source of truth for intent and decisions**. Code is the source of truth for behavior. DocC (`///` comments on public types in source) is the source of truth for the API surface. See [`docs/README.md`](docs/README.md) for the full layout.

```
docs/
  README.md             ← orientation; rules of the road
  architecture.md       ← one-page app overview
  adr/                  ← Architecture Decision Records (one decision per file, immutable)
    TEMPLATE.md
    0001-swiftui-not-uikit.md
  specs/                ← per-feature / per-screen design docs
    TEMPLATE.md
    calendar-view.md
    siri-app-intents.md
```

The HTTP contract with the backend lives in [`../cue-api/docs/api/openapi.yaml`](../cue-api/docs/api/openapi.yaml).

### When to write what

- **Architectural decision** (UI framework, persistence choice, navigation pattern, dependency adoption) → new `docs/adr/NNNN-<kebab-title>.md` copied from `docs/adr/TEMPLATE.md`. Number sequentially. Once accepted, the ADR is **immutable** — supersede with a new ADR rather than editing in place.
- **New screen / feature / sub-flow** → new `docs/specs/<feature>.md` copied from `docs/specs/TEMPLATE.md`, written **before** the implementation. Update as the design evolves.
- **Public type or API documentation** → DocC `///` comment in the source file, not in `docs/`.
- **System-level context that isn't a single decision or feature** → update `docs/architecture.md`.
- **One-off PR context** → the PR description, not a doc.

### How agents use docs

- **Before designing**: skim `docs/architecture.md`; check `docs/adr/` for relevant past decisions; check `docs/specs/` for any spec already covering this area; cross-reference the matching `cue-api/docs/specs/...` if there's a BE dependency.
- **Before implementing**: if no spec exists for non-trivial work (anything beyond a small UI tweak), draft one and confirm with the user before coding.
- **While implementing**: if an architectural decision is being made (not just executing an existing design), draft an ADR and confirm with the user.
- **After implementing**: update the spec status (`Draft` → `Implemented`), update `docs/architecture.md` if structure changed.
- **Cross-repo dependencies**: when an iOS change requires a BE change (new endpoint, schema field, etc.), link the matching `cue-api/docs/specs/...` doc and ensure the OpenAPI spec is updated there.

### Doc style

- Lead specs with **Context → Goals → Non-goals**. Spend more time on **Alternatives considered** than on the chosen design.
- ADRs are short (one screen). State the decision, the consequences (incl. downsides), the rejected alternatives.
- Diagrams inline as Mermaid; no external image files unless Mermaid cannot express it.
- Link liberally between docs with relative paths.

## Current state / deferred

- **Tab views are placeholders** (`ContentUnavailableView` stubs, no real content).
- **No real data layer yet.** `Item.swift` is the Xcode stub; replace with SwiftData `@Model` set mirroring BE entities (Calendar, Task, TaskGroup, RecurrenceRule, etc.) — adapted for SwiftData idioms (class-based, not struct; `@Relationship`; `@Attribute`).
- **No networking.** Will add a thin async/await HTTP client (URLSession only — no Alamofire or similar).
- **No auth.** Apple Sign-In + keychain-stored JWT, bridging to BE's `/auth/apple` (when that endpoint exists).
- **No App Intents (Siri).** Biggest differentiator once shipped.
- **No widgets** — "today's tasks" on home/lock screen is low-effort, high-visibility for v1.
- **No CloudKit sync.** Decision deferred (requires paid developer account). SwiftData + CloudKit integration is the idiomatic path if/when taken.
- **No Live Activities / Dynamic Island.** Nice-to-have for in-progress task timers.

## Conventions for agents working here

- **Default to idiomatic Swift / SwiftUI.** If a user request implies a non-idiomatic pattern (UIKit escape hatch, manual transparency, Combine in new code, singletons, legacy `ObservableObject`, etc.), surface the Swift-idiomatic alternative and confirm before implementing.
- **Files dropped into `cue/` auto-register** via synchronized groups — no `project.pbxproj` editing needed. Deletion works the same way (remove the file, Xcode reloads).
- **iOS 26 / Xcode 16+ features are fair game** — deployment target is pinned to 26.4. No need to write back-compat branches for iOS 17 or earlier.
- **When touching the data layer**, keep the iOS model mirrored from the BE's schema but translated into SwiftData idioms (class-based models, `@Relationship` with explicit inverse, avoid redundant `userId` fields — navigate via the object graph).
- **When touching networking**, use URLSession + `async`/`await`. Decode JSON with `JSONDecoder` + `Codable`. No third-party HTTP library.
