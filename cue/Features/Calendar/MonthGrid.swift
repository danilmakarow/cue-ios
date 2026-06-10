//
//  MonthGrid.swift
//  cue
//

import SwiftUI

/// The 7-column day grid for one month. Leading blanks align day 1 under its
/// weekday; each real day is a tappable `MonthDayCell` listing that day's event
/// titles.
struct MonthGrid: View {
    let monthAnchor: Date
    let selectedDate: Date
    /// Event titles per day (`startOfDay` key), ordered by start.
    let titlesByDay: [Date: [String]]
    let namespace: Namespace.ID
    var onSelectDay: (Date) -> Void

    @Environment(ZoomSourceRegistry.self) private var zoomSources

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(CalendarMath.monthGridCells(monthAnchor).enumerated()), id: \.offset) { _, day in
                if let day {
                    MonthDayCell(
                        day: day,
                        isSelected: CalendarMath.isSameDay(day, selectedDate),
                        isToday: CalendarMath.isToday(day),
                        titles: titlesByDay[CalendarMath.startOfDay(day)] ?? [],
                        namespace: namespace
                    )
                    .contentShape(.rect)
                    .onTapGesture { onSelectDay(day) }
                    // Report this day's zoom source as on/off screen so a
                    // programmatic deep-link can wait for it before pushing the
                    // day scope, keeping the interactive zoom-out alive. `day`
                    // is the same value used as the cell's matched-source id.
                    .onAppear { zoomSources.markPresent(day) }
                    .onDisappear { zoomSources.markAbsent(day) }
                } else {
                    Color.clear.frame(minHeight: MonthDayCell.minHeight)
                }
            }
        }
        .padding(.horizontal, 12)
    }
}
