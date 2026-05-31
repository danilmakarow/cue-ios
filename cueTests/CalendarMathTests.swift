//
//  CalendarMathTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct CalendarMathTests {
    private let calendar = Calendar.current

    @Test func startOfMonthZeroesDayAndTime() {
        let date = makeDate(year: 2026, month: 5, day: 26, hour: 22, minute: 47)
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: CalendarMath.startOfMonth(date)
        )
        #expect(components.year == 2026)
        #expect(components.month == 5)
        #expect(components.day == 1)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
    }

    @Test func daysInMonthHandlesLeapFebruary() {
        #expect(CalendarMath.daysInMonth(makeDate(year: 2024, month: 2, day: 10)).count == 29)
        #expect(CalendarMath.daysInMonth(makeDate(year: 2025, month: 2, day: 10)).count == 28)
        #expect(CalendarMath.daysInMonth(makeDate(year: 2026, month: 4, day: 1)).count == 30)
    }

    @Test func monthGridCellsAreLeadingBlanksThenDays() {
        let date = makeDate(year: 2026, month: 5, day: 1)
        let cells = CalendarMath.monthGridCells(date)
        let blanks = CalendarMath.leadingBlankCount(forMonth: date)
        let days = CalendarMath.daysInMonth(date).count

        #expect(blanks >= 0 && blanks < 7)
        #expect(cells.count == blanks + days)
        #expect(cells.prefix(blanks).allSatisfy { $0 == nil })
        #expect(cells.dropFirst(blanks).allSatisfy { $0 != nil })
    }

    @Test func monthAnchorsAreCenteredAndAscending() {
        let date = makeDate(year: 2026, month: 5, day: 26)
        let anchors = CalendarMath.monthAnchors(around: date, radius: 18)

        #expect(anchors.count == 37) // 2 * radius + 1
        #expect(anchors.contains(CalendarMath.startOfMonth(date)))
        #expect(anchors == anchors.sorted())
    }

    @Test func monthsBeforeAndAfterAreOrderedAndBounded() {
        let anchor = CalendarMath.startOfMonth(makeDate(year: 2026, month: 5, day: 1))
        let before = CalendarMath.months(before: anchor, count: 12)
        let after = CalendarMath.months(after: anchor, count: 12)

        #expect(before.count == 12)
        #expect(after.count == 12)
        #expect(before == before.sorted())
        #expect(after == after.sorted())
        #expect(before.allSatisfy { $0 < anchor })
        #expect(after.allSatisfy { $0 > anchor })
    }

    @Test func monthsOfYearReturnsTwelveAscending() {
        let months = CalendarMath.monthsOfYear(makeDate(year: 2026, month: 1, day: 1))
        #expect(months.count == 12)
        #expect(months == months.sorted())
    }

    @Test func orderedWeekdaySymbolsHasSeven() {
        #expect(CalendarMath.orderedWeekdaySymbols().count == 7)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? .now
    }
}
