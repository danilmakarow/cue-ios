//
//  MonthPage.swift
//  cue
//

import SwiftData
import SwiftUI

/// A single month in the month scope: month heading + `MonthGrid`. Owns the
/// `@Query` for this month's tasks and groups them by day into ordered title
/// lists, which the grid shows under each day number.
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

        // Note: #Predicate cannot close over Date.distantPast as a KeyPath
        // expression. We fetch all occurrence-bearing tasks and filter to the
        // month in body — month scope queries are small.
        _tasks = Query(
            filter: #Predicate<TaskItem> { task in
                task.occurrenceStart != nil
            }
        )
    }

    var body: some View {
        let (from, to) = CalendarMath.monthBounds(monthAnchor)
        let titlesByDay = eventTitlesByDay(from: from, to: to)

        VStack(alignment: .leading, spacing: 12) {
            Text(monthHeading)
                .font(.title2.bold())
                .padding(.horizontal, 16)

            MonthGrid(
                monthAnchor: monthAnchor,
                selectedDate: selectedDate,
                titlesByDay: titlesByDay,
                namespace: namespace,
                onSelectDay: onSelectDay
            )
        }
    }

    /// Groups this month's tasks by day (`startOfDay` key), each day's titles
    /// ordered by occurrence start, so the grid can list them under the day
    /// number instead of a single dot.
    private func eventTitlesByDay(from: Date, to: Date) -> [Date: [String]] {
        let monthTasks = tasks.compactMap { task -> (day: Date, start: Date, title: String)? in
            guard let start = task.occurrenceStart, start >= from, start < to else { return nil }
            return (CalendarMath.startOfDay(start), start, task.title)
        }
        return Dictionary(grouping: monthTasks, by: \.day)
            .mapValues { entries in entries.sorted { $0.start < $1.start }.map(\.title) }
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
