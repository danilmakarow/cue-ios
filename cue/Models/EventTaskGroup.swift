//
//  EventTaskGroup.swift
//  cue
//

import Foundation
import SwiftData

/// On-device task group. Mirrors `TaskGroupDTO`; named `EventTaskGroup` to avoid
/// any ambiguity with Swift's standard `TaskGroup`. Follows the same pattern as
/// `EventCalendar`.
@Model
final class EventTaskGroup {
    @Attribute(.unique) var id: String
    var calendarId: String
    var name: String
    /// Group color: a `TaskColor` preset name (e.g. "BLUE") or a `#RRGGBB` hex.
    /// Resolve via `TaskColorResolver` — despite the legacy property name, this is
    /// NOT always a hex.
    var colorHex: String?
    var icon: String?
    var sortOrder: Int
    /// Group default completion requirement inherited by tasks (task-wins); nil
    /// when unset. Previously dropped client-side (M5).
    var requiresCompletion: Bool?
    /// Backend id of the group's default recurrence rule (nil when none).
    var defaultRecurrenceRuleId: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        calendarId: String,
        name: String = "",
        colorHex: String? = nil,
        icon: String? = nil,
        sortOrder: Int = 0,
        requiresCompletion: Bool? = nil,
        defaultRecurrenceRuleId: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.calendarId = calendarId
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.sortOrder = sortOrder
        self.requiresCompletion = requiresCompletion
        self.defaultRecurrenceRuleId = defaultRecurrenceRuleId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension EventTaskGroup {
    /// Inserts (or updates in place) the group matching `dto.id`.
    @discardableResult
    static func upsert(from dto: TaskGroupDTO, in context: ModelContext) -> EventTaskGroup {
        let id = dto.id
        let descriptor = FetchDescriptor<EventTaskGroup>(predicate: #Predicate { $0.id == id })

        let group: EventTaskGroup
        if let existing = (try? context.fetch(descriptor))?.first {
            group = existing
        } else {
            group = EventTaskGroup(id: dto.id, calendarId: dto.calendarId)
            context.insert(group)
        }

        group.calendarId = dto.calendarId
        group.name = dto.name
        group.colorHex = dto.color
        group.icon = dto.icon
        group.sortOrder = dto.sortOrder
        group.requiresCompletion = dto.requiresCompletion
        group.defaultRecurrenceRuleId = dto.defaultRecurrenceRuleId
        group.createdAt = dto.createdAt
        group.updatedAt = dto.updatedAt
        return group
    }
}
