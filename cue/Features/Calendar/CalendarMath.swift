//
//  CalendarMath.swift
//  cue
//

import Foundation

/// Pure calendar/date helpers shared by the calendar scope views (year,
/// month, day). All math uses `Calendar.current`, so the week start
/// (Mon/Sun) and month lengths follow the user's locale.
///
/// Canonical keys produced here (`startOfDay`, `startOfMonth`) double as the
/// `matchedTransitionSource` ids for the zoom navigation, so source and
/// destination always agree.
enum CalendarMath {
    private static var calendar: Calendar { .current }

    // MARK: - Anchors

    /// Start of the day (00:00) containing `date`.
    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Start of the month (day 1, 00:00) containing `date`.
    static func startOfMonth(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    /// Start of January 1st (00:00) of the year containing `date`.
    static func startOfYear(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    // MARK: - Ranges

    /// `[startOfMonth, startOfNextMonth)` bounds for the month containing `date`.
    static func monthBounds(_ date: Date) -> (from: Date, to: Date) {
        let from = startOfMonth(date)
        let to = calendar.date(byAdding: .month, value: 1, to: from) ?? from
        return (from, to)
    }

    // MARK: - Windows

    /// `radius` months either side of `date`'s month, inclusive, ascending.
    static func monthAnchors(around date: Date, radius: Int) -> [Date] {
        let center = startOfMonth(date)
        return (-radius...radius).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: center)
        }
    }

    /// `count` months immediately after `anchor`, ascending.
    static func months(after anchor: Date, count: Int) -> [Date] {
        guard count > 0 else { return [] }
        return (1...count).compactMap { calendar.date(byAdding: .month, value: $0, to: anchor) }
    }

    /// `count` months immediately before `anchor`, ascending (oldest first).
    static func months(before anchor: Date, count: Int) -> [Date] {
        guard count > 0 else { return [] }
        return (1...count).reversed().compactMap { calendar.date(byAdding: .month, value: -$0, to: anchor) }
    }

    /// `radius` years either side of `date`'s year, inclusive, ascending.
    static func yearAnchors(around date: Date, radius: Int) -> [Date] {
        let center = startOfYear(date)
        return (-radius...radius).compactMap { offset in
            calendar.date(byAdding: .year, value: offset, to: center)
        }
    }

    /// `count` years immediately after `anchor`, ascending.
    static func years(after anchor: Date, count: Int) -> [Date] {
        guard count > 0 else { return [] }
        return (1...count).compactMap { calendar.date(byAdding: .year, value: $0, to: anchor) }
    }

    /// `count` years immediately before `anchor`, ascending (oldest first).
    static func years(before anchor: Date, count: Int) -> [Date] {
        guard count > 0 else { return [] }
        return (1...count).reversed().compactMap { calendar.date(byAdding: .year, value: -$0, to: anchor) }
    }

    /// Extends `anchors` (ascending month-starts) just enough to contain
    /// `target`'s month with `margin` extra months on the leading side, reusing
    /// every existing element so the caller's `LazyVStack` keeps page identities
    /// stable. Returns the original array unchanged when `target` is already
    /// covered. Prefer this over rebuilding the whole window when jumping to a
    /// far-away month: only the genuinely-new pages get realized.
    static func monthAnchorsExtended(_ anchors: [Date], toInclude target: Date, margin: Int) -> [Date] {
        extendedAnchors(anchors, toInclude: startOfMonth(target), margin: margin, component: .month)
    }

    /// Year-scope counterpart of ``monthAnchorsExtended(_:toInclude:margin:)``.
    /// Extends `anchors` (ascending year-starts) to contain `target`'s year
    /// without discarding existing pages, so jumping to a distant year doesn't
    /// rebuild the entire lazy column.
    static func yearAnchorsExtended(_ anchors: [Date], toInclude target: Date, margin: Int) -> [Date] {
        extendedAnchors(anchors, toInclude: startOfYear(target), margin: margin, component: .year)
    }

    /// Shared engine for the year/month "extend a window to include a target"
    /// helpers. Prepends/appends only the missing anchors (plus `margin`),
    /// keeping every existing element so lazy-stack identities survive.
    private static func extendedAnchors(
        _ anchors: [Date],
        toInclude target: Date,
        margin: Int,
        component: Calendar.Component
    ) -> [Date] {
        guard let first = anchors.first, let last = anchors.last else {
            // Empty window: seed a small window centered on the target.
            let span = max(margin, 1)
            return (-span...span).compactMap { calendar.date(byAdding: component, value: $0, to: target) }
        }
        guard target < first || target > last else { return anchors }

        var result = anchors
        if target < first,
           let prependFrom = calendar.date(byAdding: component, value: -margin, to: target) {
            var cursor = calendar.date(byAdding: component, value: -1, to: first)
            var prefix: [Date] = []
            while let value = cursor, value >= prependFrom {
                prefix.insert(value, at: 0)
                cursor = calendar.date(byAdding: component, value: -1, to: value)
            }
            result.insert(contentsOf: prefix, at: 0)
        }
        if target > last,
           let appendTo = calendar.date(byAdding: component, value: margin, to: target) {
            var cursor = calendar.date(byAdding: component, value: 1, to: last)
            while let value = cursor, value <= appendTo {
                result.append(value)
                cursor = calendar.date(byAdding: component, value: 1, to: value)
            }
        }
        return result
    }

    // MARK: - Grid building

    /// The 12 month-start anchors of `yearAnchor`'s year, ascending.
    static func monthsOfYear(_ yearAnchor: Date) -> [Date] {
        let start = startOfYear(yearAnchor)
        return (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
    }

    /// Number of empty leading cells before day 1, honoring the locale's
    /// first weekday.
    static func leadingBlankCount(forMonth date: Date) -> Int {
        let first = startOfMonth(date)
        let weekday = calendar.component(.weekday, from: first) // 1...7 (Sun = 1)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    /// All day-dates (1...n) in the month containing `date`, ascending.
    static func daysInMonth(_ date: Date) -> [Date] {
        let first = startOfMonth(date)
        let count = calendar.range(of: .day, in: .month, for: first)?.count ?? 0
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    /// Grid cells for a month: leading `nil` blanks (to align day 1 under its
    /// weekday) followed by each day. Use the cell index as the `ForEach` id
    /// so blanks stay stable and SwiftUI doesn't warn about a dynamic range.
    static func monthGridCells(_ date: Date) -> [Date?] {
        let blanks = [Date?](repeating: nil, count: leadingBlankCount(forMonth: date))
        let days: [Date?] = daysInMonth(date).map { $0 }
        return blanks + days
    }

    /// Very-short weekday symbols ordered from the locale's first weekday
    /// (e.g. `["M","T","W","T","F","S","S"]` when Monday is first).
    static func orderedWeekdaySymbols() -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstIndex = calendar.firstWeekday - 1
        guard symbols.indices.contains(firstIndex) else { return symbols }
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    // MARK: - Predicates

    /// True when `lhs` and `rhs` fall on the same calendar day.
    static func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    /// True when `date` is today.
    static func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
}
