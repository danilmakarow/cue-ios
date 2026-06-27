//
//  ReminderOffset.swift
//  cue
//

import Foundation

/// The curated set of reminder offsets the reminders editor cycles through.
/// Each maps to a signed `offsetMinutes` relative to the task start: negative
/// fires before the event, positive after, zero at event time. Mirrors the
/// design spec's `OFFSETS` list.
enum ReminderOffset: Int, CaseIterable, Identifiable, Sendable {
    case fiveMinBefore = -5
    case fifteenMinBefore = -15
    case thirtyMinBefore = -30
    case oneHourBefore = -60
    case oneDayBefore = -1440
    case atEventTime = 0
    case fifteenMinAfter = 15

    var id: Int { rawValue }

    /// The signed offset in minutes sent to the backend (`ReminderInput.offsetMinutes`).
    var offsetMinutes: Int { rawValue }

    /// Human-readable label shown on the cycling offset chip.
    var label: String {
        switch self {
        case .fiveMinBefore: return String(localized: "reminder.offset.5minBefore")
        case .fifteenMinBefore: return String(localized: "reminder.offset.15minBefore")
        case .thirtyMinBefore: return String(localized: "reminder.offset.30minBefore")
        case .oneHourBefore: return String(localized: "reminder.offset.1hrBefore")
        case .oneDayBefore: return String(localized: "reminder.offset.1dayBefore")
        case .atEventTime: return String(localized: "reminder.offset.atEventTime")
        case .fifteenMinAfter: return String(localized: "reminder.offset.15minAfter")
        }
    }

    /// The offset whose `offsetMinutes` matches `minutes`, falling back to the
    /// nearest preset (then `.fifteenMinBefore`) when no exact match exists — so a
    /// reminder loaded from the server always lands on a representable chip.
    static func nearest(to minutes: Int) -> ReminderOffset {
        if let exact = allCases.first(where: { $0.rawValue == minutes }) {
            return exact
        }
        return allCases.min { lhs, rhs in
            abs(lhs.rawValue - minutes) < abs(rhs.rawValue - minutes)
        } ?? .fifteenMinBefore
    }

    /// The next preset in the cycle (wraps around), used by the offset chip's
    /// tap-to-advance interaction in the editor.
    var next: ReminderOffset {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return .fiveMinBefore }
        return all[(index + 1) % all.count]
    }
}

/// A single editable reminder row's state. Wraps a ``ReminderOffset`` + channel
/// and carries a stable identity so SwiftUI can diff rows as they are added,
/// removed, and reordered.
struct EditableReminder: Identifiable, Hashable, Sendable {
    let id: UUID
    var offset: ReminderOffset
    var channel: NotificationChannel

    init(id: UUID = UUID(), offset: ReminderOffset = .fifteenMinBefore, channel: NotificationChannel = .push) {
        self.id = id
        self.offset = offset
        self.channel = channel
    }

    /// The wire payload for this row.
    var input: ReminderInput {
        ReminderInput(offsetMinutes: offset.offsetMinutes, channel: channel)
    }

    /// Builds an editable row from a server reminder, snapping its offset to the
    /// nearest representable preset.
    init(from dto: ReminderDTO) {
        self.init(offset: .nearest(to: dto.offsetMinutes), channel: dto.channel)
    }
}
