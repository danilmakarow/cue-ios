//
//  CalendarViewMode.swift
//  cue
//

import Foundation

/// Presentation mode for the Calendar tab. `CalendarView` switches
/// between rendering a `TimelineDayPage` and a `ListDayPage` based on
/// this value.
enum CalendarViewMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    /// Hour-by-hour timeline with events laid out by start/duration.
    case timeline
    /// Flat list of tasks for the day — like a TODO list.
    case list

    var id: String { rawValue }

    /// SF Symbol used by `ViewModeSwitcher`.
    var systemImage: String {
        switch self {
        case .timeline: return "calendar.day.timeline.left"
        case .list: return "list.bullet"
        }
    }

    /// Accessibility label.
    var displayName: String {
        switch self {
        case .timeline: return "Timeline"
        case .list: return "List"
        }
    }
}
