//
//  APIClient+Resources.swift
//  cue
//

import Foundation

/// Typed resource methods over the generic `get`/`post`/`patch`/`delete` verbs.
///
/// These wrap the raw paths + query construction the feature stores would
/// otherwise repeat, so each call site reads as a single intent
/// (`api.searchTasks(q:)`) and the path/contract lives in exactly one place. They
/// add no transport behavior — bearer auth, `APIError` envelope parsing, and the
/// ISO-8601 coders all come from the underlying verbs. Every method is
/// `nonisolated` to match the verbs, so they're callable from any isolation.
extension APIClient {
    // MARK: - Tasks

    /// Searches the signed-in user's tasks by text via `GET /tasks/search` (M1).
    /// Case-insensitive over title + notes across ALL the user's calendars (NOT
    /// window-bound). `groupId` narrows to a single group; `limit` caps the result
    /// count (server default 25, clamped to 50). Returns the matched series rows
    /// (a recurring match returns its anchor).
    ///
    /// - Parameters:
    ///   - query: the search term (sent as `q`; the server trims it).
    ///   - groupId: optional group to narrow to.
    ///   - limit: optional max matches (1…50).
    nonisolated func searchTasks(
        q query: String,
        groupId: String? = nil,
        limit: Int? = nil
    ) async throws -> [TaskSearchResultDTO] {
        var items = [URLQueryItem(name: "q", value: query)]
        if let groupId {
            items.append(URLQueryItem(name: "groupId", value: groupId))
        }
        if let limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        return try await get("/tasks/search", queryItems: items)
    }

    // MARK: - Task groups

    /// Bulk-reorders the user's task groups via `POST /task-groups/reorder` (M5).
    /// `orderedIds` is the complete, ordered list of group ids whose position
    /// changed; the server assigns each a `sortOrder` equal to its index,
    /// transactionally. Returns the updated groups in their new order.
    ///
    /// - Parameter orderedIds: the group ids in their intended display order.
    nonisolated func reorderGroups(orderedIds: [String]) async throws -> [TaskGroupDTO] {
        try await post("/task-groups/reorder", body: ReorderTaskGroupsRequest(groupIds: orderedIds))
    }

    // MARK: - User account & settings

    /// Fetches the signed-in user's account settings via `GET /users/me/settings`.
    nonisolated func userSettings() async throws -> UserSettingsDTO {
        try await get("/users/me/settings")
    }

    /// Updates the signed-in user's account settings via
    /// `PATCH /users/me/settings` (D8) and returns the persisted shape. Send only
    /// the changed fields on `request`; omitted keys are left unchanged.
    nonisolated func updateUserSettings(
        _ request: UpdateUserSettingsRequest
    ) async throws -> UserSettingsDTO {
        try await patch("/users/me/settings", body: request)
    }

    /// Permanently deletes the signed-in user's account via `DELETE /users/me`
    /// (S5) — cascade-purges the user aggregate and revokes the Apple refresh
    /// token. Resolves on the `200 { ok: true }` confirmation.
    nonisolated func deleteAccount() async throws {
        let _: OkResponse = try await delete("/users/me")
    }

    // MARK: - Devices (APNs)

    /// Registers (upserts) an APNs device token for the current user via
    /// `POST /users/me/devices` (S2). Idempotent server-side: re-posting a known
    /// token refreshes it rather than duplicating.
    ///
    /// - Parameters:
    ///   - token: the opaque APNs device token issued to the client.
    ///   - platform: the platform the token was issued on.
    nonisolated func registerDevice(
        token: String,
        platform: DevicePlatform
    ) async throws -> DeviceDTO {
        try await post(
            "/users/me/devices",
            body: RegisterDeviceRequest(token: token, platform: platform)
        )
    }

    /// Unregisters an APNs device token for the current user via
    /// `DELETE /users/me/devices/:token`. Resolves on the `200 { ok: true }`
    /// confirmation. The token is path-escaped for the URL.
    ///
    /// - Parameter token: the APNs device token to remove.
    nonisolated func unregisterDevice(token: String) async throws {
        let escaped = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
        let _: OkResponse = try await delete("/users/me/devices/\(escaped)")
    }

    // MARK: - Daily report

    /// Fetches the daily report settings via `GET /users/me/report-settings`
    /// (ADR 0046). Creates a default (off, `08:00`) on the first read server-side.
    nonisolated func reportSettings() async throws -> ReportSettingsDTO {
        try await get("/users/me/report-settings")
    }

    /// Updates the daily report settings via `PATCH /users/me/report-settings`
    /// (ADR 0046) and returns the persisted shape. Send only the changed fields.
    nonisolated func updateReportSettings(
        _ request: UpdateReportSettingsRequest
    ) async throws -> ReportSettingsDTO {
        try await patch("/users/me/report-settings", body: request)
    }

    /// Fetches the daily brief via `GET /users/me/daily-brief` (D2). `date` is an
    /// optional local `YYYY-MM-DD` (user timezone); omit for today. Served from a
    /// per-day cache; `brief` is nil when the day yielded nothing usable.
    ///
    /// - Parameter date: optional local `YYYY-MM-DD` to brief on; defaults to today.
    nonisolated func dailyBrief(date: String? = nil) async throws -> DailyBriefDTO {
        var items: [URLQueryItem] = []
        if let date {
            items.append(URLQueryItem(name: "date", value: date))
        }
        return try await get("/users/me/daily-brief", queryItems: items)
    }

    // MARK: - Assistant (quick-create parse)

    /// Parses one line of natural language into a structured task DRAFT via
    /// `POST /assistant/parse` (D4). No task is created — the quick-create well
    /// pre-fills its fields from the returned draft for the user to confirm.
    ///
    /// - Parameter text: a single line of natural language describing a task.
    nonisolated func parseTask(text: String) async throws -> TaskDraftDTO {
        try await post("/assistant/parse", body: ParseTaskRequest(text: text))
    }

    // MARK: - AI persona

    /// Lists the curated AI persona presets via `GET /users/me/persona-presets`
    /// (D9) the persona screen offers as pickable starting points.
    nonisolated func listPersonaPresets() async throws -> [PersonaPresetDTO] {
        try await get("/users/me/persona-presets")
    }

    /// Resets the user's custom persona back to the seeded preset via
    /// `DELETE /users/me/persona-settings` (D9) and returns the now-active
    /// persona. Idempotent: succeeds whether or not a custom persona was set.
    nonisolated func resetPersona() async throws -> PersonaSettingsDTO {
        try await delete("/users/me/persona-settings")
    }
}
