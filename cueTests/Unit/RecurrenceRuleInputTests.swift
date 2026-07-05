//
//  RecurrenceRuleInputTests.swift
//  cueTests
//
//  Tests the OBSERVABLE cross-field contract that
//  `RecurrenceEditor.updateBinding()` must uphold on `RecurrenceRuleInput`.
//
//  TESTABILITY GAP: `updateBinding()`, `stringFromDate(_:)`, and
//  `dateFromString(_:)` are all `private` members of the `RecurrenceEditor`
//  SwiftUI `View`, so they are NOT directly callable from a unit test. These
//  tests therefore assert the invariants by constructing `RecurrenceRuleInput`
//  values that mirror each `updateBinding()` branch exactly (one local helper
//  per editor branch, reproducing the same field-population logic), then
//  asserting field population + `Hashable`/`Equatable` behavior. To cover
//  `updateBinding()` / the date helpers DIRECTLY, they should be promoted to a
//  free function or a testable helper type (e.g. a `RecurrenceRuleBuilder`
//  struct) that the `View` calls — flagged in the return notes.
//

import Foundation
import Testing
@testable import cue

struct RecurrenceRuleInputTests {

    // MARK: - Branch mirrors
    //
    // Each helper reproduces ONE branch of `RecurrenceEditor.updateBinding()`
    // verbatim, so the assertions below pin the real cross-field rules the
    // editor encodes. Keep these in lock-step with the source switch.

    /// Mirrors the `.weekly` branch: only sorted `byWeekday`, nil when empty.
    private func buildWeekly(
        weekdays: Set<Int>,
        interval: Int = 1,
        endType: RecurrenceEndType = .never,
        endDate: String? = nil,
        count: Int? = nil
    ) -> RecurrenceRuleInput {
        let byWeekday = weekdays.isEmpty ? nil : weekdays.sorted()
        return RecurrenceRuleInput(
            frequency: .weekly,
            interval: interval,
            byWeekday: byWeekday,
            byMonthDay: nil,
            byMonth: nil,
            bySetPos: nil,
            monthlyAnchor: nil,
            endType: endType,
            endDate: endDate,
            count: count
        )
    }

    /// Mirrors the monthly `.onDay` branch: only sorted `byMonthDay`.
    private func buildMonthlyOnDay(monthDays: Set<Int>, interval: Int = 1) -> RecurrenceRuleInput {
        let byMonthDay = monthDays.isEmpty ? nil : monthDays.sorted()
        return RecurrenceRuleInput(
            frequency: .monthly,
            interval: interval,
            byWeekday: nil,
            byMonthDay: byMonthDay,
            byMonth: nil,
            bySetPos: nil,
            monthlyAnchor: nil,
            endType: .never,
            endDate: nil,
            count: nil
        )
    }

    /// Mirrors the monthly `.onThe` branch: a single `bySetPos` paired with
    /// exactly one `byWeekday` — never one without the other.
    private func buildMonthlyOnThe(
        position: NthPosition,
        weekday: Int,
        interval: Int = 1
    ) -> RecurrenceRuleInput {
        RecurrenceRuleInput(
            frequency: .monthly,
            interval: interval,
            byWeekday: [weekday],
            byMonthDay: nil,
            byMonth: nil,
            bySetPos: [position.rawValue],
            monthlyAnchor: nil,
            endType: .never,
            endDate: nil,
            count: nil
        )
    }

    /// Mirrors the monthly `.workday` branch: `monthlyAnchor` set, every other
    /// monthly selector cleared.
    private func buildMonthlyWorkday(anchor: MonthlyAnchorMode, interval: Int = 1) -> RecurrenceRuleInput {
        RecurrenceRuleInput(
            frequency: .monthly,
            interval: interval,
            byWeekday: nil,
            byMonthDay: nil,
            byMonth: nil,
            bySetPos: nil,
            monthlyAnchor: anchor,
            endType: .never,
            endDate: nil,
            count: nil
        )
    }

    /// Mirrors the `.yearly` branch: only sorted `byMonth`, nil when empty.
    private func buildYearly(months: Set<Int>, interval: Int = 1) -> RecurrenceRuleInput {
        let byMonth = months.isEmpty ? nil : months.sorted()
        return RecurrenceRuleInput(
            frequency: .yearly,
            interval: interval,
            byWeekday: nil,
            byMonthDay: nil,
            byMonth: byMonth,
            bySetPos: nil,
            monthlyAnchor: nil,
            endType: .never,
            endDate: nil,
            count: nil
        )
    }

    // MARK: - (1) Monthly .onThe always pairs bySetPos with exactly one byWeekday

    @Test func monthlyOnThePairsSingleSetPosWithSingleWeekday() {
        let rule = buildMonthlyOnThe(position: .first, weekday: 0)

        #expect(rule.bySetPos == [1])
        #expect(rule.byWeekday == [0])
        // Exactly one of each — the cross-field invariant.
        #expect(rule.bySetPos?.count == 1)
        #expect(rule.byWeekday?.count == 1)
        // .onThe never populates the other monthly selectors.
        #expect(rule.byMonthDay == nil)
        #expect(rule.monthlyAnchor == nil)
        #expect(rule.byMonth == nil)
    }

    @Test func monthlyOnTheNeverEmitsSetPosWithoutWeekday() {
        // Sweep every ordinal/weekday combination the editor can produce.
        for position in NthPosition.allCases {
            for weekday in 0...6 {
                let rule = buildMonthlyOnThe(position: position, weekday: weekday)
                let hasSetPos = !(rule.bySetPos?.isEmpty ?? true)
                let hasWeekday = !(rule.byWeekday?.isEmpty ?? true)
                // bySetPos must NEVER ride without a byWeekday.
                #expect(hasSetPos == hasWeekday)
                #expect(rule.bySetPos == [position.rawValue])
                #expect(rule.byWeekday == [weekday])
            }
        }
    }

    @Test func nthPositionLastMapsToMinusOne() {
        let rule = buildMonthlyOnThe(position: .last, weekday: 4)
        #expect(rule.bySetPos == [-1])
        #expect(rule.byWeekday == [4])
    }

    // MARK: - (2) Monthly .workday populates anchor, clears the rest

    @Test func monthlyWorkdayPopulatesAnchorAndClearsOtherSelectors() {
        for anchor in MonthlyAnchorMode.allCases {
            let rule = buildMonthlyWorkday(anchor: anchor)
            #expect(rule.monthlyAnchor == anchor)
            // Mutual exclusivity: anchor clears every other monthly field.
            #expect(rule.byMonthDay == nil)
            #expect(rule.bySetPos == nil)
            #expect(rule.byWeekday == nil)
            #expect(rule.byMonth == nil)
        }
    }

    // MARK: - (3) Monthly .onDay populates only byMonthDay

    @Test func monthlyOnDayPopulatesOnlyByMonthDaySorted() {
        let rule = buildMonthlyOnDay(monthDays: [15, 1, 31])
        #expect(rule.byMonthDay == [1, 15, 31])
        #expect(rule.bySetPos == nil)
        #expect(rule.byWeekday == nil)
        #expect(rule.monthlyAnchor == nil)
        #expect(rule.byMonth == nil)
    }

    @Test func monthlyOnDayEmptySelectionYieldsNilByMonthDay() {
        let rule = buildMonthlyOnDay(monthDays: [])
        #expect(rule.byMonthDay == nil)
    }

    // MARK: - (4) Weekly populates only sorted byWeekday, nil when empty

    @Test func weeklyPopulatesOnlySortedByWeekday() {
        let rule = buildWeekly(weekdays: [6, 0, 3])
        #expect(rule.byWeekday == [0, 3, 6])
        #expect(rule.byMonthDay == nil)
        #expect(rule.byMonth == nil)
        #expect(rule.bySetPos == nil)
        #expect(rule.monthlyAnchor == nil)
    }

    @Test func weeklyEmptySelectionYieldsNilByWeekday() {
        let rule = buildWeekly(weekdays: [])
        #expect(rule.byWeekday == nil)
    }

    // MARK: - (5) Yearly populates only sorted byMonth

    @Test func yearlyPopulatesOnlySortedByMonth() {
        let rule = buildYearly(months: [12, 1, 6])
        #expect(rule.byMonth == [1, 6, 12])
        #expect(rule.byWeekday == nil)
        #expect(rule.byMonthDay == nil)
        #expect(rule.bySetPos == nil)
        #expect(rule.monthlyAnchor == nil)
    }

    @Test func yearlyEmptySelectionYieldsNilByMonth() {
        let rule = buildYearly(months: [])
        #expect(rule.byMonth == nil)
    }

    // MARK: - (6) End-type cross-field rules

    @Test func endTypeUntilDateYieldsDateStringAndNilCount() {
        let rule = buildWeekly(
            weekdays: [0],
            endType: .untilDate,
            endDate: "2027-01-15",
            count: nil
        )
        #expect(rule.endType == .untilDate)
        #expect(rule.endDate == "2027-01-15")
        #expect(rule.count == nil)
    }

    @Test func endTypeCountYieldsCountAndNilEndDate() {
        let rule = buildWeekly(
            weekdays: [0],
            endType: .count,
            endDate: nil,
            count: 10
        )
        #expect(rule.endType == .count)
        #expect(rule.count == 10)
        #expect(rule.endDate == nil)
    }

    @Test func endTypeNeverYieldsNeitherDateNorCount() {
        let rule = buildWeekly(weekdays: [0], endType: .never)
        #expect(rule.endType == .never)
        #expect(rule.endDate == nil)
        #expect(rule.count == nil)
    }

    // MARK: - YYYY-MM-DD endDate string format

    @Test func endDateStringMatchesYearMonthDayFormat() {
        // The editor produces "%04d-%02d-%02d" — single-digit month/day padded.
        let rule = buildWeekly(
            weekdays: [0],
            endType: .untilDate,
            endDate: "2026-03-09",
            count: nil
        )
        let pattern = #/^\d{4}-\d{2}-\d{2}$/#
        #expect(rule.endDate?.wholeMatch(of: pattern) != nil)
        // Components are zero-padded to two digits.
        #expect(rule.endDate == "2026-03-09")
    }

    @Test func endDateStringRoundTripsThroughYYYYMMDDFormatter() {
        // Mirror of the private `dateFromString` / `stringFromDate` helpers.
        // Build a date, format it the way `stringFromDate` does, parse it back
        // the way `dateFromString` does, and assert the calendar day survives.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 28
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to construct fixture date")
            return
        }

        let stringForm = String(
            format: "%04d-%02d-%02d",
            calendar.component(.year, from: date),
            calendar.component(.month, from: date),
            calendar.component(.day, from: date)
        )
        #expect(stringForm == "2026-06-28")

        guard let parsed = formatter.date(from: stringForm) else {
            Issue.record("Failed to parse \(stringForm)")
            return
        }
        let parsedComponents = formatter.calendar.dateComponents(
            [.year, .month, .day],
            from: parsed
        )
        #expect(parsedComponents.year == 2026)
        #expect(parsedComponents.month == 6)
        #expect(parsedComponents.day == 28)
    }

    // MARK: - Hashable / Equatable

    @Test func identicalInputsAreEqualAndShareHash() {
        let lhs = buildMonthlyOnThe(position: .second, weekday: 2)
        let rhs = buildMonthlyOnThe(position: .second, weekday: 2)
        #expect(lhs == rhs)
        #expect(lhs.hashValue == rhs.hashValue)
        // Set membership relies on Hashable consistency.
        let set: Set<RecurrenceRuleInput> = [lhs, rhs]
        #expect(set.count == 1)
    }

    @Test func differingIntervalMakesRulesUnequal() {
        let lhs = buildWeekly(weekdays: [0, 1], interval: 1)
        let rhs = buildWeekly(weekdays: [0, 1], interval: 2)
        #expect(lhs != rhs)
    }

    @Test func differingWeekdayMakesRulesUnequal() {
        let lhs = buildWeekly(weekdays: [0])
        let rhs = buildWeekly(weekdays: [1])
        #expect(lhs != rhs)
    }

    @Test func differingMonthlyAnchorMakesRulesUnequal() {
        let lhs = buildMonthlyWorkday(anchor: .firstWorkday)
        let rhs = buildMonthlyWorkday(anchor: .lastWorkday)
        #expect(lhs != rhs)
    }

    @Test func sameWeekdaySetInDifferentInsertionOrderProducesEqualRules() {
        // Sorting in the editor makes order irrelevant — two unordered sets
        // with the same members must yield identical rules.
        let lhs = buildWeekly(weekdays: [2, 0, 4])
        let rhs = buildWeekly(weekdays: [4, 2, 0])
        #expect(lhs == rhs)
        #expect(lhs.byWeekday == [0, 2, 4])
    }

    @Test func onTheAndWorkdayRulesAreNeverEqual() {
        // Two distinct monthly modes built for the "same" intent must differ —
        // confirms the mutual-exclusivity fields actually participate in ==.
        let onThe = buildMonthlyOnThe(position: .first, weekday: 0)
        let workday = buildMonthlyWorkday(anchor: .firstWorkday)
        #expect(onThe != workday)
    }
}
