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
///
/// Each day cell reports its frame (in the zoom container's coordinate space)
/// to the `ScopeFrameRegistry`, which is how a day ↔ month zoom finds its
/// anchor cell and how a pinch-open picks the day under the fingers. The
/// registry is a plain store — writes don't invalidate any view.
struct MonthGrid: View {
    let model: MonthGridModel
    /// `startOfDay` key of the selected day (drives the selection ring).
    let selectedDayKey: Date
    /// `startOfDay` key of today (drives the today highlight).
    let todayKey: Date
    let daysWithEvents: Set<Date>
    var onSelectDay: (Date) -> Void

    @Environment(ScopeFrameRegistry.self) private var frames

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(model.cells.enumerated()), id: \.offset) { _, cell in
                if let cell {
                    MonthDayCell(
                        number: cell.number,
                        isSelected: cell.date == selectedDayKey,
                        isToday: cell.date == todayKey,
                        hasEvents: daysWithEvents.contains(cell.date)
                    )
                    .contentShape(.rect)
                    .onTapGesture { onSelectDay(cell.date) }
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .named(ScopeFrameRegistry.coordinateSpaceName))
                    } action: { frame in
                        frames.setDayFrame(frame, for: cell.date)
                    }
                    .onDisappear { frames.clearDayFrame(for: cell.date) }
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 12)
    }
}
