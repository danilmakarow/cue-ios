//
//  MonthPage.swift
//  cue
//

import SwiftData
import SwiftUI

/// A single month in the month scope: month heading + `MonthGrid`. Owns the
/// `@Query` for this month's tasks (configured from the month bounds in its
/// init — the dynamic-query pattern) and groups them by day into ordered title
/// lists, which the grid shows under each day number.
struct MonthPage: View {
    let monthAnchor: Date
    let selectedDate: Date
    var onSelectDay: (Date) -> Void

    @Query private var tasks: [TaskItem]

    init(monthAnchor: Date, selectedDate: Date, onSelectDay: @escaping (Date) -> Void) {
        self.monthAnchor = monthAnchor
        self.selectedDate = selectedDate
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

        VStack(alignment: .leading, spacing: 12) {
            Text(heading(for: model, todayKey: todayKey))
                .font(.title2.bold())
                .padding(.horizontal, 16)

            MonthGrid(
                model: model,
                selectedDayKey: CalendarMath.startOfDay(selectedDate),
                todayKey: todayKey,
                titlesByDay: eventTitlesByDay(),
                onSelectDay: onSelectDay
            )
        }
    }

    /// Groups this month's tasks by day (`startOfDay` key), each day's titles
    /// ordered by occurrence start, so the grid can list them under the day
    /// number instead of a single dot. The query is already month-bounded, so
    /// this is cheap array work over a handful of rows.
    private func eventTitlesByDay() -> [Date: [String]] {
        let entries = tasks.compactMap { task -> (day: Date, start: Date, title: String)? in
            guard let start = task.occurrenceStart else { return nil }
            return (CalendarMath.startOfDay(start), start, task.title)
        }
        return Dictionary(grouping: entries, by: \.day)
            .mapValues { dayEntries in dayEntries.sorted { $0.start < $1.start }.map(\.title) }
    }

    /// "May" within the current year; "May 2027" elsewhere, so the year is
    /// clear while scrolling across year boundaries.
    private func heading(for model: MonthGridModel, todayKey: Date) -> String {
        let currentYear = Calendar.current.component(.year, from: todayKey)
        return model.year == currentYear ? model.nameWide : model.nameWideWithYear
    }
}
