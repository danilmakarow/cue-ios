//
//  MonthDayCell.swift
//  cue
//

import SwiftUI

/// One day in the month grid: the day number with a today/selected highlight
/// and the day's event titles listed beneath it (Apple-Calendar style), capped
/// with a "+N" overflow row.
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
    /// This day's event titles, ordered by start; listed under the day number.
    let titles: [String]

    /// Most title chips shown before the rest collapse into a "+N" row.
    private static let maxVisibleTitles = 3
    /// Minimum cell height. Also used by the grid's leading blank cells so rows
    /// stay vertically aligned.
    static let minHeight: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            dayNumber

            ForEach(Array(titles.prefix(Self.maxVisibleTitles).enumerated()), id: \.offset) { _, title in
                titleChip(title)
            }

            if titles.count > Self.maxVisibleTitles {
                Text(verbatim: "+\(titles.count - Self.maxVisibleTitles)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Self.minHeight, alignment: .top)
    }

    private var dayNumber: some View {
        Text(number)
            .font(.caption)
            .fontWeight(isToday ? .bold : .regular)
            .monospacedDigit()
            .foregroundStyle(numberColor)
            .frame(width: 24, height: 24)
            .background(dayBackground)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func titleChip(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(.tint.opacity(0.18), in: .rect(cornerRadius: 3))
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
    HStack(alignment: .top, spacing: 8) {
        MonthDayCell(
            number: "17",
            isSelected: false,
            isToday: true,
            titles: ["Standup", "Lunch with David", "Gym", "Call mom"]
        )
        MonthDayCell(number: "18", isSelected: true, isToday: false, titles: ["Review PR"])
        MonthDayCell(number: "19", isSelected: false, isToday: false, titles: [])
    }
    .padding()
}
