//
//  EventCalendar.swift
//  cue
//

import Foundation
import SwiftData

/// On-device calendar. Mirrors `CalendarDTO` (the BE `Calendar` entity);
/// named `EventCalendar` to avoid colliding with Foundation's `Calendar`.
@Model
final class EventCalendar {
    @Attribute(.unique) var id: String
    var name: String
    var colorHex: String?
    var icon: String?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    /// Tasks belonging to this calendar. Cascade-deletes its tasks; the
    /// inverse is `TaskItem.calendar`.
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.calendar)
    var tasks: [TaskItem] = []

    init(
        id: String,
        name: String = "",
        colorHex: String? = nil,
        icon: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension EventCalendar {
    /// Inserts (or updates in place) the calendar matching `dto.id`.
    @discardableResult
    static func upsert(from dto: CalendarDTO, in context: ModelContext) -> EventCalendar {
        let id = dto.id
        let descriptor = FetchDescriptor<EventCalendar>(predicate: #Predicate { $0.id == id })

        let calendar: EventCalendar
        if let existing = (try? context.fetch(descriptor))?.first {
            calendar = existing
        } else {
            calendar = EventCalendar(id: dto.id)
            context.insert(calendar)
        }

        calendar.name = dto.name
        calendar.colorHex = dto.color
        calendar.icon = dto.icon
        calendar.sortOrder = dto.sortOrder
        calendar.createdAt = dto.createdAt
        calendar.updatedAt = dto.updatedAt
        return calendar
    }
}
