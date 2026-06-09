//
//  MonthPage.swift
//  cue
//

import SwiftData
import SwiftUI

/// A single month in the month scope: month heading + `MonthGrid`. Owns the
/// `@Query` for this month's tasks (configured from the month bounds in its
/// init — the dynamic-query pattern) and reduces them to the set of days that
/// have events, which drives each day cell's dot.
struct MonthPage: View {
    let monthAnchor: Date
    let selectedDate: Date
    let namespace: Namespace.ID
    var onSelectDay: (Date) -> Void

    @Query private var tasks: [TaskItem]

    init(monthAnchor: Date, selectedDate: Date, namespace: Namespace.ID, onSelectDay: @escaping (Date) -> Void) {
        self.monthAnchor = monthAnchor
        self.selectedDate = selectedDate
        self.namespace = namespace
        self.onSelectDay = onSelectDay

        // Bound the query to this month's window so each realized page fetches
        // (and re-fetches, on any context save) only its own handful of rows —
        // never the whole table. #Predicate can't reference `Date.distantPast`
        // as a key path, but coalescing through a captured local works.
        let (from, to) = CalendarMath.monthBounds(monthAnchor)
        let sentinel = Date.distantPast
        _tasks = Query(
            filter: #Predicate<TaskItem> { task in
                (task.occurrenceStart ?? sentinel) >= from &&
                (task.occurrenceStart ?? sentinel) < to
            }
        )
    }

    var body: some View {
        let model = MonthGridModel.model(for: monthAnchor)
        let todayKey = CalendarMath.startOfDay(.now)
        let daysWithEvents = Set(tasks.compactMap { task in
            task.occurrenceStart.map(CalendarMath.startOfDay)
        })

        VStack(alignment: .leading, spacing: 12) {
            Text(heading(for: model, todayKey: todayKey))
                .font(.title2.bold())
                .padding(.horizontal, 16)

            MonthGrid(
                model: model,
                selectedDayKey: CalendarMath.startOfDay(selectedDate),
                todayKey: todayKey,
                daysWithEvents: daysWithEvents,
                namespace: namespace,
                onSelectDay: onSelectDay
            )
        }
    }

    /// "May" within the current year; "May 2027" elsewhere, so the year is
    /// clear while scrolling across year boundaries.
    private func heading(for model: MonthGridModel, todayKey: Date) -> String {
        let currentYear = Calendar.current.component(.year, from: todayKey)
        return model.year == currentYear ? model.nameWide : model.nameWideWithYear
    }
}
