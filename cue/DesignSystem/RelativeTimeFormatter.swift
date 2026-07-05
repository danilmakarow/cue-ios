//
//  RelativeTimeFormatter.swift
//  cue
//

import Foundation

/// Human-friendly relative-time phrasing for the Task Box meta line and the Event
/// Detail time band ("in 18 min", "in 3 h", "in 2 d", "5 min ago").
///
/// Pure and side-effect-free so it is trivially unit-testable: every method takes
/// an explicit `now` (defaulting to `.now`) and returns a plain `String`. The
/// bucketing mirrors the design brief's ramp — sub-hour in minutes, sub-day in
/// hours, sub-month in days, sub-year in months, then years — and reads the same
/// whether the target is in the future ("in N …") or the past ("N … ago").
enum RelativeTimeFormatter {

    /// One minute in seconds.
    private static let minute: TimeInterval = 60
    /// One hour in seconds.
    private static let hour: TimeInterval = 60 * 60
    /// One day in seconds.
    private static let day: TimeInterval = 24 * 60 * 60
    /// An approximate month (30 days) in seconds — good enough for coarse "N mo".
    private static let month: TimeInterval = 30 * 24 * 60 * 60
    /// An approximate year (365 days) in seconds.
    private static let year: TimeInterval = 365 * 24 * 60 * 60

    /// A future-facing countdown to `date` from `now`: `<1h → "in N min"`,
    /// `<24h → "in N h"`, `<30d → "in N d"`, `<~12mo → "in N mo"`, else `"in N y"`.
    /// When `date` is at or before `now` it reads "now" (within a minute) or falls
    /// through to the past phrasing ("N min ago").
    ///
    /// - Parameters:
    ///   - date: the target instant.
    ///   - now: the reference "now" (default `.now`); injected for testing.
    static func timeUntil(_ date: Date, from now: Date = .now) -> String {
        let interval = date.timeIntervalSince(now)
        if interval < minute {
            return past(interval)
        }
        let (count, unit) = quantize(interval)
        let format = String(
            localized: "relativeTime.in",
            defaultValue: "in %1$d %2$@"
        )
        return String(format: format, count, unit)
    }

    /// A past-facing phrasing for an `interval` (seconds, negative or sub-minute):
    /// "just now" within a minute, else "N <unit> ago".
    private static func past(_ interval: TimeInterval) -> String {
        let elapsed = -interval
        guard elapsed >= minute else {
            return String(localized: "relativeTime.now", defaultValue: "now")
        }
        let (count, unit) = quantize(elapsed)
        let format = String(
            localized: "relativeTime.ago",
            defaultValue: "%1$d %2$@ ago"
        )
        return String(format: format, count, unit)
    }

    /// Buckets a positive `interval` (seconds) into a `(count, unitAbbreviation)`
    /// pair on the min → h → d → mo → y ramp. The abbreviation is the compact form
    /// the design uses ("min", "h", "d", "mo", "y").
    private static func quantize(_ interval: TimeInterval) -> (count: Int, unit: String) {
        let magnitude = abs(interval)
        if magnitude < hour {
            let value = max(1, Int(magnitude / minute))
            return (value, String(localized: "relativeTime.unit.minute", defaultValue: "min"))
        }
        if magnitude < day {
            let value = max(1, Int(magnitude / hour))
            return (value, String(localized: "relativeTime.unit.hour", defaultValue: "h"))
        }
        if magnitude < month {
            let value = max(1, Int(magnitude / day))
            return (value, String(localized: "relativeTime.unit.day", defaultValue: "d"))
        }
        if magnitude < year {
            let value = max(1, Int(magnitude / month))
            return (value, String(localized: "relativeTime.unit.month", defaultValue: "mo"))
        }
        let value = max(1, Int(magnitude / year))
        return (value, String(localized: "relativeTime.unit.year", defaultValue: "y"))
    }
}
