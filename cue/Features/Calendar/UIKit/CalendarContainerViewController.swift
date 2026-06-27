//
//  CalendarContainerViewController.swift
//  cue
//

import SwiftData
import UIKit

/// The single zoomable surface that fuses the calendar's three scopes (year,
/// month, day) into one interactively-zoomable container — the UIKit
/// replacement for the SwiftUI `CalendarZoomContainer`.
///
/// **Containment.** It hosts the three ``CalendarScopeViewController``s via
/// child-VC containment. The **day scope is the resting/launch scope** (matching
/// the old container, which rested on `.day` and rendered it directly on cold
/// launch); the month and year scopes are **mounted lazily** on the first zoom-out
/// that needs them, then kept for reuse. During a transition the inner scope is
/// stacked above the outer.
///
/// **Zoom.** It owns a ``CalendarZoomController`` and wires its pinch onto the
/// container's view. It conforms to ``CalendarZoomHost`` so the controller can ask
/// it to mount scopes and re-parent them on settle, and to ``CalendarScopeDelegate``
/// so scope-reported selections drive the zoom:
/// - `scope(_:didSelectUnit:cellFrame:)` ⇒ animated zoom-**in** to the adjacent
///   inner scope, anchored on `cellFrame`.
/// - `scopeDidRequestToday(_:)` ⇒ animated zoom-**in** one level toward today
///   (the progressive Today from the old container).
/// - `scope(_:didSelectEvent:)` ⇒ forwarded to ``onSelectEvent``, which the
///   SwiftUI host sets to push task detail.
///
/// ## Public surface for the Integration engineer
/// ```swift
/// let container = CalendarContainerViewController(
///     user: user,
///     store: store,
///     adapter: adapter,
///     modelContext: modelContext,
///     theme: theme
/// )
/// container.onSelectEvent = { occurrence in /* push task detail */ }
/// // On SwiftUI theme / Dynamic-Type change:
/// container.apply(theme: rebuiltTheme)
/// // When the host toggles store.viewMode (timeline ⇄ list):
/// container.viewModeDidChange()
/// // Optional deep-link / today entry (sets selection + rests on the day scope):
/// container.jump(to: date)
/// ```
@MainActor
final class CalendarContainerViewController: UIViewController {

    // MARK: - Public surface

    /// Called when an event card is tapped in any scope (in practice the day
    /// scope). The SwiftUI host sets this to push the task-detail screen.
    var onSelectEvent: ((OccurrenceVM) -> Void)?

    // MARK: - Dependencies

    private let user: UserDTO
    private let store: CalendarStore
    private let adapter: CalendarDataAdapter
    private let modelContext: ModelContext
    private var theme: CalendarTheme

    /// The shared direction/velocity-aware prefetch planner, built once here and
    /// injected into all three scopes so they share one scroll estimate.
    private let prefetchCoordinator = PrefetchCoordinator()

    // MARK: - Scopes (day eager, month/year lazy)

    /// The day scope — the resting/launch scope, built eagerly.
    private lazy var dayScope: DayScopeViewController = makeScope(.day)
    /// The month scope, built on first zoom-out from day (or zoom-in from year).
    private var monthScope: MonthScopeViewController?
    /// The year scope, built on first zoom-out from month.
    private var yearScope: YearScopeViewController?

    /// The currently-resting scope. Starts as day.
    private var active: CalendarScopeViewController

    // MARK: - Zoom

    private lazy var zoom = CalendarZoomController(host: self)

    // MARK: - Init

    /// Designated initializer. Injected by the Integration engineer's
    /// representable/coordinator with the shared calendar dependencies.
    ///
    /// - Parameters:
    ///   - user: the authenticated user (passed through to the store-backed scopes).
    ///   - store: the shared calendar store (selection, view mode, sync, revision).
    ///   - adapter: the windowed read-side bridge over SwiftData the scopes observe.
    ///   - modelContext: the SwiftData context used by store sync/toggle calls.
    ///   - theme: the initial pushed UIKit theme.
    init(
        user: UserDTO,
        store: CalendarStore,
        adapter: CalendarDataAdapter,
        modelContext: ModelContext,
        theme: CalendarTheme
    ) {
        self.user = user
        self.store = store
        self.adapter = adapter
        self.modelContext = modelContext
        self.theme = theme
        // `active` is set to the day scope after super.init (it needs `self`).
        let placeholder = DayScopeViewController(
            store: store, adapter: adapter, modelContext: modelContext, theme: theme,
            prefetchCoordinator: prefetchCoordinator
        )
        self.active = placeholder
        super.init(nibName: nil, bundle: nil)
        // Adopt the eagerly-built day scope as the active one.
        self.active = dayScope
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = theme.background
        mountActiveScope()
        view.addGestureRecognizer(zoom.pinch)
    }

    /// Adds the resting day scope as the initial child, filling the container.
    private func mountActiveScope() {
        addChildScope(dayScope)
        dayScope.view.frame = view.bounds
        dayScope.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    // MARK: - Scope construction & containment

    /// Builds a scope VC of the given kind, wires this container as its delegate.
    /// Day is the only kind built more than once would be wrong — callers use the
    /// memoized `dayScope` / `monthScope` / `yearScope` accessors.
    private func makeScope<Scope: CalendarScopeViewController>(_ kind: CalendarScopeKind) -> Scope {
        let scope: CalendarScopeViewController
        switch kind {
        case .day:
            scope = DayScopeViewController(
                store: store, adapter: adapter, modelContext: modelContext, theme: theme,
                prefetchCoordinator: prefetchCoordinator
            )
        case .month:
            scope = MonthScopeViewController(
                store: store, adapter: adapter, modelContext: modelContext, theme: theme,
                prefetchCoordinator: prefetchCoordinator
            )
        case .year:
            scope = YearScopeViewController(
                store: store, adapter: adapter, modelContext: modelContext, theme: theme,
                prefetchCoordinator: prefetchCoordinator
            )
        }
        scope.scopeDelegate = self
        // Force-cast is safe: the switch builds exactly the requested concrete type.
        guard let typed = scope as? Scope else {
            fatalError("makeScope(\(kind)) produced the wrong concrete scope type")
        }
        return typed
    }

    /// Returns the memoized scope for `kind`, lazily building month/year the first
    /// time they're needed.
    private func scope(for kind: CalendarScopeKind) -> CalendarScopeViewController {
        switch kind {
        case .day:
            return dayScope
        case .month:
            if let monthScope { return monthScope }
            let built: MonthScopeViewController = makeScope(.month)
            monthScope = built
            return built
        case .year:
            if let yearScope { return yearScope }
            let built: YearScopeViewController = makeScope(.year)
            yearScope = built
            return built
        }
    }

    /// Adds `scope` as a child VC and inserts its view at the back (the container
    /// re-stacks during a transition). Idempotent — re-adding the active child is a
    /// no-op.
    private func addChildScope(_ scope: CalendarScopeViewController) {
        guard scope.parent == nil else { return }
        addChild(scope)
        scope.view.frame = view.bounds
        scope.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(scope.view, at: 0)
        scope.didMove(toParent: self)
    }

    /// Removes `scope` from containment (used to unmount the outgoing scope after a
    /// commit). The day scope is never removed — it's the resting launch scope and
    /// re-mounting it on every zoom would discard its pager state.
    private func removeChildScope(_ scope: CalendarScopeViewController) {
        guard scope !== dayScope, scope.parent != nil else { return }
        scope.willMove(toParent: nil)
        scope.view.removeFromSuperview()
        scope.removeFromParent()
    }

    // MARK: - Public methods

    /// Re-styles every built scope. The Integration engineer calls this from
    /// `updateUIViewController` (theme change) and `traitCollectionDidChange`
    /// (Dynamic Type). Cheap when unchanged — each scope early-outs on an equal
    /// theme.
    func apply(theme: CalendarTheme) {
        self.theme = theme
        view.backgroundColor = theme.background
        dayScope.apply(theme: theme)
        monthScope?.apply(theme: theme)
        yearScope?.apply(theme: theme)
    }

    /// Forwards a `store.viewMode` toggle to the day scope so its pages re-render
    /// in the new timeline/list mode. No-op for month/year (they have no mode).
    func viewModeDidChange() {
        dayScope.viewModeDidChange()
    }

    /// Sets the selection and recenters the **active** scope on `date`, keeping the
    /// current zoom level — the entry for the SwiftUI toolbar's Today control (and
    /// any future deep link). Each scope's `center(on:)` handles its own unit type
    /// (day/month/year), so a Today tap in the year scope recenters the year grid in
    /// place rather than collapsing to the day scope. If a transition is in flight
    /// it's a no-op (the caller should retry once settled).
    func jump(to date: Date) {
        guard !zoom.isTransitioning else { return }
        store.selectedDate = CalendarMath.startOfDay(date)
        // Delegate to the active scope's recenter logic — every scope knows how to
        // center itself on a date without changing the zoom level.
        active.center(on: date, animated: false)
    }
}

// MARK: - CalendarScopeDelegate

extension CalendarContainerViewController: CalendarScopeDelegate {

    /// A unit cell was tapped: animate a zoom-in into the adjacent inner scope,
    /// anchored on the reported `cellFrame` (already in this container's coordinate
    /// space). Selection was set by the reporting scope; we point the inner scope
    /// at the same unit through the controller.
    func scope(
        _ scope: CalendarScopeViewController,
        didSelectUnit unit: Date,
        cellFrame: CGRect
    ) {
        guard scope === active, let innerKind = scope.kind.zoomedIn else { return }
        zoom.zoomIn(to: innerKind, unit: unit, anchorFrame: cellFrame)
    }

    /// An event card was tapped — forward it to the SwiftUI host to push detail.
    func scope(_ scope: CalendarScopeViewController, didSelectEvent event: OccurrenceVM) {
        onSelectEvent?(event)
    }

    /// Progressive Today: zoom one level *in* toward today, anchored on today's
    /// unit in the active (outer) scope — mirroring the old container, where the
    /// month/year Jump-to-Today recenters then zooms one level in. At the day scope
    /// there's no inner level, so this is a no-op (the day scope handles its own
    /// recenter before ever calling this).
    func scopeDidRequestToday(_ scope: CalendarScopeViewController) {
        guard scope === active, let innerKind = scope.kind.zoomedIn else { return }
        let unit = todayUnit(for: innerKind)
        let anchor = scope.anchorFrame(forUnit: unit, in: view)
        zoom.zoomIn(to: innerKind, unit: unit, anchorFrame: anchor)
    }

    /// The unit a zoom-in toward `innerKind` should land on for "today": today's
    /// day when zooming to the day scope, today's month when zooming to month.
    private func todayUnit(for innerKind: CalendarScopeKind) -> Date {
        switch innerKind {
        case .day:
            return CalendarMath.startOfDay(.now)
        case .month:
            return CalendarMath.startOfMonth(.now)
        case .year:
            return CalendarMath.startOfYear(.now)
        }
    }
}

// MARK: - CalendarZoomHost

extension CalendarContainerViewController: CalendarZoomHost {

    var activeScope: CalendarScopeViewController { active }

    var zoomCoordinateSpace: UICoordinateSpace { view }

    /// Lazily builds + mounts the scope for `kind` (a no-op add if already a child)
    /// so it's ready to be a transition party.
    func mountScope(_ kind: CalendarScopeKind) -> CalendarScopeViewController? {
        let target = scope(for: kind)
        addChildScope(target)
        return target
    }

    /// The unit a freshly-mounted outer scope should center on when zooming out of
    /// the active scope: the active day's month, or the active month's year.
    func currentUnit(for outerKind: CalendarScopeKind) -> Date {
        switch outerKind {
        case .month:
            return CalendarMath.startOfMonth(store.selectedDate)
        case .year:
            // Zooming out from month → year: center the year on the month the month
            // scope currently shows (tracked via `selectedDate`'s month).
            return CalendarMath.startOfYear(store.selectedDate)
        case .day:
            return CalendarMath.startOfDay(store.selectedDate)
        }
    }

    /// Points shared selection at the unit a zoom-in will land on, before the
    /// animation, so the inner scope and `store.selectedDate` agree on commit.
    func willZoomIn(to kind: CalendarScopeKind, unit: Date) {
        switch kind {
        case .day:
            store.selectedDate = CalendarMath.startOfDay(unit)
        case .month, .year:
            // Month/year don't drive `selectedDate` directly; centering the scope
            // (done by the controller) is enough. Keep selection on the same day.
            break
        }
    }

    /// Stacks `inner` above `outer` for the transition (both already children).
    func beginTransition(inner: CalendarScopeViewController, outer: CalendarScopeViewController) {
        view.bringSubviewToFront(outer.view)
        view.bringSubviewToFront(inner.view)
        // The floating pinch recognizer lives on the container's view, which stays
        // on top of the children regardless of subview order, so no re-add needed.
    }

    /// Settles on `settled`, restores its scrolling, and unmounts `outgoing`.
    func endTransition(settled: CalendarScopeViewController, outgoing: CalendarScopeViewController) {
        active = settled
        view.bringSubviewToFront(settled.view)
        settled.setScrollEnabled(true)
        removeChildScope(outgoing)
    }
}
