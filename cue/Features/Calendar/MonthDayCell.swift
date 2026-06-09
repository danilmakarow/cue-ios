//
//  MonthDayCell.swift
//  cue
//

import SwiftUI

/// One day in the month grid: the day number with a today/selected background
/// and an event-indicator dot. Acts as the `matchedTransitionSource` for the
/// zoom into the day scope.
///
/// Deliberately dumb: the day number arrives pre-formatted (from
/// `MonthGridModel`) and today/selected arrive as flags, so the cell's `body`
/// does no date math or formatting — it renders constantly while the month
/// list scrolls.
struct MonthDayCell: View {
    let day: Date
    let number: String
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let namespace: Namespace.ID

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
        .matchedTransitionSource(id: day, in: namespace)
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
    @Previewable @Namespace var namespace
    HStack(spacing: 8) {
        MonthDayCell(day: .now, number: "17", isSelected: false, isToday: true, hasEvents: true, namespace: namespace)
        MonthDayCell(day: .now, number: "18", isSelected: true, isToday: false, hasEvents: true, namespace: namespace)
        MonthDayCell(day: .now, number: "19", isSelected: false, isToday: false, hasEvents: false, namespace: namespace)
    }
    .padding()
}
