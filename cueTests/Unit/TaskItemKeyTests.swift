//
//  TaskItemKeyTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// Tests for `TaskItem.makeKey(seriesId:occurrenceStart:)` — the composite
/// occurrence-key builder that backs the `@Attribute(.unique) occurrenceKey`
/// constraint. The key's stability and whole-second precision are what make the
/// SwiftData uniqueness/upsert behavior correct, so they are pinned here.
@MainActor
struct TaskItemKeyTests {
    /// A non-fractional ISO-8601 string the default `ISO8601DateFormatter` emits,
    /// so we can assert the exact key shape rather than re-deriving the format.
    private static let isoNoFraction = "2023-11-14T22:13:20Z"

    /// The instant matching ``isoNoFraction`` (1_700_000_000s since epoch, on a
    /// whole second so it round-trips through the whole-second formatter).
    private let wholeSecondStart = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func nilStartYieldsTrailingHashOneOffForm() {
        let key = TaskItem.makeKey(seriesId: "series-1", occurrenceStart: nil)
        #expect(key == "series-1#")
    }

    @Test func nonNilStartYieldsHashThenIso8601() {
        let key = TaskItem.makeKey(seriesId: "series-1", occurrenceStart: wholeSecondStart)
        #expect(key == "series-1#\(Self.isoNoFraction)")
    }

    @Test func sameSeriesAndStartProduceIdenticalKey() {
        let first = TaskItem.makeKey(seriesId: "series-1", occurrenceStart: wholeSecondStart)
        let second = TaskItem.makeKey(seriesId: "series-1", occurrenceStart: wholeSecondStart)
        #expect(first == second)
    }

    @Test func sameSeriesAndNilStartProduceIdenticalKey() {
        let first = TaskItem.makeKey(seriesId: "series-1", occurrenceStart: nil)
        let second = TaskItem.makeKey(seriesId: "series-1", occurrenceStart: nil)
        #expect(first == second)
    }

    @Test func differentSeriesIdProducesDifferentKey() {
        let keyA = TaskItem.makeKey(seriesId: "series-a", occurrenceStart: wholeSecondStart)
        let keyB = TaskItem.makeKey(seriesId: "series-b", occurrenceStart: wholeSecondStart)
        #expect(keyA != keyB)
    }

    @Test func differentStartProducesDifferentKey() {
        let laterStart = wholeSecondStart.addingTimeInterval(60)
        let keyEarly = TaskItem.makeKey(seriesId: "series-1", occurrenceStart: wholeSecondStart)
        let keyLate = TaskItem.makeKey(seriesId: "series-1", occurrenceStart: laterStart)
        #expect(keyEarly != keyLate)
    }

    @Test func nilStartDiffersFromAnyDatedStart() {
        let oneOff = TaskItem.makeKey(seriesId: "series-1", occurrenceStart: nil)
        let dated = TaskItem.makeKey(seriesId: "series-1", occurrenceStart: wholeSecondStart)
        #expect(oneOff != dated)
    }

    /// Documents the INTENDED `.unique` behavior: the formatter uses default
    /// options (no fractional seconds), so a start and the same start plus a
    /// sub-second fraction collapse to the SAME key. Two occurrences within one
    /// second therefore share an occurrence identity by design.
    @Test func subSecondFractionCollapsesToSameKey() {
        let withFraction = wholeSecondStart.addingTimeInterval(0.4)
        let whole = TaskItem.makeKey(seriesId: "series-1", occurrenceStart: wholeSecondStart)
        let fractional = TaskItem.makeKey(seriesId: "series-1", occurrenceStart: withFraction)
        #expect(whole == fractional)
    }

    @Test func aboveWholeSecondBoundaryDoesNotCollapse() {
        let nextSecond = wholeSecondStart.addingTimeInterval(1)
        let whole = TaskItem.makeKey(seriesId: "series-1", occurrenceStart: wholeSecondStart)
        let later = TaskItem.makeKey(seriesId: "series-1", occurrenceStart: nextSecond)
        #expect(whole != later)
    }
}
