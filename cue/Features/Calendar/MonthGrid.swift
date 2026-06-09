//
//  MonthGrid.swift
//  cue
//

import SwiftUI

/// The 7-column day grid for one month. Leading blanks align day 1 under its
/// weekday; each real day is a tappable `MonthDayCell`.
///
/// Renders entirely from a precomputed `MonthGridModel` plus day-key flags —
/// no `Calendar` math or formatting happens here, so realizing a month while
/// the list scrolls stays cheap.
struct MonthGrid: View {
    let model: MonthGridModel
    /// `startOfDay` key of the selected day (drives the selection ring).
    let selectedDayKey: Date
    /// `startOfDay` key of today (drives the today highlight).
    let todayKey: Date
    let daysWithEvents: Set<Date>
    let namespace: Namespace.ID
    var onSelectDay: (Date) -> Void

    @Environment(ZoomSourceRegistry.self) private var zoomSources

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(model.cells.enumerated()), id: \.offset) { _, cell in
                if let cell {
                    MonthDayCell(
                        day: cell.date,
                        number: cell.number,
                        isSelected: cell.date == selectedDayKey,
                        isToday: cell.date == todayKey,
                        hasEvents: daysWithEvents.contains(cell.date),
                        namespace: namespace
                    )
                    .contentShape(.rect)
                    .onTapGesture { onSelectDay(cell.date) }
                    // Report this day's zoom source as on/off screen so a
                    // programmatic deep-link can wait for it before pushing the
                    // day scope, keeping the interactive zoom-out alive. The
                    // date is the same value used as the cell's matched-source id.
                    .onAppear { zoomSources.markPresent(cell.date) }
                    .onDisappear { zoomSources.markAbsent(cell.date) }
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 12)
    }
}
