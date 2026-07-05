//
//  ReminderOffsetTests.swift
//  cueTests
//
//  Pure value-logic tests for ReminderOffset.nearest(to:), the CaseIterable
//  cycle (`next`), and EditableReminder <-> wire mapping. No SwiftData, no
//  network — every assertion is over deterministic in-memory values.
//

import Foundation
import Testing
@testable import cue

struct ReminderOffsetTests {

    // MARK: - nearest(to:) exact matches

    @Test func nearestReturnsExactCaseForEveryPreset() {
        #expect(ReminderOffset.nearest(to: -5) == .fiveMinBefore)
        #expect(ReminderOffset.nearest(to: -15) == .fifteenMinBefore)
        #expect(ReminderOffset.nearest(to: -30) == .thirtyMinBefore)
        #expect(ReminderOffset.nearest(to: -60) == .oneHourBefore)
        #expect(ReminderOffset.nearest(to: -1440) == .oneDayBefore)
        #expect(ReminderOffset.nearest(to: 0) == .atEventTime)
        #expect(ReminderOffset.nearest(to: 15) == .fifteenMinAfter)
    }

    @Test func nearestExactMatchPreservesRawOffset() {
        for offset in ReminderOffset.allCases {
            let resolved = ReminderOffset.nearest(to: offset.offsetMinutes)
            #expect(resolved == offset)
            #expect(resolved.offsetMinutes == offset.offsetMinutes)
        }
    }

    // MARK: - nearest(to:) non-matching snaps to closest by absolute distance

    @Test func nearestSnapsToCloserNeighbor() {
        // -7 is 2 from -5 and 8 from -15 -> -5 wins.
        #expect(ReminderOffset.nearest(to: -7) == .fiveMinBefore)
        // -20 is 5 from -15 and 10 from -30 -> -15 wins.
        #expect(ReminderOffset.nearest(to: -20) == .fifteenMinBefore)
        // -120 is 60 from -60 and 1320 from -1440 -> -60 wins.
        #expect(ReminderOffset.nearest(to: -120) == .oneHourBefore)
        // 5 is 5 from 0 and 10 from 15 -> 0 wins.
        #expect(ReminderOffset.nearest(to: 5) == .atEventTime)
        // 100 is 85 from 15 and far from everything else -> 15 wins.
        #expect(ReminderOffset.nearest(to: 100) == .fifteenMinAfter)
        // -5000 is well past the largest negative preset -> -1440 wins.
        #expect(ReminderOffset.nearest(to: -5000) == .oneDayBefore)
    }

    @Test func nearestTieFavorsEarlierCaseInAllCases() {
        // -10 is equidistant (5) from -5 and -15. Swift's min(by:) keeps the
        // first element when the predicate is a strict `<`, so the case appearing
        // earlier in allCases (.fiveMinBefore, -5) wins the tie.
        #expect(ReminderOffset.nearest(to: -10) == .fiveMinBefore)
        // 7 is 7 from 0 and 8 from 15 -> 0 (no tie, but adjacent-to-tie sanity).
        #expect(ReminderOffset.nearest(to: 7) == .atEventTime)
    }

    @Test func nearestFallbackContractReturnsRepresentablePreset() {
        // The `?? .fifteenMinBefore` fallback is unreachable while allCases is
        // non-empty (it always is for a CaseIterable enum with cases), but the
        // contract is "always lands on a representable chip". Assert that every
        // arbitrary server value resolves to a real allCases member.
        for value in [-9999, -300, -1, 1, 42, 1_000_000] {
            let resolved = ReminderOffset.nearest(to: value)
            #expect(ReminderOffset.allCases.contains(resolved))
        }
    }

    // MARK: - next: CaseIterable cycle with wraparound

    @Test func nextAdvancesThroughTheCycle() {
        #expect(ReminderOffset.fiveMinBefore.next == .fifteenMinBefore)
        #expect(ReminderOffset.fifteenMinBefore.next == .thirtyMinBefore)
        #expect(ReminderOffset.thirtyMinBefore.next == .oneHourBefore)
        #expect(ReminderOffset.oneHourBefore.next == .oneDayBefore)
        #expect(ReminderOffset.oneDayBefore.next == .atEventTime)
        #expect(ReminderOffset.atEventTime.next == .fifteenMinAfter)
    }

    @Test func nextWrapsAroundFromLastToFirst() {
        // .fifteenMinAfter is the final case -> wraps back to .fiveMinBefore.
        #expect(ReminderOffset.fifteenMinAfter.next == .fiveMinBefore)
    }

    @Test func nextVisitsEveryCaseExactlyOnceThenReturns() {
        var visited: [ReminderOffset] = []
        var current = ReminderOffset.fiveMinBefore
        for _ in ReminderOffset.allCases {
            visited.append(current)
            current = current.next
        }
        // After allCases.count advances we are back at the start.
        #expect(current == .fiveMinBefore)
        #expect(visited == ReminderOffset.allCases)
        #expect(Set(visited).count == ReminderOffset.allCases.count)
    }

    // MARK: - EditableReminder default init

    @Test func defaultInitUsesFifteenMinBeforeAndPush() {
        let reminder = EditableReminder()
        #expect(reminder.offset == .fifteenMinBefore)
        #expect(reminder.channel == .push)
    }

    @Test func defaultInitAssignsAUniqueIdentity() {
        let first = EditableReminder()
        let second = EditableReminder()
        #expect(first.id != second.id)
    }

    // MARK: - EditableReminder.input mapping to the wire payload

    @Test func inputMapsOffsetMinutesAndChannel() {
        let reminder = EditableReminder(offset: .oneHourBefore, channel: .telegram)
        let payload = reminder.input
        #expect(payload.offsetMinutes == -60)
        #expect(payload.channel == .telegram)
    }

    @Test func inputCarriesEveryPresetOffsetVerbatim() {
        for offset in ReminderOffset.allCases {
            let reminder = EditableReminder(offset: offset, channel: .push)
            #expect(reminder.input.offsetMinutes == offset.offsetMinutes)
            #expect(reminder.input.channel == .push)
        }
    }

    // MARK: - EditableReminder(from: ReminderDTO) snaps offset, preserves channel

    @Test func initFromDTOSnapsExactOffset() throws {
        let dto = try decodeReminderDTO(offsetMinutes: -30, channel: "PUSH")
        let reminder = EditableReminder(from: dto)
        #expect(reminder.offset == .thirtyMinBefore)
        #expect(reminder.channel == .push)
    }

    @Test func initFromDTOSnapsNonMatchingOffsetToNearest() throws {
        // -25 is 5 from -30 and 10 from -15 -> -30 wins.
        let dto = try decodeReminderDTO(offsetMinutes: -25, channel: "TELEGRAM")
        let reminder = EditableReminder(from: dto)
        #expect(reminder.offset == .thirtyMinBefore)
        #expect(reminder.channel == .telegram)
    }

    @Test func initFromDTOPreservesChannelIndependentOfOffsetSnapping() throws {
        let dto = try decodeReminderDTO(offsetMinutes: 999, channel: "TELEGRAM")
        let reminder = EditableReminder(from: dto)
        // 999 snaps to the nearest preset (15 / .fifteenMinAfter)...
        #expect(reminder.offset == .fifteenMinAfter)
        // ...while the channel rides through untouched.
        #expect(reminder.channel == .telegram)
    }

    @Test func initFromDTORoundTripsBackToInputForExactPresets() throws {
        let dto = try decodeReminderDTO(offsetMinutes: -1440, channel: "PUSH")
        let reminder = EditableReminder(from: dto)
        #expect(reminder.input.offsetMinutes == -1440)
        #expect(reminder.input.channel == .push)
    }

    // MARK: - Fixtures

    /// Builds a ``ReminderDTO`` by decoding a JSON fixture (its `Codable`
    /// conformance is synthesized; no memberwise init is exposed publicly here
    /// from the test's perspective, so we go through the decoder for fidelity).
    private func decodeReminderDTO(offsetMinutes: Int, channel: String) throws -> ReminderDTO {
        let json = """
        {
            "id": "rem-\(offsetMinutes)",
            "offsetMinutes": \(offsetMinutes),
            "channel": "\(channel)"
        }
        """
        let data = Data(json.utf8)
        return try JSONDecoder().decode(ReminderDTO.self, from: data)
    }
}
