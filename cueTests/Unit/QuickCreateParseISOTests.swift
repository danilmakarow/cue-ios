//
//  QuickCreateParseISOTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// Tests for ``QuickCreateWell/parseISO(_:)`` — the lenient draft-start ISO
/// parser that guards the assistant-draft -> form-prefill path. The load-bearing
/// behavior is the fractional-seconds-then-plain fallback: a draft start string
/// may arrive with or without a `.000` fraction, and either must resolve.
@MainActor
struct QuickCreateParseISOTests {
    /// 2026-06-28T09:30:00Z as a wall-clock reference (UTC).
    private var referenceComponents: DateComponents {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 28
        components.hour = 9
        components.minute = 30
        components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        return components
    }

    /// Expected instant for the UTC reference strings.
    private var referenceDate: Date? {
        Calendar(identifier: .gregorian).date(from: referenceComponents)
    }

    @Test func parsesFractionalSecondsZulu() throws {
        let parsed = try #require(QuickCreateWell.parseISO("2026-06-28T09:30:00.000Z"))
        #expect(parsed == referenceDate)
    }

    @Test func parsesWholeSecondZulu() throws {
        let parsed = try #require(QuickCreateWell.parseISO("2026-06-28T09:30:00Z"))
        #expect(parsed == referenceDate)
    }

    @Test func fractionalAndPlainResolveToSameInstant() throws {
        let fractional = try #require(QuickCreateWell.parseISO("2026-06-28T09:30:00.000Z"))
        let plain = try #require(QuickCreateWell.parseISO("2026-06-28T09:30:00Z"))
        #expect(fractional == plain)
    }

    @Test func parsesPositiveOffsetZone() throws {
        // +02:00 means 09:30 local == 07:30 UTC.
        let parsed = try #require(QuickCreateWell.parseISO("2026-06-28T09:30:00+02:00"))

        var utcComponents = referenceComponents
        utcComponents.hour = 7
        let expected = try #require(Calendar(identifier: .gregorian).date(from: utcComponents))
        #expect(parsed == expected)
    }

    @Test func parsesFractionalSecondsWithOffsetZone() throws {
        let parsed = try #require(QuickCreateWell.parseISO("2026-06-28T09:30:00.000+02:00"))

        var utcComponents = referenceComponents
        utcComponents.hour = 7
        let expected = try #require(Calendar(identifier: .gregorian).date(from: utcComponents))
        #expect(parsed == expected)
    }

    @Test func returnsNilForDateOnly() {
        #expect(QuickCreateWell.parseISO("2026-06-28") == nil)
    }

    @Test func returnsNilForEmptyString() {
        #expect(QuickCreateWell.parseISO("") == nil)
    }

    @Test func returnsNilForGarbage() {
        #expect(QuickCreateWell.parseISO("not-a-date") == nil)
    }

    @Test func returnsNilForWhitespace() {
        #expect(QuickCreateWell.parseISO("   ") == nil)
    }

    @Test func returnsNilForTimeWithoutZone() {
        // No zone designator -> ISO8601DateFormatter with .withInternetDateTime
        // requires a timezone, so this is not parseable by either strategy.
        #expect(QuickCreateWell.parseISO("2026-06-28T09:30:00") == nil)
    }
}
