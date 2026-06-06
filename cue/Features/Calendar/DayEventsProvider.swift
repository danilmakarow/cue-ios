//
//  DayEventsProvider.swift
//  cue
//

import SwiftData
import SwiftUI

/// Bridges SwiftData to the existing day-page views. Queries one day's occurrences,
/// maps them to the lightweight `ScheduleEvent` value type, and renders either
/// `TimelineDayPage` or `ListDayPage` per the store's current `viewMode`.
///
/// The day pages keep their unchanged `(date, events, onToggleCompletion, onSelect)` —
/// this provider is the only thing that knows about SwiftData.
struct DayEventsProvider: View {
    let date: Date
    /// Called when the user taps an event card (not the completion toggle).
    var onSelect: (ScheduleEvent) -> Void = { _ in }

    @Environment(CalendarStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]

    init(date: Date, onSelect: @escaping (ScheduleEvent) -> Void = { _ in }) {
        self.date = date
        self.onSelect = onSelect
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let sentinel = Date.distantPast
        _tasks = Query(
            filter: #Predicate<TaskItem> { task in
                (task.occurrenceStart ?? sentinel) >= dayStart &&
                (task.occurrenceStart ?? sentinel) < dayEnd
            },
            sort: \.occurrenceStart
        )
    }

    var body: some View {
        let events = tasks.compactMap { $0.asScheduleEvent() }
        let toggle: (ScheduleEvent) -> Void = { event in
            guard let task = tasks.first(where: { $0.occurrenceKey == event.id }) else { return }
            Task { await store.toggleCompletion(task, context: modelContext) }
        }

        switch store.viewMode {
        case .timeline:
            TimelineDayPage(
                date: date,
                events: events,
                onToggleCompletion: toggle,
                onSelect: onSelect
            )
        case .list:
            ListDayPage(
                date: date,
                events: events,
                onToggleCompletion: toggle,
                onSelect: onSelect
            )
        }
    }
}
