# Siri integration via App Intents

- **Status**: Draft (not implemented)
- **Last updated**: 2026-05-31
- **Owner**: @danil
- **Related ADRs**: [0001 — swiftui-not-uikit](../adr/0001-swiftui-not-uikit.md)
- **BE counterpart**: depends on Task CRUD endpoints (not yet specified)

## Context

Siri is a major differentiator for Cue. The App Intents framework (iOS 16+) lets users invoke app functionality by voice, by typing in Spotlight, or by Shortcuts automations — without ever opening the app. App Intents also drives:

- Shortcuts app integration.
- Apple Intelligence "use app" suggestions.
- Lock-screen and Action-button shortcuts.
- Focus filter & Smart Stack actions.

This spec covers the iOS-side intent surface. BE work (task CRUD endpoints) is a prerequisite.

## Goals

- "Hey Siri, add a task to call mom tomorrow at 5pm" → task created with `startAt = tomorrow 5pm local`, `title = "call mom"`.
- "Hey Siri, what's on my plate today?" → Siri reads back the day's tasks.
- "Hey Siri, complete my 3pm task" → task marked complete.
- Each intent works from Shortcuts, Spotlight typing, and voice — same code path.
- Intents are discoverable via App Shortcuts (visible in Shortcuts on first launch).

## Non-goals

- Custom Siri voice / TTS — use the system voice.
- Multi-step conversational flows ("…and what time?" follow-ups) — rely on App Intents' built-in parameter prompting.
- Apple Watch complications driven by App Intents (separate spec).
- Background app refresh purely to populate Siri suggestions.

## Proposed design

### Intent inventory (v1)

| Intent | Phrase example | Parameters |
|---|---|---|
| `AddTaskIntent` | "Add a task to <X>" | `title: String`, `startAt: Date?`, `calendar: CalendarEntity?` |
| `ListTasksTodayIntent` | "What's on my plate today?" | (none) |
| `CompleteTaskIntent` | "Complete <task title>" | `task: TaskEntity` (disambiguates via dialog) |
| `StartNextTaskIntent` | "Start my next task" | (none — reads from current time) |

### App Intents shape

```swift
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Title") var title: String
    @Parameter(title: "Time") var startAt: Date?
    @Parameter(title: "Calendar") var calendar: CalendarEntity?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let task = try await taskService.create(...)
        return .result(dialog: "Added \(task.title)")
    }
}
```

`taskService` is resolved via a small dependency container — App Intents instances are short-lived, must not capture SwiftUI environment, and run outside the app process when invoked by Siri/Shortcuts.

### Entity bridge

`TaskEntity: AppEntity` and `CalendarEntity: AppEntity` wrap SwiftData models. Each declares:
- `typeDisplayRepresentation`
- `displayRepresentation` (title + subtitle for Shortcuts UI)
- A `DefaultEntityQuery` for "Recent / today's tasks".
- A `StringQuery` for fuzzy match by title.

### App Shortcuts provider

`AppShortcutsProvider` declares pre-configured shortcuts so the OS surfaces them without the user manually opening Shortcuts.app. This is also what makes the action available via the Action button.

### Disambiguation

When Siri resolves "complete my 3pm task" and finds two tasks at 3pm, App Intents' built-in `requestDisambiguation` flow handles the follow-up question. We supply the dialog string only.

### Out-of-process execution

App Intents invoked via Siri run in an extension-like process — no SwiftUI environment, no `@Query`, no shared in-memory state. The intent reaches the data layer via a small `IntentDataStore` actor that talks to the same SwiftData store (using `ModelConfiguration` to point at the shared container).

## Edge cases

- **Offline create**: intent succeeds locally; sync layer reconciles when next online. Dialog confirms success.
- **No matching task** (Complete by title): Siri responds with "I couldn't find a task called X."
- **Ambiguous time** ("at 5"): rely on App Intents' built-in date parser; if unresolved, prompt for clarification.
- **Locked device**: most intents require unlock; `openAppWhenRun = false` keeps short interactions snappy.

## Alternatives considered

### Legacy `SiriKit` (`INIntent`)

The pre-App-Intents framework. Rejected because:
- App Intents is the path forward; SiriKit gets no new investment.
- App Intents has a better Swift-native API surface (`AppIntent` protocol vs. Objective-C-ish `INIntent` subclasses).
- App Intents drives Shortcuts/Spotlight/Action Button unified — SiriKit was Siri-only.

### Defer until v2

Tempting given how much foundational work is unbuilt. Rejected as a *spec timing* question, not a *design* question — the spec is cheap; the implementation can wait until task CRUD is in place. Writing the spec now anchors the API design (a task service that the intents will call has to be intent-friendly: async, no SwiftUI env, idempotent).

### Build only `AddTaskIntent` for v1

A minimal slice. Probably the right v1 *implementation* call. The spec covers the v1.0 intent set as the design target; we can ship `AddTaskIntent` alone and add others incrementally.

## Rollout

1. Land Task CRUD on the BE.
2. Land local SwiftData task model + sync.
3. Implement `IntentDataStore` actor against the SwiftData container.
4. Ship `AddTaskIntent` + `AppShortcutsProvider` with one shortcut.
5. Iterate: add `ListTasksTodayIntent`, then `CompleteTaskIntent`, then `StartNextTaskIntent`.

## Open questions

- [ ] How does the intent surface task completion status (does Siri say "marked complete" or just succeed silently)?
- [ ] Do we expose calendar selection at the intent level, or always add to the default calendar and let the user move?
- [ ] Visual snippet (custom view for the result) — worth the cost for v1?
- [ ] How do intents interact with the "default calendar on signup" — is the seeded `Personal` calendar always the implicit default?

## References

- [Apple — App Intents](https://developer.apple.com/documentation/appintents)
- [WWDC22 — Dive into App Intents](https://developer.apple.com/videos/play/wwdc2022/10032/)
- [WWDC23 — Spotlight your app with App Shortcuts](https://developer.apple.com/videos/play/wwdc2023/10103/)
