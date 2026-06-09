//
//  YearPage.swift
//  cue
//

import SwiftUI

/// A single year in the year scope: a large year title above a 3-column grid
/// of the year's twelve `YearMonthCell`s.
struct YearPage: View {
    let yearAnchor: Date
    var onSelectMonth: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        let todayKey = CalendarMath.startOfDay(.now)
        let todayMonth = CalendarMath.startOfMonth(todayKey)

        VStack(alignment: .leading, spacing: 16) {
            Text(yearAnchor.formatted(.dateTime.year()))
                .font(.largeTitle.bold())
                .foregroundStyle(.tint)
                .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(CalendarMath.monthsOfYear(yearAnchor), id: \.self) { monthAnchor in
                    YearMonthCell(
                        model: MonthGridModel.model(for: monthAnchor),
                        todayKey: monthAnchor == todayMonth ? todayKey : nil
                    )
                    .contentShape(.rect)
                    .onTapGesture { onSelectMonth(monthAnchor) }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
