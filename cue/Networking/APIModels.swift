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

/// MONTHLY working-day (Mon–Fri) anchor for a recurrence rule (S3). Mirrors the
/// backend `MonthlyAnchorMode` exactly. Pins a single occurrence to the first /
/// last / day-before-last working day of the month, independent of a fixed
/// day-of-month or nth-weekday selector.
///
/// Honored only for `.monthly` frequency; mutually exclusive with `byMonthDay`,
/// `bySetPos`, and `byWeekday` (see the cross-field rule on
/// ``RecurrenceRuleInput``).
nonisolated enum MonthlyAnchorMode: String, Codable, CaseIterable, Sendable {
    /// First Mon–Fri on/after the 1st of the month.
    case firstWorkday = "FIRST_WORKDAY"
    /// Last Mon–Fri on/before the last day of the month.
    case lastWorkday = "LAST_WORKDAY"
    /// The working day immediately before ``lastWorkday`` (second-to-last workday).
    case dayBeforeLastWorkday = "DAY_BEFORE_LAST_WORKDAY"
}

/// Server representation of a recurrence rule — embedded in `TaskDTO.recurrence`
/// and `TaskGroupDTO.recurrence`.
struct RecurrenceRuleDTO: Codable, Sendable, Hashable {
    /// The former recurrence-rule row id. Now OPTIONAL: recurrence is stored inline
    /// as JSONB (backend ADR 0054), so the backend's `RecurrenceConfigDTO` no longer
    /// emits an `id`. A required `id` here made `JSONDecoder` throw `keyNotFound(.id)`
    /// on the `recurrence` object of every recurring task's `GET /tasks/:id` — which
    /// silently failed the whole `TaskDTO` decode and made recurring tasks appear
    /// un-editable. Nothing reads this field; it is kept only for wire-compat.
    let id: String?
    let frequency: RecurrenceFrequency
    /// >= 1
    let interval: Int
    /// 0 = Monday … 6 = Sunday, or nil when not weekly.
    let byWeekday: [Int]?
    let byMonthDay: [Int]?
    let byMonth: [Int]?
    /// MONTHLY nth-weekday ordinals (RFC-5545 BYSETPOS): 1…4 = first…fourth,
    /// -1 = last. Combined with `byWeekday` to express "first Monday" / "last
    /// Friday"; nil means no ordinal restriction. Honored only for `.monthly`.
    let bySetPos: [Int]?
    /// MONTHLY working-day anchor (first / last / day-before-last Mon–Fri); nil
    /// means no working-day anchor. Honored only for `.monthly`.
    let monthlyAnchor: MonthlyAnchorMode?
    let endType: RecurrenceEndType
    /// "YYYY-MM-DD" — present only when `endType == .untilDate`.
    let endDate: String?
    /// Present only when `endType == .count`.
    let count: Int?
}

/// Request body that creates or replaces a recurrence rule (same as
/// `RecurrenceRuleDTO` minus `id`). Sent inside create/update task & group bodies.
///
/// Cross-field rules the editor must enforce before sending (the backend
/// validates them too):
/// - `bySetPos` requires a non-empty `byWeekday` and `.monthly` frequency.
/// - `monthlyAnchor` is mutually exclusive with `byMonthDay` / `bySetPos` /
///   `byWeekday` and is `.monthly`-only.
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
    /// MONTHLY nth-weekday ordinals (1…4 = first…fourth, -1 = last); combine with
    /// `byWeekday`. Defaulted so existing call sites stay source-compatible.
    var bySetPos: [Int]? = nil
    /// MONTHLY working-day anchor. Defaulted so existing call sites stay
    /// source-compatible.
    var monthlyAnchor: MonthlyAnchorMode? = nil
    let endType: RecurrenceEndType
    /// "YYYY-MM-DD" — required when `endType == .untilDate`.
    let endDate: String?
    /// Required when `endType == .count`.
    let count: Int?
}

// MARK: - Reminders

/// Delivery channel for a per-task reminder. Mirrors the backend
/// `NotificationChannel` exactly.
///
/// `nonisolated` so its synthesized `Codable` conformance is reachable off the
/// main actor — it rides inside the request bodies the `nonisolated` `APIClient`
/// encodes (via ``ReminderInput``).
nonisolated enum NotificationChannel: String, Codable, CaseIterable, Sendable {
    case push = "PUSH"
    case telegram = "TELEGRAM"
}

/// Server representation of a per-task reminder, embedded in `TaskDTO.reminders`.
/// Carries the persisted rule id so the client can correlate, plus the offset +
/// channel. `offsetMinutes` is relative to the task start: negative fires before,
/// positive after.
struct ReminderDTO: Codable, Sendable, Hashable {
    let id: String
    let offsetMinutes: Int
    let channel: NotificationChannel
}

/// A single per-task reminder on a create/update body — the offset (minutes from
/// the task start; negative before, positive after) plus the delivery channel.
/// No `id`: the backend assigns one and returns it on ``ReminderDTO``.
///
/// `nonisolated` so its synthesized `Codable` conformance is reachable off the
/// main actor — it is the element type of the `[ReminderInput]` request fields
/// the `nonisolated` `APIClient` encodes (and the `Value` of a `FieldUpdate`).
nonisolated struct ReminderInput: Codable, Sendable, Hashable {
    let offsetMinutes: Int
    let channel: NotificationChannel
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
    /// Per-task color: a `TaskColor` preset name (e.g. "BLUE") or a `#RRGGBB`
    /// hex; nil inherits the group color. Resolve via ``TaskColorResolver``.
    let color: String?
    /// Per-task icon (SF Symbol name); nil leaves the task iconless.
    let icon: String?
    let completedAt: Date?
    let recurrenceRuleId: String?
    /// Full embedded rule, present when the task has a recurrence.
    let recurrence: RecurrenceRuleDTO?
    /// The task's own per-task reminders (offset + channel), earliest first.
    /// Decodes an absent key as an empty array.
    let reminders: [ReminderDTO]
    let notificationStrategyId: String?
    /// Non-nil when this task is a materialized override child — the recurring
    /// parent's id. A child carries no recurrence rule of its own.
    let parentTaskId: String?
    /// RECURRENCE-ID: the pre-override generated instant this child replaces.
    let originalStartAt: Date?
    /// Set when the parent rule no longer generates this child's original slot.
    let detachedAt: Date?
    /// Bumped when the task's effective-rule inputs change; the delta client uses
    /// `recurrenceUpdatedAt > since` as its "re-expansion needed" discriminator.
    let recurrenceUpdatedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id, calendarId, groupId, title, notes, startAt, endAt, isAllDay
        case timezone, requiresCompletion, color, icon, completedAt
        case recurrenceRuleId, recurrence, reminders, notificationStrategyId
        case parentTaskId, originalStartAt, detachedAt, recurrenceUpdatedAt
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        calendarId = try container.decode(String.self, forKey: .calendarId)
        groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        startAt = try container.decodeIfPresent(Date.self, forKey: .startAt)
        endAt = try container.decodeIfPresent(Date.self, forKey: .endAt)
        isAllDay = try container.decode(Bool.self, forKey: .isAllDay)
        timezone = try container.decode(String.self, forKey: .timezone)
        requiresCompletion = try container.decode(Bool.self, forKey: .requiresCompletion)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        recurrenceRuleId = try container.decodeIfPresent(String.self, forKey: .recurrenceRuleId)
        recurrence = try container.decodeIfPresent(RecurrenceRuleDTO.self, forKey: .recurrence)
        reminders = try container.decodeIfPresent([ReminderDTO].self, forKey: .reminders) ?? []
        notificationStrategyId = try container.decodeIfPresent(String.self, forKey: .notificationStrategyId)
        parentTaskId = try container.decodeIfPresent(String.self, forKey: .parentTaskId)
        originalStartAt = try container.decodeIfPresent(Date.self, forKey: .originalStartAt)
        detachedAt = try container.decodeIfPresent(Date.self, forKey: .detachedAt)
        recurrenceUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .recurrenceUpdatedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
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
    /// The owning group's color — a `TaskColor` preset name (e.g. "BLUE") or a
    /// `#RRGGBB` hex; nil when ungrouped or the group relation wasn't loaded.
    /// Carried alongside `groupId` so day rails / month dots can render the real
    /// group color even when the task has its own `color` override. Resolve via
    /// ``TaskColorResolver`` — NOT always a hex. Defaulted so the
    /// `TaskDTO`-derived synthesis in `TaskItem+Mapping` stays source-compatible.
    var groupColorHex: String? = nil
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
    /// EFFECTIVE color (task ?? group ?? nil): a `TaskColor` preset name or a
    /// `#RRGGBB` hex. Resolve via ``TaskColorResolver``. Defaulted so the
    /// `TaskDTO`-derived synthesis in `TaskItem+Mapping` stays source-compatible.
    var color: String? = nil
    /// Per-task icon (SF Symbol name); nil leaves the occurrence iconless.
    /// Defaulted so the `TaskDTO`-derived synthesis stays source-compatible.
    var icon: String? = nil
    /// Per-instance completion timestamp.
    let completedAt: Date?
    let isRecurring: Bool
    let isException: Bool
    /// Non-nil when this occurrence is a materialized override of a recurring
    /// series — the parent task's id. `taskId` is then the CHILD's id, so
    /// completion / edit / delete address the child directly. Defaulted so the
    /// `TaskDTO`-derived synthesis in `TaskItem+Mapping` stays source-compatible.
    var parentTaskId: String? = nil
    /// True when this override child's parent rule no longer generates its
    /// original slot. Defaulted for the same source-compat reason.
    var isDetached: Bool = false

    private enum CodingKeys: String, CodingKey {
        case taskId, calendarId, groupId, groupColorHex, originalStart
        case occurrenceStart, occurrenceEnd, title, notes, isAllDay, timezone
        case requiresCompletion, color, icon, completedAt, isRecurring, isException
        case parentTaskId, isDetached
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskId = try container.decode(String.self, forKey: .taskId)
        calendarId = try container.decode(String.self, forKey: .calendarId)
        groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
        groupColorHex = try container.decodeIfPresent(String.self, forKey: .groupColorHex)
        originalStart = try container.decodeIfPresent(Date.self, forKey: .originalStart)
        occurrenceStart = try container.decodeIfPresent(Date.self, forKey: .occurrenceStart)
        occurrenceEnd = try container.decodeIfPresent(Date.self, forKey: .occurrenceEnd)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isAllDay = try container.decode(Bool.self, forKey: .isAllDay)
        timezone = try container.decode(String.self, forKey: .timezone)
        requiresCompletion = try container.decode(Bool.self, forKey: .requiresCompletion)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        isRecurring = try container.decode(Bool.self, forKey: .isRecurring)
        isException = try container.decode(Bool.self, forKey: .isException)
        parentTaskId = try container.decodeIfPresent(String.self, forKey: .parentTaskId)
        isDetached = try container.decodeIfPresent(Bool.self, forKey: .isDetached) ?? false
    }

    /// Memberwise initializer retained so callers (e.g. `TaskItem+Mapping`'s
    /// `TaskDTO`-derived synthesis) can build an occurrence directly. The custom
    /// `init(from:)` shadows the synthesized one, so it's restated here.
    init(
        taskId: String,
        calendarId: String,
        groupId: String?,
        groupColorHex: String? = nil,
        originalStart: Date?,
        occurrenceStart: Date?,
        occurrenceEnd: Date?,
        title: String,
        notes: String?,
        isAllDay: Bool,
        timezone: String,
        requiresCompletion: Bool,
        color: String? = nil,
        icon: String? = nil,
        completedAt: Date?,
        isRecurring: Bool,
        isException: Bool,
        parentTaskId: String? = nil,
        isDetached: Bool = false
    ) {
        self.taskId = taskId
        self.calendarId = calendarId
        self.groupId = groupId
        self.groupColorHex = groupColorHex
        self.originalStart = originalStart
        self.occurrenceStart = occurrenceStart
        self.occurrenceEnd = occurrenceEnd
        self.title = title
        self.notes = notes
        self.isAllDay = isAllDay
        self.timezone = timezone
        self.requiresCompletion = requiresCompletion
        self.color = color
        self.icon = icon
        self.completedAt = completedAt
        self.isRecurring = isRecurring
        self.isException = isException
        self.parentTaskId = parentTaskId
        self.isDetached = isDetached
    }
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
    /// Optional per-task icon (SF Symbol name); nil/omitted leaves it iconless.
    /// Defaulted so existing call sites stay source-compatible.
    var icon: String? = nil
    /// Optional per-task reminders (offset + channel) persisted at creation time;
    /// nil/omitted creates none. Defaulted so existing call sites stay
    /// source-compatible.
    var reminders: [ReminderInput]? = nil
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
    /// Per-task color: a `TaskColor` preset name (e.g. "BLUE") or a `#RRGGBB` hex.
    /// A ``FieldUpdate`` so the edit screen can distinguish "leave the color alone"
    /// (`.unchanged`) from "clear it so the group color is inherited" (`.clear` →
    /// explicit JSON `null`) versus "set it" (`.set`). Mirrors the backend's
    /// `UpdateTaskDto.color?: string | null` tri-state.
    var color: FieldUpdate<String> = .unchanged
    /// Per-task icon. A ``FieldUpdate`` so the edit screen can distinguish "leave
    /// the icon alone" (`.unchanged`) from "remove it" (`.clear` → explicit JSON
    /// `null`) versus "set it" (`.set`).
    var icon: FieldUpdate<String> = .unchanged
    /// Per-task reminders. NOT a tri-state: this field is "replace the whole set"
    /// — `nil` omits the key (leave untouched), an empty array clears all
    /// reminders, a populated array replaces them. (The backend has no
    /// explicit-null semantics for this field, so a plain optional models it.)
    var reminders: [ReminderInput]?
    var recurrence: FieldUpdate<RecurrenceRuleInput> = .unchanged

    private enum CodingKeys: String, CodingKey {
        case title, notes, startAt, endAt, isAllDay, requiresCompletion, groupId
        case color, icon, reminders, recurrence
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
        try color.encode(into: &container, forKey: .color)
        try icon.encode(into: &container, forKey: .icon)
        try container.encodeIfPresent(reminders, forKey: .reminders)
        try recurrence.encode(into: &container, forKey: .recurrence)
    }
}

/// Request payload for `POST /tasks/:id/occurrences/override` — materializes an
/// editable override child for one occurrence of a recurring series.
///
/// `originalStart` identifies which generated occurrence to override and MUST be a
/// fractional-seconds ISO string (built via `CalendarStore.isoFractional`) to
/// match the backend's sub-second occurrence key — same rationale as
/// `SetCompletionRequest.occurrenceStart`. The remaining fields are the patch
/// applied on top of the parent snapshot; `color`/`icon` are ``FieldUpdate``
/// tri-states (omit = inherit the parent, `.clear` = explicit null, `.set` = set).
struct CreateOccurrenceOverrideRequest: Encodable, Sendable {
    let originalStart: String
    var title: String?
    var notes: String?
    var startAt: Date?
    var endAt: Date?
    var isAllDay: Bool?
    var requiresCompletion: Bool?
    var groupId: String?
    var color: FieldUpdate<String> = .unchanged
    var icon: FieldUpdate<String> = .unchanged
    var reminders: [ReminderInput]?

    private enum CodingKeys: String, CodingKey {
        case originalStart, title, notes, startAt, endAt, isAllDay
        case requiresCompletion, groupId, color, icon, reminders
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(originalStart, forKey: .originalStart)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(startAt, forKey: .startAt)
        try container.encodeIfPresent(endAt, forKey: .endAt)
        try container.encodeIfPresent(isAllDay, forKey: .isAllDay)
        try container.encodeIfPresent(requiresCompletion, forKey: .requiresCompletion)
        try container.encodeIfPresent(groupId, forKey: .groupId)
        try color.encode(into: &container, forKey: .color)
        try icon.encode(into: &container, forKey: .icon)
        try container.encodeIfPresent(reminders, forKey: .reminders)
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

/// Response from `GET /tasks/daily-counts`. `counts` maps a local `YYYY-MM-DD`
/// date string to that day's occurrence total; zero-count days are omitted.
struct DailyCountsResponse: Codable, Sendable {
    let counts: [String: Int]
}

// MARK: - Task search

/// A single task search hit, returned by `GET /tasks/search` (M1). Carries the
/// matched series row's identity and its anchor date/time plus the owning group's
/// id + color, so the search screen can render the row with its real group color
/// and navigate to its date — even for a recurring series, where `startAt` is the
/// anchor occurrence.
struct TaskSearchResultDTO: Codable, Identifiable, Sendable, Hashable {
    /// Series / anchor id (== `TaskDTO.id`).
    let taskId: String
    let calendarId: String
    let groupId: String?
    /// The owning group's color — a `TaskColor` preset name (e.g. "BLUE") or a
    /// `#RRGGBB` hex; nil when ungrouped. Resolve via ``TaskColorResolver`` —
    /// NOT always a hex.
    let groupColorHex: String?
    let title: String
    let notes: String?
    let startAt: Date?
    let endAt: Date?
    let isAllDay: Bool
    let timezone: String
    /// True when the matched task is a recurring series (`startAt` is its anchor).
    let isRecurring: Bool

    /// `Identifiable` via the series id, so a `List`/`ForEach` of hits is stable.
    var id: String { taskId }
}

// MARK: - Delta sync (Phase 3)

/// A changed `TaskOccurrenceException` row, returned by `GET /tasks/changes`.
///
/// The delta only needs `originalStartAt` (the stable instance key) to decide
/// which month window to invalidate so the next per-window sync re-pulls and
/// re-expands the affected occurrence.
///
/// `originalStartAt` is decoded as a `String` (not a `Date`) on purpose: the
/// exception key carries millisecond precision, but the shared `APIClient`
/// decoder uses the no-fractional-seconds `.iso8601` strategy, so a `Date` here
/// could fail the whole-response decode on a fractional-seconds timestamp. The
/// raw string is parsed leniently at the call site via
/// `CalendarStore.isoFractional`.
struct TaskOccurrenceExceptionDTO: Codable, Sendable {
    let id: String
    /// Parent series id (== `TaskDTO.id`).
    let taskId: String
    /// Stable instance key — the original (pre-override) start, ISO-8601 string.
    let originalStartAt: String
    /// Overridden (moved) start, when this exception rescheduled the occurrence —
    /// the delta invalidates BOTH the original month and this destination month.
    /// ISO-8601 string; nil when the occurrence was not moved. Decoded leniently
    /// (parsed at the call site via `CalendarStore.isoFractional`).
    let overrideStartAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, taskId, originalStartAt, overrideStartAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        taskId = try container.decode(String.self, forKey: .taskId)
        originalStartAt = try container.decode(String.self, forKey: .originalStartAt)
        overrideStartAt = try container.decodeIfPresent(String.self, forKey: .overrideStartAt)
    }
}

/// Response from `GET /sync/state` — the cheap per-user "did anything change?"
/// check. The client compares `revision` to its last-seen value: different ⇒ run
/// the delta pull; equal ⇒ skip the network round-trip. `revision` is an opaque
/// equality token (a bigint serialized as a string), `"0"` before any mutation.
struct SyncStateDTO: Codable, Sendable {
    let revision: String
    let changedAt: String?
    let serverTime: String
}

/// Response from `GET /tasks/changes?calendarId=&since=<cursor>`.
///
/// Precise change-detection delta: everything that changed for the calendar since
/// the client's last `serverTime` cursor.
///
/// - `tasks` — changed task *series* (`updatedAt > since`), each with its full
///   embedded `recurrence` rule when present. The client does NOT expand the rule
///   itself; it invalidates the overlapping window memos so the next `GET /tasks`
///   re-pulls and re-expands.
/// - `deleted` — series ids soft-deleted since `since` (visible via the backend's
///   `withDeleted` query); the client tombstone-deletes all local rows for each.
/// - `exceptions` — changed occurrence exceptions; each invalidates the month
///   window containing its `originalStartAt`.
/// - `serverTime` — the server-clock timestamp that becomes the next opaque
///   cursor. Stored verbatim; never parsed by the client.
struct ChangesResponse: Codable, Sendable {
    let tasks: [TaskDTO]
    let deleted: [String]
    let exceptions: [TaskOccurrenceExceptionDTO]
    let serverTime: String
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
    /// Group default completion requirement inherited by tasks (task-wins); nil
    /// means unset. Decodes an absent key as nil.
    let requiresCompletion: Bool?
    let defaultRecurrenceRuleId: String?
    /// Full embedded group-level default recurrence rule.
    let recurrence: RecurrenceRuleDTO?
    let defaultNotificationStrategyId: String?
    let createdAt: Date
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id, calendarId, name, color, icon, sortOrder, requiresCompletion
        case defaultRecurrenceRuleId, recurrence, defaultNotificationStrategyId
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        calendarId = try container.decode(String.self, forKey: .calendarId)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        requiresCompletion = try container.decodeIfPresent(Bool.self, forKey: .requiresCompletion)
        defaultRecurrenceRuleId = try container.decodeIfPresent(String.self, forKey: .defaultRecurrenceRuleId)
        recurrence = try container.decodeIfPresent(RecurrenceRuleDTO.self, forKey: .recurrence)
        defaultNotificationStrategyId = try container.decodeIfPresent(String.self, forKey: .defaultNotificationStrategyId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

/// Request payload for `POST /task-groups`.
struct CreateTaskGroupRequest: Codable, Sendable {
    let calendarId: String
    let name: String
    let color: String?
    let icon: String?
    let sortOrder: Int?
    /// Group default completion requirement inherited by tasks (task-wins).
    /// Defaulted so existing call sites stay source-compatible.
    var requiresCompletion: Bool? = nil
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
    /// Group default completion requirement. A ``FieldUpdate`` so the editor can
    /// clear it (`.clear` → explicit JSON `null`, the group then inherits the
    /// default) versus leaving it untouched (`.unchanged` → key omitted).
    var requiresCompletion: FieldUpdate<Bool> = .unchanged
    var recurrence: FieldUpdate<RecurrenceRuleInput> = .unchanged

    private enum CodingKeys: String, CodingKey {
        case name, color, icon, sortOrder, requiresCompletion, recurrence
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(sortOrder, forKey: .sortOrder)
        try requiresCompletion.encode(into: &container, forKey: .requiresCompletion)
        try recurrence.encode(into: &container, forKey: .recurrence)
    }
}

/// Request payload for `POST /task-groups/reorder` (M5). `groupIds` is the
/// complete, ordered list of group ids whose position changed; the server assigns
/// each row a `sortOrder` equal to its array index, transactionally.
struct ReorderTaskGroupsRequest: Codable, Sendable {
    let groupIds: [String]
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

// MARK: - Assistant parse (quick-create)

/// Request payload for `POST /assistant/parse` (D4) — one line of natural
/// language the quick-create well sends to be turned into a structured task
/// draft WITHOUT creating anything.
struct ParseTaskRequest: Codable, Sendable {
    let text: String
}

/// Response from `POST /assistant/parse` (D4) — the structured task DRAFT the
/// assistant extracted from one line of natural language. A draft only: no task
/// is created. The quick-create well pre-fills its fields from this and lets the
/// user confirm/edit before a real `POST /tasks`.
///
/// `start` is an ISO-8601 datetime resolved in the user's timezone (absent for a
/// timeless todo). It is decoded as a `String?` rather than a `Date` to avoid
/// coupling to the shared decoder's `.iso8601` (no-fractional-seconds) strategy,
/// which would fail the whole decode on a fractional-seconds timestamp; parse it
/// leniently at the call site. `durationMinutes`, `recurrence`, and `groupId` are
/// present only when the text implied them.
struct TaskDraftDTO: Codable, Sendable {
    let title: String
    /// ISO-8601 start datetime resolved in the user timezone, or nil for a
    /// timeless todo. Display-only string (see type doc).
    let start: String?
    let durationMinutes: Int?
    /// Recurrence rule, present only when the text stated a repeat.
    let recurrence: RecurrenceRuleInput?
    /// Id of an EXISTING group the draft was matched to, nil when none applied.
    let groupId: String?
}

// MARK: - User account & settings

/// Response from `GET`/`PATCH /users/me/settings` (D8). The signed-in user's
/// mutable account settings the Settings screen reads and round-trips. `timezone`
/// is the IANA zone every time-of-day-local computation resolves against;
/// `displayName` / `avatarBase64` are editable post sign-in; `morningBriefEnabled`
/// / `eveningRecapEnabled` are the cross-device notification opt-ins.
struct UserSettingsDTO: Codable, Sendable, Equatable {
    let timezone: String
    let displayName: String?
    /// Base64-encoded profile picture (no data-URL prefix); nil when unset.
    let avatarBase64: String?
    let morningBriefEnabled: Bool
    let eveningRecapEnabled: Bool
}

/// Request payload for `PATCH /users/me/settings` (D8). Every field is optional —
/// send only what changed; omitted keys leave the stored value unchanged.
/// `displayName` is trimmed + non-empty server-side; `avatarBase64` is a bare
/// base64 image (no data-URL prefix).
struct UpdateUserSettingsRequest: Codable, Sendable {
    var timezone: String? = nil
    var displayName: String? = nil
    var avatarBase64: String? = nil
    var morningBriefEnabled: Bool? = nil
    var eveningRecapEnabled: Bool? = nil
}

// MARK: - Device (APNs)

/// Supported push-token platform. Mirrors the backend `DevicePlatform` exactly.
/// Lowercase raw values match the wire contract (`"ios"`, not `"IOS"`).
nonisolated enum DevicePlatform: String, Codable, CaseIterable, Sendable {
    case ios
    case ipados
    case macos
}

/// Server representation of a registered device, returned by
/// `POST /users/me/devices` (S2). Omits the owning user (implicit from the authed
/// caller). `token` is the opaque APNs device token.
struct DeviceDTO: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let token: String
    let platform: DevicePlatform
    let lastSeenAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

/// Request payload for `POST /users/me/devices` (S2) — registers (upserts) an
/// APNs device token for the current user. Idempotent server-side.
struct RegisterDeviceRequest: Codable, Sendable {
    let token: String
    let platform: DevicePlatform
}

// MARK: - Daily report settings & brief

/// Response from `GET`/`PATCH /users/me/report-settings` (ADR 0046). The Settings
/// screen reads this to render the report toggle, time picker, and channel.
/// `reportTimeLocal` is a 24-hour `HH:mm` wall-clock string in the user timezone.
struct ReportSettingsDTO: Codable, Sendable, Equatable {
    let enabled: Bool
    /// Local wall-clock send time as `HH:mm` (24-hour), in the user timezone.
    let reportTimeLocal: String
    /// Preferred delivery channel. NOTE: push delivery is deferred — a `.push`
    /// value persists but Telegram delivers today regardless.
    let channel: NotificationChannel
}

/// Request payload for `PATCH /users/me/report-settings` (ADR 0046). Both fields
/// optional — send only what changed. `reportTimeLocal` must be a 24-hour `HH:mm`.
struct UpdateReportSettingsRequest: Codable, Sendable {
    var enabled: Bool? = nil
    var reportTimeLocal: String? = nil
    var channel: NotificationChannel? = nil
}

/// Response from `GET /users/me/daily-brief` (D2). The generated morning-brief
/// text the today card renders, plus the resolved local date it covers. `brief`
/// is nil when generation produced nothing usable for the day.
struct DailyBriefDTO: Codable, Sendable, Equatable {
    let brief: String?
    /// The local date (`YYYY-MM-DD`, in the user timezone) the brief covers.
    let localDate: String
}

// MARK: - Brief configuration

/// Response from `GET`/`PATCH`/`DELETE /users/me/brief-settings`. The user's
/// custom brief prompt that shapes how the daily brief is written; `customPrompt`
/// is nil when no override is set (the brief falls back to the default voice).
struct BriefSettingsDTO: Codable, Sendable, Equatable {
    /// The custom brief instruction text, or nil when the default is in effect.
    let customPrompt: String?
}

/// Request payload for `PATCH /users/me/brief-settings` — sets (or clears, via an
/// explicit `null`) the user's custom brief prompt. Mirrors the shared contract's
/// `{ customPrompt: string | null }` shape.
struct UpdateBriefSettingsRequest: Codable, Sendable {
    let customPrompt: String?
}

// MARK: - AI persona

/// Provenance of the active persona. Mirrors the backend `PersonaPromptSource`
/// exactly (lowercase wire values).
nonisolated enum PersonaPromptSource: String, Codable, CaseIterable, Sendable {
    case preset
    case custom
}

/// Response from `GET`/`PATCH`/`DELETE /users/me/persona-settings` (Story 18 /
/// ADR 0014). The active persona the assistant adopts: the user's own custom text
/// when set, else the seeded "Jarvis" preset. `source` tells the screen which it
/// is; `presetName` is the preset's display name when applicable.
struct PersonaSettingsDTO: Codable, Sendable, Equatable {
    /// The active persona instruction text the assistant adopts.
    let promptText: String
    let source: PersonaPromptSource
    /// Display name when the active persona is a preset, else nil.
    let presetName: String?
}

/// Request payload for `PATCH /users/me/persona-settings` — sets the user's
/// custom persona text (validated non-empty + length-bounded server-side).
struct UpdatePersonaSettingsRequest: Codable, Sendable {
    let promptText: String
}

/// Response from `GET /users/me/persona-presets` (D9) — one curated persona
/// preset the persona screen lists as a pickable starting point. `id` addresses
/// the row; `presetName` is the display label; `promptText` is the full persona
/// instruction text previewed in the editor.
struct PersonaPresetDTO: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let presetName: String
    let promptText: String
}

// MARK: - Shared OK envelope

/// Response from endpoints that reply `200 { ok: true }` (e.g.
/// `DELETE /users/me`, `DELETE /users/me/devices/:token`). A decodable body the
/// client can confirm rather than a bare 204.
struct OkResponse: Codable, Sendable {
    let ok: Bool
}
