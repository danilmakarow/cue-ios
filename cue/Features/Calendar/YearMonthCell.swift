//
//  YearMonthCell.swift
//  cue
//

import SwiftUI

/// Miniature month inside the year grid: the month name above a tiny 7-column
/// day-number grid. Dot-free by design (the year scope shows no events). Acts
/// as the `matchedTransitionSource` for the zoom into the month scope.
struct YearMonthCell: View {
    let monthAnchor: Date
    let namespace: Namespace.ID

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(monthAnchor.formatted(.dateTime.month(.abbreviated)))
                .font(.subheadline.bold())
                .foregroundStyle(isCurrentMonth ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))

            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(CalendarMath.monthGridCells(monthAnchor).enumerated()), id: \.offset) { _, day in
                    if let day {
                        Text(day.formatted(.dateTime.day()))
                            .font(.system(size: 8))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, minHeight: 11)
                            .foregroundStyle(CalendarMath.isToday(day) ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    } else {
                        Color.clear.frame(height: 11)
                    }
                }
            }
        }
        .padding(8)
        .matchedTransitionSource(id: monthAnchor, in: namespace)
    }

    private var isCurrentMonth: Bool {
        CalendarMath.startOfMonth(.now) == monthAnchor
    }
}

#Preview {
    @Previewable @Namespace var namespace
    YearMonthCell(monthAnchor: CalendarMath.startOfMonth(.now), namespace: namespace)
        .frame(width: 110)
}
