//
//  RecurrenceEngine.swift
//  cue
//
//  Pure client-side recurrence expansion — a faithful Swift port of the backend
//  `RecurrenceRuleService.expandOccurrences` (cue-api,
//  src/modules/recurrence-rule/recurrence-rule.service.ts). The full-calendar
//  replica expands rules locally so any month/year renders with no network; this
//  engine MUST agree with the server oracle to epoch-millisecond exactness, which
//  the golden parity-fixture corpus (`RecurrenceParityTests`) enforces.
//
//  Parity-critical decisions mirrored from luxon:
//   • Weekday axis: the entity/config uses 0 = Monday … 6 = Sunday. Foundation's
//     `.weekday` is 1 = Sunday … 7 = Saturday; ``ZonedDateTime.luxonWeekday``
//     maps it to luxon's 1 = Monday … 7 = Sunday, then `- 1` gives the entity axis.
//   • Week start is Monday (ISO-8601), computed manually so it never depends on
//     `Calendar.firstWeekday` / locale.
//   • Wall-clock preservation across DST: the period cursor steps CUMULATIVELY
//     via `Calendar.date(byAdding:)` in the task timezone, so a time that lands in
//     a spring-forward gap rolls forward and the whole series then carries the
//     shifted wall-clock — exactly luxon's `.plus({...})` behavior.
//   • Month-day overflow (BYMONTHDAY 31 in a 30-day month) is DROPPED, never
//     clamped, detected by the resulting month differing from the requested month.
//   • UNTIL is the inclusive end-of-day of `endDate` in the task timezone; COUNT
//     is measured from the series origin, window-independent.
//

import Foundation

/// Pure recurrence expansion. Stateless; every method is `nonisolated static` so
/// the engine can run off the main actor (background projection).
nonisolated enum RecurrenceEngine {
    /// Hard ceiling on occurrences returned from one expansion (matches the server).
    static let maxOccurrencesPerWindow = 1000
    /// Defensive ceiling on raw generation steps (matches the server: 1000 × 64).
    static let maxGenerationSteps = 1000 * 64

    /// Expands a recurring anchor into the occurrences intersecting the half-open
    /// window `[windowFrom, windowTo)`, with exceptions applied. Pure and I/O-free.
    /// Returns occurrences in GENERATION order (by `originalStart`) — the higher
    /// projection layer is responsible for any final sort, matching the server
    /// (`expandOccurrences` does not re-sort after applying moves).
    static func expandOccurrences(
        anchorStart: Date,
        anchorEnd: Date?,
        title: String,
        timeZone: TimeZone,
        config: RecurrenceConfig,
        exceptions: [RecurrenceException],
        windowFrom: Date,
        windowTo: Date
    ) -> [EngineOccurrence] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let seed = ZonedDateTime(anchorStart, calendar)

        let durationMillis: Int64? = anchorEnd.map {
            epochMillis($0) - epochMillis(anchorStart)
        }
        let exceptionsByOriginalStart = indexExceptions(exceptions)
        let windowFromMillis = epochMillis(windowFrom)
        let windowToMillis = epochMillis(windowTo)
        let untilMillis = untilBoundaryMillis(config, calendar)
        let hasCount = config.endType == .count && config.count != nil
        let countLimit = hasCount ? config.count : nil

        var occurrences: [EngineOccurrence] = []
        var periodCursor = seed
        var generatedCount = 0
        var generationSteps = 0
        var truncated = false

        while generationSteps < maxGenerationSteps {
            let candidates = candidatesForPeriod(periodCursor, seed, config)

            for candidate in candidates {
                let candidateMillis = candidate.millis

                if let untilMillis, candidateMillis > untilMillis {
                    return occurrences
                }

                if let countLimit, generatedCount >= countLimit {
                    return occurrences
                }

                generatedCount += 1

                if candidateMillis >= windowToMillis {
                    return occurrences
                }

                let occurrenceEndMillis =
                    durationMillis != nil ? candidateMillis + durationMillis! : candidateMillis

                if occurrenceEndMillis <= windowFromMillis { continue }

                let originalStart = candidate.date
                let exception = exceptionsByOriginalStart[candidateMillis]

                if exception?.isSkipped == true { continue }

                occurrences.append(
                    buildOccurrence(
                        anchorTitle: title,
                        originalStart: originalStart,
                        durationMillis: durationMillis,
                        exception: exception
                    )
                )

                if occurrences.count >= maxOccurrencesPerWindow {
                    truncated = true
                    break
                }
            }

            if truncated { break }

            let next = stepPeriod(periodCursor, config)

            if next.millis <= periodCursor.millis { break }

            periodCursor = next
            generationSteps += 1
        }

        return occurrences
    }

    // MARK: - Occurrence construction

    /// Builds one occurrence, applying an exception's move / resize / retitle /
    /// completion (skip is handled by the caller). Mirrors `buildOccurrence`: the
    /// derived end uses the (possibly overridden) start plus the anchor duration.
    private static func buildOccurrence(
        anchorTitle: String,
        originalStart: Date,
        durationMillis: Int64?,
        exception: RecurrenceException?
    ) -> EngineOccurrence {
        let occurrenceStart = exception?.overrideStartAt ?? originalStart
        let defaultEnd: Date? = durationMillis.map {
            millisToDate(epochMillis(occurrenceStart) + $0)
        }
        let occurrenceEnd = exception?.overrideEndAt ?? defaultEnd

        return EngineOccurrence(
            originalStart: originalStart,
            occurrenceStart: occurrenceStart,
            occurrenceEnd: occurrenceEnd,
            title: exception?.overrideTitle ?? anchorTitle,
            completedAt: exception?.completedAt,
            isException: exception != nil
        )
    }

    // MARK: - Period stepping & termination

    /// Advances the period cursor by one `frequency × interval` step (cumulative,
    /// wall-clock-preserving). A week step is 7 × interval days, matching luxon.
    private static func stepPeriod(
        _ cursor: ZonedDateTime,
        _ config: RecurrenceConfig
    ) -> ZonedDateTime {
        let interval = config.interval >= 1 ? config.interval : 1

        switch config.frequency {
        case .daily: return cursor.adding(.day, interval)
        case .weekly: return cursor.adding(.day, 7 * interval)
        case .monthly: return cursor.adding(.month, interval)
        case .yearly: return cursor.adding(.year, interval)
        }
    }

    /// Inclusive UNTIL boundary (end-of-day of `endDate`) in millis, or nil when
    /// the config does not terminate by date.
    private static func untilBoundaryMillis(
        _ config: RecurrenceConfig,
        _ calendar: Calendar
    ) -> Int64? {
        guard config.endType == .untilDate, let endDate = config.endDate else {
            return nil
        }

        let parts = endDate.split(separator: "-")

        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 23
        components.minute = 59
        components.second = 59
        components.nanosecond = 999_000_000

        guard let boundary = calendar.date(from: components) else { return nil }

        return epochMillis(boundary)
    }

    /// Indexes exceptions by the epoch-millis of their `originalStartAt`.
    private static func indexExceptions(
        _ exceptions: [RecurrenceException]
    ) -> [Int64: RecurrenceException] {
        var index: [Int64: RecurrenceException] = [:]

        for exception in exceptions {
            index[epochMillis(exception.originalStartAt)] = exception
        }

        return index
    }

    // MARK: - Per-period candidate generation

    /// Sorted, de-duplicated candidate starts within one period, filtered by the
    /// limiting `by*` axes and dropping anything before the series seed.
    private static func candidatesForPeriod(
        _ periodStart: ZonedDateTime,
        _ seed: ZonedDateTime,
        _ config: RecurrenceConfig
    ) -> [ZonedDateTime] {
        let raw: [ZonedDateTime]

        switch config.frequency {
        case .daily:
            raw = [periodStart]
        case .weekly:
            raw = weeklyCandidates(periodStart, config.byWeekday)
        case .monthly:
            raw = monthlyCandidates(periodStart, seed, config)
        case .yearly:
            raw = yearlyCandidates(periodStart, seed, config.byMonth, config.byMonthDay)
        }

        let seedMillis = seed.millis
        var seen = Set<Int64>()
        var filtered: [ZonedDateTime] = []

        for candidate in raw {
            let millis = candidate.millis

            if millis < seedMillis { continue }
            if seen.contains(millis) { continue }
            if !passesLimitFilters(candidate, config.frequency, config) { continue }

            seen.insert(millis)
            filtered.append(candidate)
        }

        return filtered.sorted { $0.millis < $1.millis }
    }

    /// Candidate starts within one WEEKLY period. With `byWeekday`, expands the
    /// (Monday-anchored) week into one candidate per listed weekday at the period
    /// cursor's wall-clock time; otherwise the cursor itself.
    private static func weeklyCandidates(
        _ periodStart: ZonedDateTime,
        _ byWeekday: [Int]?
    ) -> [ZonedDateTime] {
        guard let byWeekday, !byWeekday.isEmpty else { return [periodStart] }

        let weekStart = periodStart.startOfWeekMonday()

        return byWeekday.map { entityWeekday in
            weekStart
                .adding(.day, entityWeekday)
                .settingTime(
                    hour: periodStart.hour,
                    minute: periodStart.minute,
                    second: periodStart.second,
                    nanosecond: periodStart.nanosecond
                )
        }
    }

    /// Candidate starts within one MONTHLY period. Selector precedence: working-day
    /// anchor → nth-weekday (`bySetPos` + `byWeekday`) → `byMonthDay` → seed day.
    private static func monthlyCandidates(
        _ periodStart: ZonedDateTime,
        _ seed: ZonedDateTime,
        _ config: RecurrenceConfig
    ) -> [ZonedDateTime] {
        let monthStart = periodStart.startOfMonth()

        if let monthlyAnchor = config.monthlyAnchor {
            guard let anchor = workdayAnchorInMonth(monthStart, monthlyAnchor) else {
                return []
            }

            return [atSeedTime(anchor, seed)]
        }

        if let bySetPos = config.bySetPos, !bySetPos.isEmpty,
           let byWeekday = config.byWeekday, !byWeekday.isEmpty {
            return bySetPos
                .compactMap { nthWeekdayInMonth(monthStart, byWeekday, $0) }
                .map { atSeedTime($0, seed) }
        }

        let days: [Int] =
            (config.byMonthDay?.isEmpty == false) ? config.byMonthDay! : [seed.day]

        return days
            .compactMap { dayInMonthOrNull(monthStart, $0) }
            .map { atSeedTime($0, seed) }
    }

    /// Candidate starts within one YEARLY period. `byMonth` (or the seed month)
    /// selects months; within each, `byMonthDay` (or the seed day) selects days,
    /// skipping any day that overflows its month.
    private static func yearlyCandidates(
        _ periodStart: ZonedDateTime,
        _ seed: ZonedDateTime,
        _ byMonth: [Int]?,
        _ byMonthDay: [Int]?
    ) -> [ZonedDateTime] {
        let months: [Int] = (byMonth?.isEmpty == false) ? byMonth! : [seed.month]
        let days: [Int] = (byMonthDay?.isEmpty == false) ? byMonthDay! : [seed.day]
        var candidates: [ZonedDateTime] = []

        for month in months {
            let monthStart = periodStart.startOfMonth(month: month)

            for day in days {
                guard let candidate = dayInMonthOrNull(monthStart, day) else { continue }

                candidates.append(
                    candidate.settingTime(
                        hour: seed.hour,
                        minute: seed.minute,
                        second: seed.second,
                        nanosecond: seed.nanosecond
                    )
                )
            }
        }

        return candidates
    }

    // MARK: - Selector primitives

    /// Applies the `by*` axes that LIMIT the given frequency (the axes it doesn't
    /// already expand on). Returns true when the candidate is allowed through.
    private static func passesLimitFilters(
        _ candidate: ZonedDateTime,
        _ frequency: RecurrenceFrequency,
        _ config: RecurrenceConfig
    ) -> Bool {
        let limitsWeekday = frequency != .weekly
        let limitsMonthDay = frequency != .monthly && frequency != .yearly
        let limitsMonth = frequency != .yearly

        if limitsWeekday, let byWeekday = config.byWeekday, !byWeekday.isEmpty,
           !byWeekday.contains(luxonWeekdayToEntity(candidate.luxonWeekday)) {
            return false
        }

        if limitsMonthDay, let byMonthDay = config.byMonthDay, !byMonthDay.isEmpty,
           !byMonthDay.contains(candidate.day) {
            return false
        }

        if limitsMonth, let byMonth = config.byMonth, !byMonth.isEmpty,
           !byMonth.contains(candidate.month) {
            return false
        }

        return true
    }

    /// Resolves a day-of-month within `monthStart`'s month, or nil when the day
    /// overflows (iCal BYMONTHDAY: day 31 in a 30-day month is skipped, not clamped).
    private static func dayInMonthOrNull(
        _ monthStart: ZonedDateTime,
        _ day: Int
    ) -> ZonedDateTime? {
        let candidate = monthStart.setting(day: day)

        if candidate.month != monthStart.month { return nil }

        return candidate
    }

    /// Resolves the nth match of a weekday set within a month (BYSETPOS over BYDAY).
    /// 1..k counts from the front, -1 the last; overflowing ordinals return nil.
    private static func nthWeekdayInMonth(
        _ monthStart: ZonedDateTime,
        _ byWeekday: [Int],
        _ setPos: Int
    ) -> ZonedDateTime? {
        let daysInMonth = monthStart.daysInMonth

        guard daysInMonth >= 1 else { return nil }

        let allowed = Set(byWeekday)
        var matches: [ZonedDateTime] = []

        for day in 1...daysInMonth {
            let candidate = monthStart.setting(day: day)

            if allowed.contains(luxonWeekdayToEntity(candidate.luxonWeekday)) {
                matches.append(candidate)
            }
        }

        if matches.isEmpty { return nil }

        let index = setPos > 0 ? setPos - 1 : matches.count + setPos

        if index < 0 || index >= matches.count { return nil }

        return matches[index]
    }

    /// Resolves the working-day (Mon–Fri) anchor of a month for the given mode.
    private static func workdayAnchorInMonth(
        _ monthStart: ZonedDateTime,
        _ mode: MonthlyAnchorMode
    ) -> ZonedDateTime? {
        let daysInMonth = monthStart.daysInMonth

        guard daysInMonth >= 1 else { return nil }

        if mode == .firstWorkday {
            for day in 1...daysInMonth {
                let candidate = monthStart.setting(day: day)

                if isWorkday(candidate.luxonWeekday) { return candidate }
            }

            return nil
        }

        // LAST_WORKDAY / DAY_BEFORE_LAST_WORKDAY walk back from month end,
        // skipping the requested number of leading working days.
        let skip = mode == .dayBeforeLastWorkday ? 1 : 0
        var seen = 0
        var day = daysInMonth

        while day >= 1 {
            let candidate = monthStart.setting(day: day)

            if isWorkday(candidate.luxonWeekday) {
                if seen == skip { return candidate }

                seen += 1
            }

            day -= 1
        }

        return nil
    }

    /// Carries the seed's wall-clock time onto a date-anchored candidate.
    private static func atSeedTime(
        _ candidate: ZonedDateTime,
        _ seed: ZonedDateTime
    ) -> ZonedDateTime {
        candidate.settingTime(
            hour: seed.hour,
            minute: seed.minute,
            second: seed.second,
            nanosecond: seed.nanosecond
        )
    }

    /// luxon weekday (1 = Monday … 7 = Sunday) → entity axis (0 = Monday … 6 = Sunday).
    private static func luxonWeekdayToEntity(_ luxonWeekday: Int) -> Int {
        luxonWeekday - 1
    }

    /// True when the luxon weekday (1 = Monday … 7 = Sunday) is Mon–Fri.
    private static func isWorkday(_ luxonWeekday: Int) -> Bool {
        luxonWeekday <= 5
    }
}

// MARK: - Epoch helpers

/// A `Date` as whole epoch-milliseconds — the comparison/identity currency shared
/// with the backend (`Date.getTime()`), rounded to absorb sub-millisecond float noise.
private func epochMillis(_ date: Date) -> Int64 {
    Int64((date.timeIntervalSince1970 * 1000).rounded())
}

/// Inverse of ``epochMillis(_:)`` — reconstructs a `Date` from whole epoch-millis.
private func millisToDate(_ millis: Int64) -> Date {
    Date(timeIntervalSince1970: Double(millis) / 1000)
}

// MARK: - Zoned date-time

/// A timezone-aware wall-clock date, wrapping a `Date` + a `Calendar` pinned to the
/// task timezone. Mirrors the luxon `DateTime` operations the engine relies on —
/// each returns a new value; DST resolution is delegated to `Calendar`, which (like
/// luxon) rolls a nonexistent spring-forward time forward and resolves an ambiguous
/// fall-back time to the earlier offset.
private nonisolated struct ZonedDateTime {
    let date: Date
    let calendar: Calendar

    init(_ date: Date, _ calendar: Calendar) {
        self.date = date
        self.calendar = calendar
    }

    var year: Int { calendar.component(.year, from: date) }
    var month: Int { calendar.component(.month, from: date) }
    var day: Int { calendar.component(.day, from: date) }
    var hour: Int { calendar.component(.hour, from: date) }
    var minute: Int { calendar.component(.minute, from: date) }
    var second: Int { calendar.component(.second, from: date) }
    var nanosecond: Int { calendar.component(.nanosecond, from: date) }
    var millis: Int64 { epochMillis(date) }
    var daysInMonth: Int { calendar.range(of: .day, in: .month, for: date)?.count ?? 0 }

    /// luxon weekday: 1 = Monday … 7 = Sunday (Foundation's 1 = Sunday … 7 = Saturday remapped).
    var luxonWeekday: Int {
        let weekday = calendar.component(.weekday, from: date)

        return weekday == 1 ? 7 : weekday - 1
    }

    /// Adds a calendar component (wall-clock-preserving, DST-aware); the cursor
    /// step relies on this to drift a series carried through a DST gap.
    func adding(_ component: Calendar.Component, _ value: Int) -> ZonedDateTime {
        guard let advanced = calendar.date(byAdding: component, value: value, to: date) else {
            return self
        }

        return ZonedDateTime(advanced, calendar)
    }

    /// Midnight of the current day in the task timezone.
    func startOfDay() -> ZonedDateTime {
        ZonedDateTime(calendar.startOfDay(for: date), calendar)
    }

    /// The 1st of the current month at 00:00 (task timezone).
    func startOfMonth() -> ZonedDateTime {
        startOfMonth(month: month)
    }

    /// The 1st of `month` in the current YEAR at 00:00 — used by yearly expansion
    /// (`periodStart.set({month, day:1}).startOf('day')`).
    func startOfMonth(month: Int) -> ZonedDateTime {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let start = calendar.date(from: components) else { return self }

        return ZonedDateTime(start, calendar)
    }

    /// The Monday 00:00 of the current ISO week (independent of `Calendar.firstWeekday`).
    func startOfWeekMonday() -> ZonedDateTime {
        let startOfDay = startOfDay()
        let offsetFromMonday = startOfDay.luxonWeekday - 1

        return startOfDay.adding(.day, -offsetFromMonday)
    }

    /// Sets the day-of-month, keeping the time — lenient, so an out-of-range day
    /// rolls into the next month (detected by the caller as an overflow).
    func setting(day: Int) -> ZonedDateTime {
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond],
            from: date
        )
        components.day = day

        guard let updated = calendar.date(from: components) else { return self }

        return ZonedDateTime(updated, calendar)
    }

    /// Sets the wall-clock time, keeping the date. DST-invalid times resolve the
    /// same way `Calendar.date(from:)` handles them (matching luxon `.set`).
    func settingTime(hour: Int, minute: Int, second: Int, nanosecond: Int) -> ZonedDateTime {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = second
        components.nanosecond = nanosecond

        guard let updated = calendar.date(from: components) else { return self }

        return ZonedDateTime(updated, calendar)
    }
}
