//
//  DayEventsProvider.swift
//  cue
//

import SwiftUI

/// Pure value-driven router for a single day page: renders either `TimelineDayPage`
/// or `ListDayPage` for the given `viewMode`, from an already-resolved `events`
/// slice. It owns **no** SwiftData query — `CalendarView` runs one windowed `@Query`,
/// buckets the results by day, and hands each page its slice. Realizing or
/// recycling a page therefore costs nothing in the data layer.
struct DayEventsProvider: View {
    let date: Date
    let events: [ScheduleEvent]
    let viewMode: CalendarViewMode
    /// Called when the user taps an event's completion checkbox.
    var onToggle: (ScheduleEvent) -> Void = { _ in }
    /// Called when the user taps an event card (not the completion toggle).
    var onSelect: (ScheduleEvent) -> Void = { _ in }

    var body: some View {
        switch viewMode {
        case .timeline:
            TimelineDayPage(
                date: date,
                events: events,
                onToggleCompletion: onToggle,
                onSelect: onSelect
            )
        case .list:
            ListDayPage(
                date: date,
                events: events,
                onToggleCompletion: onToggle,
                onSelect: onSelect
            )
        }
    }
}
