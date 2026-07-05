# Cue (iOS)

Cue is an iOS planner / to-do app built around a **calendar-centric** model: a user
owns calendars, and tasks & events hang off them — unified (optional start/end or
all-day, optional completion), with recurring series, per-instance overrides, task
groups, reminders, a daily "morning brief", reporting, and a Telegram assistant.

- **UI:** SwiftUI only, iOS 26, Liquid Glass chrome. Design system: **"CUE — Clean"**
  (white surfaces, soft floating shadows, clay `#BE4A28` + olive `#466234` accents,
  IBM Plex Serif display titles / system sans / JetBrains Mono receipts).
- **State:** `@Observable @MainActor` stores via `@Environment` (no `ObservableObject`).
- **Data:** SwiftData (`@Model` + `@Query`), an on-device cache that re-syncs from the backend.
- **Networking:** `URLSession` + `Codable` (`APIClient`), no third-party HTTP library.
- **Backend:** [`cue-api`](../cue-api) (NestJS + Postgres + Redis). The HTTP contract lives in
  `../cue-api/docs/api/openapi.yaml`.

> Deep architecture, conventions, and the docs tree are in [`CLAUDE.md`](CLAUDE.md) and `docs/`.

## Requirements

- **macOS + Xcode 26+** (the iOS toolchain is macOS-only — there is no Linux path for
  building, the Simulator, snapshot, or UI tests).
- An iOS 26 Simulator (e.g. *iPhone 17 Pro*). Bundle id: `makarov.cue`.

## Build & run

### Xcode
Open `cue.xcodeproj`, pick an iPhone simulator, **⌘R**. Files dropped into `cue/`,
`cueTests/`, or `cueUITests/` auto-register (synchronized file groups — no `.pbxproj` edits).

### Command line
```bash
xcodebuild -project cue.xcodeproj -scheme cue \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

### Backend & sign-in
The API base URL is injected per build configuration from `Config/Debug.xcconfig` /
`Config/Release.xcconfig` (key `APIBaseURL`, read by `AppConfig`). Point Debug at your
backend (e.g. `http://localhost:3000` or an ngrok tunnel) while `cue-api` runs locally.

Auth is **Sign in with Apple** → a Cue JWT in the Keychain. In **DEBUG** builds a
**dev-login** is available: the hammer pill on the sign-in screen lists every backend user
(`GET /auth/dev/users`) and impersonates one (`POST /auth/dev/login/:userId`) — no Apple ID
needed against a local `cue-api` with `NODE_ENV=development`.

## Testing

Three layers, all run on a macOS Simulator. Pin a concrete simulator id and reuse one
`-derivedDataPath` for speed:

```bash
SIM=<your-booted-sim-udid>   # xcrun simctl list devices booted
DD=/tmp/cue-dd
```

> **Gotcha:** `-only-testing:cueTests/Snapshots` (a *folder* filter) reports `TEST SUCCEEDED`
> while running **zero** tests — a false green. Always target a **suite**:
> `-only-testing:cueTests/<SuiteName>`. Parallel test clones occasionally flake on
> app-launch; they re-pass on retry (`-retry-tests-on-failure`).

### 1 · Unit tests — logic (`cueTests/Unit/`)
[Swift Testing](https://developer.apple.com/documentation/testing) (`import Testing`,
`@Test`, `#expect`). Cover the deterministic logic across the app: recurrence rule building
& summaries, `FieldUpdate` tri-state PATCH encoding, the lenient ISO-8601 date decoder,
color/hex resolution, task keys / upsert / projection, CalendarStore reconciliation, Search,
MorningBrief, Auth, reminders, quick-parse, report settings, and more.

```bash
xcodebuild test -project cue.xcodeproj -scheme cue -destination "id=$SIM" \
  -derivedDataPath "$DD" -only-testing:cueTests/RecurrenceSummaryTests   # one suite
# or the whole unit set: pass one -only-testing:cueTests/<Suite> per suite under cueTests/Unit/
```

### 2 · Snapshot tests — design fidelity (`cueTests/Snapshots/`)
Storybook-style **visual** tests: render a screen/component in isolation with deterministic
mock data and rasterize to a PNG. Hermetic (no backend), one suite per page across a content
**state matrix** (empty · single · overlapping · short-time · all-day · completed · recurring ·
heavy). Built on a **vendored, dependency-free harness** — no `swift-snapshot-testing`.

- `SnapshotHarness.record(_:named:)` — hosts a view in a 393×852 window, rasterizes, and
  **attaches** the PNG to the test result bundle as `<name>.png`.
- `ScreenHost.wrap(_:container:)` — injects the full app environment (theme + every store +
  a seeded `ModelContainer`) so a screen renders exactly as in the app.
- `MockData` — the sample user, an in-memory store, builders, and the `DayState` matrix.

Run and extract the rendered PNGs (for diffing against the design references):
```bash
RB=/tmp/cue-snap.xcresult; rm -rf "$RB"
xcodebuild test -project cue.xcodeproj -scheme cue -destination "id=$SIM" \
  -derivedDataPath "$DD" -resultBundlePath "$RB" -only-testing:cueTests/TodaySnapshotTests
xcrun xcresulttool export attachments --path "$RB" --output-path ./snapshots
# ./snapshots/manifest.json maps exported files → the human-readable <name>.png
```

### 3 · End-to-end tests — behaviour & crash-safety (`cueUITests/`)
[XCUITest](https://developer.apple.com/documentation/xctest) drives the **real running app**
through a **hermetic UI-test mode**: launching with `--uitest` (a DEBUG-gated launch argument)
boots straight into an authenticated, **seeded, offline** session (network sync disabled), so
flows are fast, deterministic, and repeatable. **12 suites / 50 tests** — one per page (several
for the calendar) — assert each page is reachable, interactive, and **crash-safe**
(`app.state == .runningForeground`). `SmokeUITests` pins the original "tapping a task action
must not crash" regression (which surfaced a real missing-`@Environment`-on-`.sheet` crash).

```bash
xcodebuild test -project cue.xcodeproj -scheme cue -destination "id=$SIM" \
  -derivedDataPath "$DD" -only-testing:cueUITests/SmokeUITests
```

### Continuous integration
iOS UI testing requires a **macOS runner** (GitHub Actions `macos-15`, a self-hosted Mac for
GitLab, or a Mac cloud). Linux runners can build none of the above. Snapshot baselines are
sensitive to OS/Xcode font rendering — pin the runner image (and a perceptual tolerance if you
later compare against committed baselines).
