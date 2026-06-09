//
//  MonthDayCell.swift
//  cue
//

import SwiftUI

/// One day in the month grid: the day number with a today/selected background
/// and an event-indicator dot.
///
/// Deliberately dumb: the day number arrives pre-formatted (from
/// `MonthGridModel`) and today/selected arrive as flags, so the cell's `body`
/// does no date math or formatting — it renders constantly while the month
/// list scrolls. Zoom anchoring is handled by the parent grid's frame
/// reporting, not by the cell.
struct MonthDayCell: View {
    let number: String
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(number)
                .font(.callout)
                .fontWeight(isToday ? .bold : .regular)
                .monospacedDigit()
                .foregroundStyle(numberColor)
                .frame(width: 34, height: 34)
                .background(dayBackground)

            Circle()
                .fill(hasEvents ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear))
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }

    @ViewBuilder
    private var dayBackground: some View {
        if isToday {
            Circle().fill(.red)
        } else if isSelected {
            Circle().fill(Color.secondary.opacity(0.25))
        }
    }

    private var numberColor: AnyShapeStyle {
        if isToday { return AnyShapeStyle(.white) }
        return AnyShapeStyle(.primary)
    }
}

#Preview {
    HStack(spacing: 8) {
        MonthDayCell(number: "17", isSelected: false, isToday: true, hasEvents: true)
        MonthDayCell(number: "18", isSelected: true, isToday: false, hasEvents: true)
        MonthDayCell(number: "19", isSelected: false, isToday: false, hasEvents: false)
    }
    .padding()
}
