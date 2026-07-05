//
//  RecurrenceSummaryTests.swift
//  cueTests
//
//  Unit tests for `RecurrenceRuleInput.humanSummary` — the localized,
//  human-readable summary builder defined in
//  `cue/Features/Calendar/Recurrence/RecurrenceEditor.swift`.
//
//  The property assembles a string from localized fragments:
//    • interval==1 → "Every <unit>" / interval>1 → "Every N <units>"
//    • weekly → appends sorted weekday names ("on Mon, Wed")
//    • monthly → exactly one of anchor / nth-weekday / day-of-month (if/else-if)
//    • end suffix → " · <date>" (.untilDate) / " · for N" (.count) / none (.never)
//
//  Localized values resolve against the app bundle's English strings via
//  `@testable import cue`. Where an exact English phrase is stable we assert it;
//  where structure matters more than wording we assert `contains` / shape.
//

import Foundation
import Testing
@testable import cue

@MainActor
struct RecurrenceSummaryTests {

    // MARK: - Helpers

    /// Builds a `RecurrenceRuleInput` with sensible defaults so each test only
    /// specifies the fields under test.
    private func makeRule(
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        byWeekday: [Int]? = nil,
        byMonthDay: [Int]? = nil,
        byMonth: [Int]? = nil,
        bySetPos: [Int]? = nil,
        monthlyAnchor: MonthlyAnchorMode? = nil,
        endType: RecurrenceEndType = .never,
        endDate: String? = nil,
        count: Int? = nil
    ) -> RecurrenceRuleInput {
        RecurrenceRuleInput(
            frequency: frequency,
            interval: interval,
            byWeekday: byWeekday,
            byMonthDay: byMonthDay,
            byMonth: byMonth,
            bySetPos: bySetPos,
            monthlyAnchor: monthlyAnchor,
            endType: endType,
            endDate: endDate,
            count: count
        )
    }

    // MARK: - interval == 1 → singular "Every <unit>"

    @Test func dailySingularUsesEverySingleUnit() {
        let summary = makeRule(frequency: .daily, interval: 1).humanSummary
        #expect(summary == "Every day")
    }

    @Test func weeklySingularUsesEverySingleUnit() {
        let summary = makeRule(frequency: .weekly, interval: 1).humanSummary
        #expect(summary == "Every week")
    }

    @Test func monthlySingularUsesEverySingleUnit() {
        let summary = makeRule(frequency: .monthly, interval: 1).humanSummary
        #expect(summary == "Every month")
    }

    @Test func yearlySingularUsesEverySingleUnit() {
        let summary = makeRule(frequency: .yearly, interval: 1).humanSummary
        #expect(summary == "Every year")
    }

    // MARK: - interval > 1 → plural "Every N <units>"

    @Test func dailyPluralUsesEveryNUnits() {
        let summary = makeRule(frequency: .daily, interval: 2).humanSummary
        #expect(summary == "Every 2 days")
    }

    @Test func weeklyPluralUsesEveryNUnits() {
        let summary = makeRule(frequency: .weekly, interval: 3).humanSummary
        #expect(summary == "Every 3 weeks")
    }

    @Test func monthlyPluralUsesEveryNUnits() {
        let summary = makeRule(frequency: .monthly, interval: 2).humanSummary
        #expect(summary == "Every 2 months")
    }

    @Test func yearlyPluralUsesEveryNUnits() {
        let summary = makeRule(frequency: .yearly, interval: 5).humanSummary
        #expect(summary == "Every 5 years")
    }

    // MARK: - Weekly weekday suffix

    @Test func weeklyAppendsSingleWeekdayName() {
        // index 0 == Mon
        let summary = makeRule(frequency: .weekly, byWeekday: [0]).humanSummary
        #expect(summary == "Every week on Mon")
    }

    @Test func weeklySortsWeekdayNamesRegardlessOfInputOrder() {
        // Unsorted input [2, 0] (Wed, Mon) must render as "Mon, Wed".
        let summary = makeRule(frequency: .weekly, byWeekday: [2, 0]).humanSummary
        #expect(summary == "Every week on Mon, Wed")
    }

    @Test func weeklyRendersAllSevenDaysInOrder() {
        let summary = makeRule(frequency: .weekly, byWeekday: [6, 5, 4, 3, 2, 1, 0]).humanSummary
        #expect(summary == "Every week on Mon, Tue, Wed, Thu, Fri, Sat, Sun")
    }

    @Test func weeklyEmptyWeekdayArrayEmitsNoSuffix() {
        let summary = makeRule(frequency: .weekly, byWeekday: []).humanSummary
        #expect(summary == "Every week")
    }

    @Test func weeklyNilWeekdayEmitsNoSuffix() {
        let summary = makeRule(frequency: .weekly, byWeekday: nil).humanSummary
        #expect(summary == "Every week")
    }

    // MARK: - weekdayName index bounds (0..6 valid, out-of-range compactMapped out)

    @Test func weeklyOutOfRangeWeekdayIndicesAreDroppedKeepingValidOnes() {
        // 7 and -1 are out of bounds; only 0 (Mon) and 6 (Sun) survive.
        let summary = makeRule(frequency: .weekly, byWeekday: [7, 0, -1, 6]).humanSummary
        #expect(summary.contains("Mon"))
        #expect(summary.contains("Sun"))
        // Sorted order puts the negative index first but it is compactMapped out,
        // so the rendered list is exactly "Mon, Sun".
        #expect(summary == "Every week on Mon, Sun")
    }

    @Test func weeklyAllWeekdayIndicesOutOfRangeEmitsNoSuffix() {
        let summary = makeRule(frequency: .weekly, byWeekday: [7, 8, -1]).humanSummary
        // No valid names → the "on …" fragment is skipped entirely.
        #expect(summary == "Every week")
    }

    @Test func weekdayNameLowerBoundIndexZeroIsValid() {
        let summary = makeRule(frequency: .weekly, byWeekday: [0]).humanSummary
        #expect(summary.contains("Mon"))
    }

    @Test func weekdayNameUpperBoundIndexSixIsValid() {
        let summary = makeRule(frequency: .weekly, byWeekday: [6]).humanSummary
        #expect(summary.contains("Sun"))
    }

    // MARK: - Monthly precedence: anchor > (bySetPos + byWeekday) > byMonthDay

    @Test func monthlyAnchorWinsOverNthWeekdayAndDayOfMonth() {
        // All three monthly selectors populated; anchor must win (first if-branch).
        let summary = makeRule(
            frequency: .monthly,
            byWeekday: [0],
            byMonthDay: [15],
            bySetPos: [1],
            monthlyAnchor: .firstWorkday
        ).humanSummary

        #expect(summary.contains("first working day"))
        // Neither the nth-weekday nor the day-of-month fragments should appear.
        #expect(!summary.contains("on day 15"))
        #expect(!summary.contains("First Mon"))
    }

    @Test func monthlyNthWeekdayWinsOverDayOfMonthWhenNoAnchor() {
        // bySetPos+byWeekday present alongside byMonthDay, no anchor → nth-weekday wins.
        let summary = makeRule(
            frequency: .monthly,
            byWeekday: [0],
            byMonthDay: [15],
            bySetPos: [1]
        ).humanSummary

        #expect(summary.contains("on the First Mon"))
        #expect(!summary.contains("on day 15"))
    }

    @Test func monthlyDayOfMonthUsedWhenNoAnchorAndNoNthWeekday() {
        let summary = makeRule(
            frequency: .monthly,
            byMonthDay: [15]
        ).humanSummary

        #expect(summary == "Every month on day 15")
    }

    @Test func monthlyDayOfMonthSortsAndJoinsMultipleDays() {
        let summary = makeRule(
            frequency: .monthly,
            byMonthDay: [15, 1, 8]
        ).humanSummary

        #expect(summary == "Every month on day 1, 8, 15")
    }

    @Test func monthlyEmptyDayOfMonthEmitsNoSuffix() {
        let summary = makeRule(frequency: .monthly, byMonthDay: []).humanSummary
        #expect(summary == "Every month")
    }

    // MARK: - nth-weekday fragment requirements

    @Test func nthWeekdayFirstPositionRendersFirst() {
        let summary = makeRule(
            frequency: .monthly,
            byWeekday: [0],
            bySetPos: [1]
        ).humanSummary
        #expect(summary == "Every month on the First Mon")
    }

    @Test func nthWeekdayLastPositionMapsNegativeOneToLast() {
        // bySetPos == [-1] → NthPosition(rawValue: -1) == .last
        let summary = makeRule(
            frequency: .monthly,
            byWeekday: [2],
            bySetPos: [-1]
        ).humanSummary
        #expect(summary == "Every month on the Last Wed")
    }

    @Test func nthWeekdayUsesFirstElementOfEachArray() {
        // Only positions.first and byWeekday.first are consulted.
        let summary = makeRule(
            frequency: .monthly,
            byWeekday: [1, 4],
            bySetPos: [2, 3]
        ).humanSummary
        // Second position, Tuesday.
        #expect(summary == "Every month on the Second Tue")
    }

    @Test func nthWeekdayInvalidPositionRawValueDropsFragment() {
        // bySetPos == [99] has no matching NthPosition → the whole monthly
        // if/else-if chain falls through (no byMonthDay either) → no suffix.
        let summary = makeRule(
            frequency: .monthly,
            byWeekday: [0],
            bySetPos: [99]
        ).humanSummary
        #expect(summary == "Every month")
    }

    @Test func nthWeekdayInvalidWeekdayIndexDropsFragment() {
        // byWeekday.first == 9 → weekdayName returns nil → fragment dropped.
        let summary = makeRule(
            frequency: .monthly,
            byWeekday: [9],
            bySetPos: [1]
        ).humanSummary
        #expect(summary == "Every month")
    }

    @Test func nthWeekdayMissingWeekdayFallsBackToDayOfMonth() {
        // bySetPos present but byWeekday nil → nth branch fails its guard, so the
        // else-if day-of-month branch handles it.
        let summary = makeRule(
            frequency: .monthly,
            byMonthDay: [3],
            bySetPos: [1]
        ).humanSummary
        #expect(summary == "Every month on day 3")
    }

    // MARK: - Monthly anchor variants

    @Test func monthlyAnchorFirstWorkdayFragment() {
        let summary = makeRule(frequency: .monthly, monthlyAnchor: .firstWorkday).humanSummary
        #expect(summary == "Every month on the first working day")
    }

    @Test func monthlyAnchorLastWorkdayFragment() {
        let summary = makeRule(frequency: .monthly, monthlyAnchor: .lastWorkday).humanSummary
        #expect(summary == "Every month on the last working day")
    }

    @Test func monthlyAnchorDayBeforeLastWorkdayFragment() {
        let summary = makeRule(frequency: .monthly, monthlyAnchor: .dayBeforeLastWorkday).humanSummary
        #expect(summary == "Every month the day before the last working day")
    }

    // MARK: - Non-weekly/non-monthly frequencies ignore selectors

    @Test func dailyIgnoresWeekdaySelector() {
        // byWeekday only matters for .weekly — daily must not append it.
        let summary = makeRule(frequency: .daily, byWeekday: [0, 1]).humanSummary
        #expect(summary == "Every day")
    }

    @Test func yearlyIgnoresMonthlySelectors() {
        let summary = makeRule(
            frequency: .yearly,
            byMonthDay: [10],
            bySetPos: [1],
            monthlyAnchor: .firstWorkday
        ).humanSummary
        #expect(summary == "Every year")
    }

    // MARK: - End suffix

    @Test func endNeverAppendsNothing() {
        let summary = makeRule(frequency: .weekly, endType: .never).humanSummary
        #expect(summary == "Every week")
        #expect(!summary.contains("·"))
    }

    @Test func endUntilDateAppendsDateFragment() {
        let summary = makeRule(
            frequency: .weekly,
            endType: .untilDate,
            endDate: "2027-01-01"
        ).humanSummary
        #expect(summary == "Every week · 2027-01-01")
    }

    @Test func endUntilDateWithoutDateAppendsNothing() {
        // endType == .untilDate but endDate nil → guard skips the suffix.
        let summary = makeRule(
            frequency: .weekly,
            endType: .untilDate,
            endDate: nil
        ).humanSummary
        #expect(summary == "Every week")
    }

    @Test func endCountAppendsForCountFragment() {
        let summary = makeRule(
            frequency: .weekly,
            endType: .count,
            count: 10
        ).humanSummary
        #expect(summary == "Every week · 10 times")
    }

    @Test func endCountWithoutCountAppendsNothing() {
        // endType == .count but count nil → guard skips the suffix.
        let summary = makeRule(
            frequency: .weekly,
            endType: .count,
            count: nil
        ).humanSummary
        #expect(summary == "Every week")
    }

    // MARK: - Combined: base + selector + end suffix

    @Test func weeklyWithWeekdaysAndUntilDateCombinesAllFragments() {
        let summary = makeRule(
            frequency: .weekly,
            interval: 2,
            byWeekday: [2, 0],
            endType: .untilDate,
            endDate: "2027-01-01"
        ).humanSummary
        #expect(summary == "Every 2 weeks on Mon, Wed · 2027-01-01")
    }

    @Test func monthlyNthWeekdayWithCountCombinesAllFragments() {
        let summary = makeRule(
            frequency: .monthly,
            byWeekday: [4],
            bySetPos: [-1],
            endType: .count,
            count: 3
        ).humanSummary
        #expect(summary == "Every month on the Last Fri · 3 times")
    }
}
