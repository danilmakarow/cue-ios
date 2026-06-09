//
//  CalendarScope.swift
//  cue
//

import Foundation

/// The three zoom levels of the calendar, ordered from most zoomed-out to
/// most zoomed-in. Scopes are *zoom levels of one surface*, not navigation
/// destinations — `CalendarZoomContainer` cross-zooms between adjacent levels.
enum CalendarScope: Int, Comparable, Sendable {
    case year = 0
    case month = 1
    case day = 2

    static func < (lhs: CalendarScope, rhs: CalendarScope) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The adjacent scope when zooming out (day → month → year), or nil at year.
    var zoomedOut: CalendarScope? { CalendarScope(rawValue: rawValue - 1) }

    /// The adjacent scope when zooming in (year → month → day), or nil at day.
    var zoomedIn: CalendarScope? { CalendarScope(rawValue: rawValue + 1) }
}

/// An in-flight zoom between two adjacent scopes. `innerVisibility` is the
/// single animatable scalar the container renders from: 1 means the inner
/// (more zoomed-in) scope fills the screen, 0 means the outer scope does.
/// A pinch drives it interactively; commit/cancel animates it to 1 or 0.
struct ScopeZoomTransition {
    /// How the transition was initiated, which determines its resting state
    /// at gesture start and the commit threshold direction.
    enum Kind {
        /// Started at the outer scope, heading into `inner` (tap or pinch-open).
        case zoomIn
        /// Started at the inner scope, heading out to `outer` (pinch-close).
        case zoomOut
    }

    /// The more zoomed-in scope of the pair (rendered on top).
    let inner: CalendarScope
    /// The more zoomed-out scope of the pair (rendered underneath).
    let outer: CalendarScope
    let kind: Kind
    /// Frame of the inner scope's cell within the outer scope (the day's cell
    /// in the month grid, or the month's cell in the year grid), in the zoom
    /// container's coordinate space. Nil until the cell is realized; the
    /// container falls back to a centered rect.
    var anchorFrame: CGRect?
    /// 0 = outer fullscreen … 1 = inner fullscreen.
    var innerVisibility: CGFloat
}
