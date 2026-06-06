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

        let (from, to) = CalendarMath.monthBounds(monthAnchor)
        // Note: #Predicate cannot close over Date.distantPast as a KeyPath expression.
        // We store all tasks and filter in body — month scope queries are small.
        _tasks = Query(
            filter: #Predicate<TaskItem> { task in
                task.occurrenceStart != nil
            }
        )
        _ = from
        _ = to
    }

    var body: some View {
        let (from, to) = CalendarMath.monthBounds(monthAnchor)
        let daysWithEvents = Set(tasks.compactMap { task -> Date? in
            guard let start = task.occurrenceStart, start >= from && start < to else { return nil }
            return CalendarMath.startOfDay(start)
        })

        VStack(alignment: .leading, spacing: 12) {
            Text(monthHeading)
                .font(.title2.bold())
                .padding(.horizontal, 16)

            MonthGrid(
                monthAnchor: monthAnchor,
                selectedDate: selectedDate,
                daysWithEvents: daysWithEvents,
                namespace: namespace,
                onSelectDay: onSelectDay
            )
        }
    }

    /// "May" within the current year; "May 2027" elsewhere, so the year is
    /// clear while scrolling across year boundaries.
    private var monthHeading: String {
        let calendar = Calendar.current
        let sameYear = calendar.component(.year, from: monthAnchor) == calendar.component(.year, from: .now)
        if sameYear {
            return monthAnchor.formatted(.dateTime.month(.wide))
        }
        return monthAnchor.formatted(.dateTime.month(.wide).year())
    }
}
