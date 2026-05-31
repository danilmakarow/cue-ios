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

// MARK: - Task (event)

/// Server representation of a task/event. Named `TaskDTO` to avoid collision
/// with Swift concurrency's `Task`.
struct TaskDTO: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let calendarId: String
    let title: String
    let notes: String?
    let startAt: Date?
    let endAt: Date?
    let isAllDay: Bool
    let timezone: String
    let requiresCompletion: Bool
    let completedAt: Date?
    let recurrenceRuleId: String?
    let notificationStrategyId: String?
    let createdAt: Date
    let updatedAt: Date
}

/// Request payload for `POST /tasks`.
struct CreateTaskRequest: Codable, Sendable {
    let calendarId: String
    let title: String
    let notes: String?
    let startAt: Date?
    let endAt: Date?
    let isAllDay: Bool
    let timezone: String
    let requiresCompletion: Bool
}

/// Request payload for `PATCH /tasks/:id` — toggle completion.
/// BE sets `completedAt = now` on true, clears it on false.
struct UpdateTaskCompletionRequest: Codable, Sendable {
    let isCompleted: Bool
}
