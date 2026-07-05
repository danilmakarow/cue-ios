//
//  RecurrenceEngineTypes.swift
//  cue
//
//  Value types for the client-side recurrence engine (full-calendar-replica-sync
//  §2/§4.4). The engine is a pure Swift port of the backend
//  `RecurrenceRuleService.expandOccurrences` (cue-api) and must reproduce its
//  output to epoch-millisecond exactness — enforced by the golden parity-fixture
//  corpus (`RecurrenceParityTests`). These types are the engine's inputs/outputs;
//  they deliberately do NOT depend on SwiftData or Networking so the engine stays
//  pure and unit-testable.
//
//  The frequency / end-type / monthly-anchor enums are reused verbatim from
//  `APIModels.swift` (same `String` raw values as the backend), so a decoded
//  wire/fixture config maps straight in.
//

import Foundation

/// The inline recurrence rule the engine expands — mirrors the backend
/// `RecurrenceConfig` (ADR 0054) field-for-field. Weekday encoding for
/// `byWeekday`: 0 = Monday … 6 = Sunday (ISO-8601 ordering, matching the server).
nonisolated struct RecurrenceConfig: Codable, Sendable, Hashable {
    /// How often the series repeats.
    let frequency: RecurrenceFrequency
    /// Repeat every N periods of the frequency (>= 1; values < 1 are treated as 1).
    let interval: Int
    /// Weekday ordinals (0 = Monday … 6 = Sunday); nil means no weekday restriction.
    let byWeekday: [Int]?
    /// Days of the month (1-31); nil means no month-day restriction.
    let byMonthDay: [Int]?
    /// Months (1-12); nil means no month restriction.
    let byMonth: [Int]?
    /// MONTHLY nth-weekday ordinals (BYSETPOS): 1…4 = first…fourth, -1 = last.
    /// Honored only for MONTHLY and only when `byWeekday` is also set.
    let bySetPos: [Int]?
    /// MONTHLY working-day anchor; takes precedence over `byMonthDay` / `byWeekday`.
    let monthlyAnchor: MonthlyAnchorMode?
    /// How the series terminates.
    let endType: RecurrenceEndType
    /// "YYYY-MM-DD" the series ends on (inclusive); non-nil only for `.untilDate`.
    let endDate: String?
    /// Number of occurrences, counted from the series origin; non-nil only for `.count`.
    let count: Int?

    init(
        frequency: RecurrenceFrequency,
        interval: Int,
        byWeekday: [Int]? = nil,
        byMonthDay: [Int]? = nil,
        byMonth: [Int]? = nil,
        bySetPos: [Int]? = nil,
        monthlyAnchor: MonthlyAnchorMode? = nil,
        endType: RecurrenceEndType = .never,
        endDate: String? = nil,
        count: Int? = nil
    ) {
        self.frequency = frequency
        self.interval = interval
        self.byWeekday = byWeekday
        self.byMonthDay = byMonthDay
        self.byMonth = byMonth
        self.bySetPos = bySetPos
        self.monthlyAnchor = monthlyAnchor
        self.endType = endType
        self.endDate = endDate
        self.count = count
    }
}

/// A per-occurrence divergence applied during expansion — the client mirror of the
/// backend `TaskOccurrenceException`. Keyed by `originalStartAt` (the rule-generated
/// UTC instant BEFORE any edit), matched at epoch-millisecond equality.
nonisolated struct RecurrenceException: Sendable, Hashable {
    /// The rule-generated instant this exception keys (RECURRENCE-ID).
    let originalStartAt: Date
    /// When true the occurrence is dropped from the expansion.
    let isSkipped: Bool
    /// Moved start; when present replaces the generated start.
    let overrideStartAt: Date?
    /// Moved/resized end; when present replaces the derived end.
    let overrideEndAt: Date?
    /// Renamed title; when present replaces the anchor title.
    let overrideTitle: String?
    /// Per-instance completion timestamp.
    let completedAt: Date?

    init(
        originalStartAt: Date,
        isSkipped: Bool = false,
        overrideStartAt: Date? = nil,
        overrideEndAt: Date? = nil,
        overrideTitle: String? = nil,
        completedAt: Date? = nil
    ) {
        self.originalStartAt = originalStartAt
        self.isSkipped = isSkipped
        self.overrideStartAt = overrideStartAt
        self.overrideEndAt = overrideEndAt
        self.overrideTitle = overrideTitle
        self.completedAt = completedAt
    }
}

/// One computed instance produced by ``RecurrenceEngine``. Mirrors the backend
/// `Occurrence`'s expansion-relevant fields; the higher projection layer adds
/// suppression / merge / parent-child metadata (Phase 3).
nonisolated struct EngineOccurrence: Sendable, Hashable {
    /// Rule-generated start BEFORE any override — the stable instance identity.
    let originalStart: Date
    /// Effective start with any `overrideStartAt` applied.
    let occurrenceStart: Date
    /// Effective end with any `overrideEndAt` applied; nil for an open-ended anchor.
    let occurrenceEnd: Date?
    /// Effective title with any `overrideTitle` applied.
    let title: String
    /// Per-instance completion; nil when not completed.
    let completedAt: Date?
    /// True when a ``RecurrenceException`` row was applied to this instance.
    let isException: Bool
}
