//
//  MonthGrid.swift
//  cue
//

import SwiftUI

/// The 7-column day grid for one month. Leading blanks align day 1 under its
/// weekday; each real day is a tappable `MonthDayCell`.
struct MonthGrid: View {
    let monthAnchor: Date
    let selectedDate: Date
    let daysWithEvents: Set<Date>
    let namespace: Namespace.ID
    var onSelectDay: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(CalendarMath.monthGridCells(monthAnchor).enumerated()), id: \.offset) { _, day in
                if let day {
                    MonthDayCell(
                        day: day,
                        isSelected: CalendarMath.isSameDay(day, selectedDate),
                        isToday: CalendarMath.isToday(day),
                        hasEvents: daysWithEvents.contains(CalendarMath.startOfDay(day)),
                        namespace: namespace
                    )
                    .contentShape(.rect)
                    .onTapGesture { onSelectDay(day) }
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 12)
    }
}
