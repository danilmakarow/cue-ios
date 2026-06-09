//
//  MonthGridModel.swift
//  cue
//

import Foundation

/// Precomputed, cached layout model for one month's grid — the day dates,
/// their display numbers, the leading-blank count, and the month's display
/// names. Shared by the month scope (`MonthGrid`) and the year scope's
/// mini-months (`YearMonthCell`).
///
/// Why it exists: the grid cells used to run `Calendar` date math and
/// `FormatStyle` formatting inside every cell's `body`, which is the single
/// most expensive thing the calendar scopes did while scrolling (a realized
/// year page is ~370 day cells). All of that work is locale-dependent but
/// month-stable, so it's done once per month here and memoized.
///
/// The cache is keyed by the month anchor and invalidated wholesale when the
/// locale identifier changes (in-app language switching rebuilds the UI, and
/// the first model request under the new locale clears stale entries).
struct MonthGridModel {
    /// One real day cell: its date (a `startOfDay`, the canonical day key
    /// used across the calendar) and its pre-formatted day number.
    struct Day: Hashable {
        let date: Date
        let number: String
    }

    /// Canonical `startOfMonth` anchor for this month.
    let monthAnchor: Date
    /// Empty cells before day 1, honoring the locale's first weekday.
    let leadingBlankCount: Int
    /// The month's real days, ascending.
    let days: [Day]
    /// Grid cells: `leadingBlankCount` nils followed by each day — the exact
    /// shape the 7-column grids render.
    let cells: [Day?]
    /// Number of 7-column rows the grid occupies (drives mini-grid height).
    let weekRowCount: Int
    /// The month's calendar year (e.g. 2026), for "show the year in the
    /// heading when it isn't the current year" checks.
    let year: Int
    /// "May" — wide standalone month name.
    let nameWide: String
    /// "May 2027" — wide month name with year.
    let nameWideWithYear: String
    /// "May" / "Mai" — abbreviated month name for the year grid.
    let nameAbbreviated: String

    private static var cache: [Date: MonthGridModel] = [:]
    private static var cacheLocaleID: String = Locale.current.identifier

    /// Returns the (memoized) model for the month containing `anchor`.
    static func model(for anchor: Date) -> MonthGridModel {
        let localeID = Locale.current.identifier
        if localeID != cacheLocaleID {
            cache.removeAll()
            cacheLocaleID = localeID
        }
        let key = CalendarMath.startOfMonth(anchor)
        if let cached = cache[key] {
            return cached
        }
        let model = MonthGridModel(anchor: key)
        cache[key] = model
        return model
    }

    private init(anchor: Date) {
        monthAnchor = anchor
        leadingBlankCount = CalendarMath.leadingBlankCount(forMonth: anchor)
        days = CalendarMath.daysInMonth(anchor).map { date in
            Day(date: date, number: date.formatted(.dateTime.day()))
        }
        cells = [Day?](repeating: nil, count: leadingBlankCount) + days.map { $0 }
        weekRowCount = (leadingBlankCount + days.count + 6) / 7
        year = Calendar.current.component(.year, from: anchor)
        nameWide = anchor.formatted(.dateTime.month(.wide))
        nameWideWithYear = anchor.formatted(.dateTime.month(.wide).year())
        nameAbbreviated = anchor.formatted(.dateTime.month(.abbreviated))
    }
}
