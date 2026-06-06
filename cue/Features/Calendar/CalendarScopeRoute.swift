//
//  CalendarScopeRoute.swift
//  cue
//

import Foundation

/// Drill-in routes for the Calendar tab's scope navigation. Pushed onto the
/// stack to zoom Year → Month → Day (back-swipe zooms out). Kept distinct from
/// `CalendarRoute` (`.newEvent`), which is a plain slide push with no zoom.
///
/// The associated `Date`s double as `matchedTransitionSource` / `.zoom`
/// ids, so they must be canonical keys: a `startOfMonth` for `.month`, a
/// `startOfDay` for `.day`.
enum CalendarScopeRoute: Hashable {
    case month(Date)
    case day(Date)
    /// Push the task-detail screen for a specific occurrence.
    case taskDetail(ScheduleEvent)
}
