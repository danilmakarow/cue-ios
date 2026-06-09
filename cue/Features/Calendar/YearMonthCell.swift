//
//  YearMonthCell.swift
//  cue
//

import SwiftUI

/// Miniature month inside the year grid: the month name above a tiny 7-column
/// day-number grid. Dot-free by design (the year scope shows no events).
///
/// The day numbers are drawn with a single `Canvas` instead of ~37 laid-out
/// `Text` views: a year page realizes twelve of these at once mid-scroll, and
/// the view-tree version (~450 views + ~450 format calls per page) was the
/// main frame-drop source in the year scope. All strings come pre-formatted
/// from `MonthGridModel`.
///
/// Reports its frame to the `ScopeFrameRegistry`, which is how a month ↔ year
/// zoom finds its anchor cell and how a pinch-open picks the month under the
/// fingers.
struct YearMonthCell: View {
    let model: MonthGridModel
    /// Today's `startOfDay` when it falls inside this month, else nil. Doubles
    /// as the "this is the current month" flag for the title tint.
    let todayKey: Date?

    @Environment(ScopeFrameRegistry.self) private var frames

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(model.nameAbbreviated)
                .font(.subheadline.bold())
                .foregroundStyle(todayKey != nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))

            MiniMonthGrid(model: model, todayKey: todayKey)
        }
        .padding(8)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(ScopeFrameRegistry.coordinateSpaceName))
        } action: { frame in
            frames.setMonthFrame(frame, for: model.monthAnchor)
        }
        .onDisappear { frames.clearMonthFrame(for: model.monthAnchor) }
    }
}

/// Canvas-drawn 7-column day-number grid for one mini-month. One view (and
/// one draw pass) regardless of the month's length.
struct MiniMonthGrid: View {
    let model: MonthGridModel
    /// Today's `startOfDay` when it falls inside this month, else nil.
    let todayKey: Date?

    private static let rowHeight: CGFloat = 11

    var body: some View {
        Canvas { context, size in
            let columnWidth = size.width / 7
            for (index, day) in model.days.enumerated() {
                let cell = index + model.leadingBlankCount
                let position = CGPoint(
                    x: (CGFloat(cell % 7) + 0.5) * columnWidth,
                    y: (CGFloat(cell / 7) + 0.5) * Self.rowHeight
                )
                let text = Text(day.number)
                    .font(.system(size: 8))
                    .monospacedDigit()
                    .foregroundStyle(day.date == todayKey ? Color.accentColor : Color.secondary)
                context.draw(context.resolve(text), at: position)
            }
        }
        .frame(height: CGFloat(model.weekRowCount) * Self.rowHeight)
    }
}

#Preview {
    YearMonthCell(
        model: MonthGridModel.model(for: .now),
        todayKey: CalendarMath.startOfDay(.now)
    )
    .frame(width: 110)
    .environment(ScopeFrameRegistry())
}
