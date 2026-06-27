//
//  CalendarScopeContracts.swift
//  cue
//

import UIKit

/// The three zoom levels of the UIKit calendar, ordered most-zoomed-out (0,
/// `.year`) to most-zoomed-in (2, `.day`). Scopes are *zoom levels of one
/// surface*, not navigation destinations — the container cross-zooms between
/// adjacent levels.
///
/// UIKit-side counterpart of the SwiftUI ``CalendarScope``; kept as a separate
/// type so the UIKit surface owns its contracts without importing SwiftUI ones.
enum CalendarScopeKind: Int, Comparable {
    case year = 0
    case month = 1
    case day = 2

    static func < (lhs: CalendarScopeKind, rhs: CalendarScopeKind) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The adjacent scope when zooming in (year → month → day), or nil at `.day`.
    var zoomedIn: CalendarScopeKind? { CalendarScopeKind(rawValue: rawValue + 1) }

    /// The adjacent scope when zooming out (day → month → year), or nil at `.year`.
    var zoomedOut: CalendarScopeKind? { CalendarScopeKind(rawValue: rawValue - 1) }
}

/// A single calendar scope rendered as a `UIViewController` (in practice a
/// `UICollectionViewController`). The container holds the active scope — and,
/// during a zoom, the adjacent one — via child-VC containment and talks to each
/// only through this contract.
///
/// All members run on the main actor: the scopes, the container, and the zoom
/// controller are `@MainActor` (Swift 6, MainActor-default isolation).
@MainActor
protocol CalendarScopeViewController: UIViewController {
    /// Which zoom level this scope renders.
    var kind: CalendarScopeKind { get }

    /// The container, notified of unit/event selection and Today requests.
    var scopeDelegate: CalendarScopeDelegate? { get set }

    /// Re-styles the whole scope (colors + Dynamic-Type fonts). Called on theme
    /// change and content-size-category change; cheap to call with an unchanged
    /// theme (`CalendarTheme` is `Equatable`).
    func apply(theme: CalendarTheme)

    /// Enables/disables the scope's own scrolling. The container disables it for
    /// the duration of a zoom transition so the pinch/pan don't fight.
    func setScrollEnabled(_ isEnabled: Bool)

    /// Scrolls so the section/cell for `unit` (a day/month/year start anchor) is
    /// centered. Used to align a scope after a cross-scope zoom or a Today jump.
    func center(on unit: Date, animated: Bool)

    /// The frame of `unit`'s cell, converted into `coordinateSpace`, or nil when
    /// that cell isn't currently realized. The zoom controller anchors the
    /// cross-scale animation on this rect.
    func anchorFrame(forUnit unit: Date, in coordinateSpace: UICoordinateSpace) -> CGRect?

    /// The unit (day/month/year start anchor) whose cell contains `point`
    /// expressed in `coordinateSpace`, or nil when no cell is hit. Used to pick
    /// the anchor cell under a pinch's start point.
    func unit(at point: CGPoint, in coordinateSpace: UICoordinateSpace) -> Date?
}

/// Callbacks a ``CalendarScopeViewController`` sends up to its container: a unit
/// was tapped (drive an anchored zoom into the inner scope), an event was tapped
/// (push task detail through the SwiftUI host), or the Jump-to-Today control was
/// used.
@MainActor
protocol CalendarScopeDelegate: AnyObject {
    /// A unit cell (a day in month, a month in year) was selected. `cellFrame`
    /// is that cell's frame in the container's coordinate space, so the zoom
    /// controller can anchor the zoom-in on it.
    func scope(
        _ scope: CalendarScopeViewController,
        didSelectUnit unit: Date,
        cellFrame: CGRect
    )

    /// An event card was tapped (not its completion toggle). The container
    /// forwards it to the SwiftUI host to push the task-detail screen.
    func scope(_ scope: CalendarScopeViewController, didSelectEvent event: OccurrenceVM)

    /// The Jump-to-Today control was used while already on the current unit, so
    /// the container should zoom one level in toward today.
    func scopeDidRequestToday(_ scope: CalendarScopeViewController)
}
