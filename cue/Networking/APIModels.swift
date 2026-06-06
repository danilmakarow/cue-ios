//
//  APIModels.swift
//  cue
//

import Foundation

// MARK: - Shared

/// Placeholder body for POSTs that don't carry a payload (e.g. dev login).
struct EmptyBody: Codable, Sendable {}

// MARK: - Auth

/// Server representation of an authenticated user. Mirrors `User` on the BE.
struct UserDTO: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let appleUserId: String
    let email: String?
    let displayName: String?
    /// Base64-encoded profile picture. Nil when the user hasn't supplied one.
    let avatarBase64: String?
    let timezone: String
    let createdAt: Date
    let updatedAt: Date
}

/// Request payload for `POST /auth/apple`.
struct AppleSignInRequest: Codable, Sendable {
    let identityToken: String
    let fullName: String?
    let avatarBase64: String?
    let timezone: String?
}

/// Response payload for `POST /auth/apple` — our JWT plus the persisted user.
struct AuthResponse: Codable, Sendable {
    let accessToken: String
    let user: UserDTO
}

// MARK: - Calendar

/// Server representation of a calendar.
struct CalendarDTO: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let ownerId: String
    let name: String
    let color: String?
    let icon: String?
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date
}

/// Request payload for `POST /calendars`.
struct CreateCalendarRequest: Codable, Sendable {
    let name: String
    let color: String?
    let icon: String?
}

// MARK: - Recurrence

/// Recurrence frequency. Matches `RecurrenceRuleDTO.frequency` exactly.
nonisolated enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
    case yearly = "YEARLY"
}

/// How a recurrence series ends.
nonisolated enum RecurrenceEndType: String, Codable, CaseIterable, Sendable {
    case never = "NEVER"
    case untilDate = "UNTIL_DATE"
    case count = "COUNT"
}

/// Server representation of a recurrence rule — embedded in `TaskDTO.recurrence`
/// and `TaskGroupDTO.recurrence`.
struct RecurrenceRuleDTO: Codable, Sendable, Hashable {
    let id: String
    let frequency: RecurrenceFrequency
    /// >= 1
    let interval: Int
    /// 0 = Monday … 6 = Sunday, or nil when not weekly.
    let byWeekday: [Int]?
    let byMonthDay: [Int]?
    let byMonth: [Int]?
    let endType: RecurrenceEndType
    /// "YYYY-MM-DD" — present only when `endType == .untilDate`.
    let endDate: String?
    /// Present only when `endType == .count`.
    let count: Int?
}

/// Request body that creates or replaces a recurrence rule (same as
/// `RecurrenceRuleDTO` minus `id`). Sent inside create/update task & group bodies.
///
/// `nonisolated` so its synthesized `Codable` conformance is available off the
/// main actor — required because it's the `Value` of `FieldUpdate<Value>`, whose
/// `Encodable & Sendable` constraint is exercised inside the request bodies the
/// `nonisolated` `APIClient` encodes.
nonisolated struct RecurrenceRuleInput: Codable, Sendable, Hashable {
    let frequency: RecurrenceFrequency
    let interval: Int
    let byWeekday: [Int]?
    let byMonthDay: [Int]?
    let byMonth: [Int]?
    let endType: RecurrenceEndType
    /// "YYYY-MM-DD" — required when `endType == .untilDate`.
    let endDate: String?
    /// Required when `endType == .count`.
    let count: Int?
}

// MARK: - Task (event)

/// Server representation of a task/event. Named `TaskDTO` to avoid collision
/// with Swift concurrency's `Task`.
struct TaskDTO: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let calendarId: String
    /// Optional group membership.
    let groupId: String?
    let title: String
    let notes: String?
    let startAt: Date?
    let endAt: Date?
    let isAllDay: Bool
    let timezone: String
    let requiresCompletion: Bool
    let completedAt: Date?
    let recurrenceRuleId: String?
    /// Full embedded rule, present when the task has a recurrence.
    let recurrence: RecurrenceRuleDTO?
    let notificationStrategyId: String?
    let createdAt: Date
    let updatedAt: Date
}

/// A single expanded occurrence of a (possibly recurring) task.
/// The calendar-read endpoint returns `[OccurrenceDTO]` instead of `[TaskDTO]`.
///
/// Occurrence identity: `(taskId, occurrenceStart)` — both must be threaded into
/// completion and skip calls so the server can key per-instance state.
struct OccurrenceDTO: Codable, Sendable {
    /// Series / anchor id (== `TaskDTO.id`). Stable across all instances.
    let taskId: String
    let calendarId: String
    let groupId: String?
    /// Stable instance key together with `taskId`. ISO string or nil for one-off tasks.
    let originalStart: Date?
    /// Effective start (after applying any override). ISO string or nil.
    let occurrenceStart: Date?
    /// Effective end.
    let occurrenceEnd: Date?
    let title: String
    let notes: String?
    let isAllDay: Bool
    let timezone: String
    let requiresCompletion: Bool
    /// Per-instance completion timestamp.
    let completedAt: Date?
    let isRecurring: Bool
    let isException: Bool
}

/// Request payload for `POST /tasks`.
struct CreateTaskRequest: Codable, Sendable {
    let calendarId: String
    /// Optional: assign directly to a group on creation.
    let groupId: String?
    let title: String
    let notes: String?
    let startAt: Date?
    let endAt: Date?
    let isAllDay: Bool
    let timezone: String
    let requiresCompletion: Bool
    /// Optional recurrence rule to attach at creation time.
    let recurrence: RecurrenceRuleInput?
}

/// Request payload for `PATCH /tasks/:id` — update any combination of fields.
/// Plain optionals are omitted when `nil` (leave unchanged). `recurrence` is a
/// ``FieldUpdate`` so the edit screen can distinguish "leave the rule alone"
/// (`.unchanged`) from "remove the rule" (`.clear`) — an explicit JSON `null`
/// the backend needs to actually drop the recurrence.
struct UpdateTaskRequest: Encodable, Sendable {
    var title: String?
    var notes: String?
    var startAt: Date?
    var endAt: Date?
    var isAllDay: Bool?
    var requiresCompletion: Bool?
    var groupId: String?
    var recurrence: FieldUpdate<RecurrenceRuleInput> = .unchanged

    private enum CodingKeys: String, CodingKey {
        case title, notes, startAt, endAt, isAllDay, requiresCompletion, groupId, recurrence
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(startAt, forKey: .startAt)
        try container.encodeIfPresent(endAt, forKey: .endAt)
        try container.encodeIfPresent(isAllDay, forKey: .isAllDay)
        try container.encodeIfPresent(requiresCompletion, forKey: .requiresCompletion)
        try container.encodeIfPresent(groupId, forKey: .groupId)
        try recurrence.encode(into: &container, forKey: .recurrence)
    }
}

/// Request payload for `PATCH /tasks/:id/completion`.
///
/// `occurrenceStart` is the recurring instance's **`originalStart`** (the stable
/// exception key, not the time-overridden effective start) and is a
/// pre-formatted ISO-8601 **string with fractional seconds**, NOT a `Date`.
/// Rationale: the shared `APIClient` encoder uses `.iso8601` which truncates
/// milliseconds, so a `Date` here would miss the backend's sub-second exception
/// key (assistant-created anchors carry millisecond precision). Build the string
/// with `ISO8601DateFormatter` + `.withFractionalSeconds` (see
/// `CalendarStore.isoFractional`). `nil` for one-off (non-recurring) tasks.
struct SetCompletionRequest: Codable, Sendable {
    let isCompleted: Bool
    let occurrenceStart: String?
}

/// Response from `PATCH /tasks/:id/completion`.
struct CompletionResultDTO: Codable, Sendable {
    let taskId: String
    let occurrenceStart: Date?
    let completedAt: Date?
}

/// Response from `DELETE /tasks/:id` — returns the deleted id.
struct DeletedIDResponse: Codable, Sendable {
    let id: String
}

/// Response from `POST /tasks/:id/skip`.
struct SkipResponse: Codable, Sendable {
    let ok: Bool
}

// MARK: - Task Group

/// Server representation of a task group.
struct TaskGroupDTO: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let calendarId: String
    let name: String
    let color: String?
    let icon: String?
    let sortOrder: Int
    let defaultRecurrenceRuleId: String?
    /// Full embedded group-level default recurrence rule.
    let recurrence: RecurrenceRuleDTO?
    let defaultNotificationStrategyId: String?
    let createdAt: Date
    let updatedAt: Date
}

/// Request payload for `POST /task-groups`.
struct CreateTaskGroupRequest: Codable, Sendable {
    let calendarId: String
    let name: String
    let color: String?
    let icon: String?
    let sortOrder: Int?
    /// Optional default recurrence rule for all tasks in the group.
    let recurrence: RecurrenceRuleInput?
}

/// Request payload for `PATCH /task-groups/:id`. Plain optionals are omitted when
/// `nil`. `recurrence` is a ``FieldUpdate`` so the group editor can clear the
/// group's default rule (`.clear` → explicit JSON `null`) versus leaving it
/// untouched (`.unchanged` → key omitted).
struct UpdateTaskGroupRequest: Encodable, Sendable {
    var name: String?
    var color: String?
    var icon: String?
    var sortOrder: Int?
    var recurrence: FieldUpdate<RecurrenceRuleInput> = .unchanged

    private enum CodingKeys: String, CodingKey {
        case name, color, icon, sortOrder, recurrence
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(sortOrder, forKey: .sortOrder)
        try recurrence.encode(into: &container, forKey: .recurrence)
    }
}

/// Legacy completion-toggle request kept for `UpdateTaskCompletionRequest`
/// references that will be removed as the migration completes. DO NOT use for
/// new code — use `SetCompletionRequest` instead.
/// Request payload for `PATCH /tasks/:id` — toggle completion.
/// BE sets `completedAt = now` on true, clears it on false.
struct UpdateTaskCompletionRequest: Codable, Sendable {
    let isCompleted: Bool
}

// MARK: - Telegram linking

/// Request payload for `POST /assistant/link` — redeems a single-use linking
/// nonce minted by the bot and binds the Telegram chat to the signed-in user.
struct LinkTelegramRequest: Codable, Sendable {
    let code: String
}

/// Telegram link state, returned by `GET`, `POST`, and `DELETE /assistant/link`.
///
/// One DTO serves all three: a successful `POST` and a populated `GET` carry the
/// username + timestamp, while `DELETE` (and an unlinked `GET`) return
/// `{ linked: false }` with both optionals absent → decoded as `nil`. Today's
/// `POST` may return only `{ linked: true }`; the optionals tolerate that too.
///
/// `linkedAt` is decoded as a `String?` (display-only) rather than a `Date` to
/// avoid coupling to the shared decoder's `.iso8601` (no-fractional-seconds)
/// strategy, which would fail the whole decode on a fractional-seconds timestamp.
struct TelegramLinkStatusDTO: Codable, Sendable, Equatable {
    let linked: Bool
    let telegramUsername: String?
    let linkedAt: String?
}
