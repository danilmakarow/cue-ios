//
//  CalendarZoomContainer.swift
//  cue
//

import SwiftUI

/// One zoomable surface hosting the calendar's three scopes (year, month,
/// day) and the continuous zoom between them — the replacement for the old
/// scope-per-`NavigationStack`-level architecture.
///
/// **Model.** `activeScope` is the resting level; a `ScopeZoomTransition`
/// (when non-nil) is an in-flight zoom between two *adjacent* levels, driven
/// by a single scalar `innerVisibility` (1 = inner scope fullscreen, 0 =
/// outer). Both scopes of the pair are mounted during a transition and
/// cross-faded/scaled around the **anchor cell** — the day's cell in the
/// month grid, or the month's cell in the year grid — whose frame comes from
/// the `ScopeFrameRegistry`. A pinch drives the scalar interactively (and is
/// cancellable mid-gesture); a cell tap animates it; commit flips
/// `activeScope` and unmounts the outgoing scope.
///
/// **Why not `.navigationTransition(.zoom)`.** The navigation zoom is a
/// two-endpoint push/pop: it cannot pause, retarget, or run as a true pinch,
/// and it required a realized `matchedTransitionSource` in the parent before
/// a programmatic push (the old `ZoomSourceRegistry` polling handshake and
/// the cold-launch deep-link choreography existed only to satisfy it). Here
/// the day scope renders directly on launch and the outer scopes mount
/// lazily on first zoom-out.
///
/// `NavigationStack` remains for leaf pushes only (task detail), supplied by
/// `CalendarRootView`.
struct CalendarZoomContainer: View {
    let user: UserDTO
    /// Called when the user taps an event card in the day scope; the root
    /// pushes the task-detail screen.
    var onSelectEvent: (ScheduleEvent) -> Void = { _ in }

    @Environment(CalendarStore.self) private var store

    /// The resting zoom level. Launch lands on the day scope — outer scopes
    /// don't realize a single view until the first zoom-out.
    @State private var activeScope: CalendarScope = .day
    @State private var transition: ScopeZoomTransition?
    /// Month the month scope (re)mounts centered on; also seeds the year the
    /// year scope mounts centered on. Tracks the month scope's own scrolling
    /// via `onCenteredMonthChange` so zoom-out anchors stay truthful.
    @State private var monthAnchor = CalendarMath.startOfMonth(.now)
    @State private var frames = ScopeFrameRegistry()

    /// Pinch magnification at which a zoom-out reaches `innerVisibility` 0.
    private static let zoomOutFloor: CGFloat = 0.35
    /// Pinch magnification span over which a zoom-in reaches visibility 1.
    private static let zoomInSpan: CGFloat = 1.2
    /// How far from 1.0 the magnification must move before a pinch commits to
    /// a direction (filters touch noise at gesture start).
    private static let directionThreshold: CGFloat = 0.04
    /// Magnification velocity (per second) that commits a fling-pinch
    /// regardless of progress.
    private static let commitVelocity: CGFloat = 1.0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                // Outer-to-inner stacking: the inner scope of any transition
                // pair must render on top.
                if isMounted(.year) {
                    let transform = transform(for: .year, in: size)
                    YearScopeView(
                        centeredOn: monthAnchor,
                        onSelectMonth: zoomToMonth,
                        onOpenToday: openToday
                    )
                    .scaleEffect(transform.scale, anchor: transform.anchor)
                    .opacity(transform.opacity)
                }
                if isMounted(.month) {
                    let transform = transform(for: .month, in: size)
                    MonthScopeView(
                        monthAnchor: monthAnchor,
                        onSelectDay: zoomToDay,
                        onOpenToday: openToday,
                        onCenteredMonthChange: { monthAnchor = $0 }
                    )
                    .scaleEffect(transform.scale, anchor: transform.anchor)
                    .opacity(transform.opacity)
                }
                if isMounted(.day) {
                    let transform = transform(for: .day, in: size)
                    CalendarView(user: user, onOpenToday: openToday, onSelect: onSelectEvent)
                        .scaleEffect(transform.scale, anchor: transform.anchor)
                        .opacity(transform.opacity)
                }
            }
            .coordinateSpace(.named(ScopeFrameRegistry.coordinateSpaceName))
            // Freeze the lists while a zoom is in flight so the pinch and a
            // pan can't fight over the content.
            .scrollDisabled(transition != nil)
            .simultaneousGesture(pinchGesture)
        }
        .environment(frames)
    }

    // MARK: - Mounting & transforms

    /// A scope is in the tree while it's the resting scope or a party to the
    /// in-flight transition. Mount checks are identity-stable across a whole
    /// zoom: the resting scope stays mounted from gesture start to commit.
    private func isMounted(_ scope: CalendarScope) -> Bool {
        if scope == activeScope { return true }
        guard let transition else { return false }
        return transition.inner == scope || transition.outer == scope
    }

    private struct ScopeTransform {
        var scale: CGFloat = 1
        var opacity: CGFloat = 1
        var anchor: UnitPoint = .center
    }

    /// The cross-zoom transform for one scope at the current
    /// `innerVisibility`. The inner scope collapses toward (and grows from)
    /// the anchor cell; the outer scope counter-zooms into the same cell and
    /// fades, so the two read as one continuous magnification.
    private func transform(for scope: CalendarScope, in size: CGSize) -> ScopeTransform {
        guard let transition,
              transition.inner == scope || transition.outer == scope,
              size.width > 0, size.height > 0
        else { return ScopeTransform() }

        let visibility = transition.innerVisibility
        let cell = transition.anchorFrame ?? Self.fallbackAnchorFrame(in: size)
        let anchor = UnitPoint(
            x: min(max(cell.midX / size.width, 0), 1),
            y: min(max(cell.midY / size.height, 0), 1)
        )

        if scope == transition.inner {
            // Fully zoomed out, the inner scope rests at its cell's footprint.
            let collapsedScale = max(cell.width / size.width, 0.06)
            return ScopeTransform(
                scale: collapsedScale + (1 - collapsedScale) * visibility,
                opacity: Self.smoothstep(visibility, from: 0.15, to: 0.45),
                anchor: anchor
            )
        }
        // Outer scope: magnify into the anchor cell as the inner takes over.
        // Capped so a tiny day cell doesn't force a huge rasterized layer.
        let magnified = min(size.width / max(cell.width, 1), 3.5)
        return ScopeTransform(
            scale: 1 + (magnified - 1) * visibility,
            opacity: 1 - Self.smoothstep(visibility, from: 0.3, to: 0.75),
            anchor: anchor
        )
    }

    /// Generic center anchor used until (or in case) the real cell frame is
    /// unknown — e.g. a zoom-out whose outer scope mounted this frame.
    private static func fallbackAnchorFrame(in size: CGSize) -> CGRect {
        let side = size.width / 3
        return CGRect(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2,
            width: side,
            height: side
        )
    }

    private static func smoothstep(_ value: CGFloat, from lower: CGFloat, to upper: CGFloat) -> CGFloat {
        guard upper > lower else { return value >= upper ? 1 : 0 }
        let t = min(max((value - lower) / (upper - lower), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    // MARK: - Pinch

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if transition == nil {
                    beginPinch(value)
                }
                updatePinch(value)
            }
            .onEnded { value in
                settlePinch(value)
            }
    }

    /// Locks the pinch to a direction once magnification clears the noise
    /// threshold, mounts the counterpart scope, and captures the anchor cell.
    private func beginPinch(_ value: MagnifyGesture.Value) {
        let magnification = value.magnification
        guard abs(magnification - 1) > Self.directionThreshold else { return }

        if magnification < 1 {
            guard let outer = activeScope.zoomedOut else { return }
            if outer == .month {
                // The month scope mounts fresh — center it on the day we're
                // zooming out of so the anchor cell can realize.
                monthAnchor = CalendarMath.startOfMonth(store.selectedDate)
            }
            let anchorFrame = anchorFrame(forOuter: outer)
            transition = ScopeZoomTransition(
                inner: activeScope,
                outer: outer,
                kind: .zoomOut,
                anchorFrame: anchorFrame,
                innerVisibility: 1
            )
            if anchorFrame == nil {
                resolveAnchorFrameWhenRealized()
            }
        } else {
            guard let inner = activeScope.zoomedIn else { return }
            let anchorFrame = retargetForZoomIn(toward: inner, at: value.startLocation)
            transition = ScopeZoomTransition(
                inner: inner,
                outer: activeScope,
                kind: .zoomIn,
                anchorFrame: anchorFrame,
                innerVisibility: 0
            )
        }
    }

    private func updatePinch(_ value: MagnifyGesture.Value) {
        guard var current = transition else { return }
        switch current.kind {
        case .zoomOut:
            current.innerVisibility = Self.clamp(
                (value.magnification - Self.zoomOutFloor) / (1 - Self.zoomOutFloor)
            )
        case .zoomIn:
            current.innerVisibility = Self.clamp((value.magnification - 1) / Self.zoomInSpan)
        }
        transition = current
    }

    /// Commits or cancels the pinch from its resting progress and fling
    /// velocity, then animates to the chosen endpoint.
    private func settlePinch(_ value: MagnifyGesture.Value) {
        guard let current = transition else { return }
        let visibility = current.innerVisibility
        let commit: Bool
        switch current.kind {
        case .zoomOut:
            commit = visibility < 0.55 || value.velocity < -Self.commitVelocity
        case .zoomIn:
            commit = visibility > 0.45 || value.velocity > Self.commitVelocity
        }
        finishTransition(current, commit: commit)
    }

    /// Anchor cell for a zoom-out: the active scope's own cell as it appears
    /// in the (just-mounted) outer scope. Often nil on the first frame — see
    /// `resolveAnchorFrameWhenRealized`.
    private func anchorFrame(forOuter outer: CalendarScope) -> CGRect? {
        switch outer {
        case .month:
            return frames.dayFrame(for: CalendarMath.startOfDay(store.selectedDate))
        case .year:
            return frames.monthFrame(for: monthAnchor)
        case .day:
            return nil
        }
    }

    /// Picks the cell under a pinch-open's start location, points the shared
    /// selection state at it, and returns its frame.
    private func retargetForZoomIn(toward inner: CalendarScope, at location: CGPoint) -> CGRect? {
        switch inner {
        case .day:
            let day = frames.day(at: location) ?? CalendarMath.startOfDay(store.selectedDate)
            store.selectedDate = day
            return frames.dayFrame(for: day)
        case .month:
            let month = frames.month(at: location) ?? monthAnchor
            monthAnchor = month
            return frames.monthFrame(for: month)
        case .year:
            return nil
        }
    }

    /// A zoom-out's outer scope mounts on the gesture's first frame, so its
    /// anchor cell usually hasn't reported a frame yet. Poll the registry for
    /// a few frames and adopt the real frame — but only while the gesture is
    /// still near its start state, so the anchor never visibly jumps mid-zoom.
    private func resolveAnchorFrameWhenRealized() {
        Task { @MainActor in
            for _ in 0..<8 {
                try? await Task.sleep(for: .milliseconds(16))
                guard var current = transition, current.anchorFrame == nil else { return }
                let nearStart = current.kind == .zoomOut
                    ? current.innerVisibility > 0.8
                    : current.innerVisibility < 0.2
                guard nearStart else { return }
                if let frame = anchorFrame(forOuter: current.outer) {
                    current.anchorFrame = frame
                    transition = current
                    return
                }
            }
        }
    }

    // MARK: - Tap & programmatic zooms

    private func zoomToMonth(_ anchor: Date) {
        monthAnchor = anchor
        zoomIn(to: .month, anchorFrame: frames.monthFrame(for: anchor))
    }

    private func zoomToDay(_ day: Date) {
        store.selectedDate = day
        zoomIn(to: .day, anchorFrame: frames.dayFrame(for: day))
    }

    /// Animated zoom into the adjacent inner scope (cell tap or programmatic).
    /// Mounts the inner scope at visibility 0, then animates the commit on the
    /// next tick so mount and zoom stay separate transactions.
    private func zoomIn(to scope: CalendarScope, anchorFrame: CGRect?, completion: (() -> Void)? = nil) {
        guard transition == nil, scope == activeScope.zoomedIn else { return }
        let new = ScopeZoomTransition(
            inner: scope,
            outer: activeScope,
            kind: .zoomIn,
            anchorFrame: anchorFrame,
            innerVisibility: 0
        )
        transition = new
        Task { @MainActor in
            await Task.yield()
            guard transition != nil else { return }
            finishTransition(new, commit: true, completion: completion)
        }
    }

    /// Animates the in-flight transition to its endpoint, then settles
    /// `activeScope` and unmounts the outgoing scope.
    private func finishTransition(
        _ current: ScopeZoomTransition,
        commit: Bool,
        completion: (() -> Void)? = nil
    ) {
        // Ends on the inner scope when a zoom-in commits or a zoom-out cancels.
        let endsInner = (current.kind == .zoomIn) == commit
        withAnimation(.smooth(duration: 0.32)) {
            transition?.innerVisibility = endsInner ? 1 : 0
        } completion: {
            activeScope = endsInner ? current.inner : current.outer
            transition = nil
            completion?()
        }
    }

    /// Brings the calendar back to *today's day page* from any scope — the
    /// action behind every `OpenTodayButton`. Zooms in level by level so the
    /// return reads as the same continuous motion as manual navigation.
    private func openToday() {
        let today = CalendarMath.startOfDay(.now)
        let thisMonth = CalendarMath.startOfMonth(today)

        switch activeScope {
        case .day:
            // Already at day depth — recenter the pager (its window is built
            // around today, so today is always reachable).
            withAnimation(.snappy) { store.selectedDate = today }
        case .month:
            store.selectedDate = today
            zoomIn(to: .day, anchorFrame: frames.dayFrame(for: today))
        case .year:
            store.selectedDate = today
            monthAnchor = thisMonth
            zoomIn(to: .month, anchorFrame: frames.monthFrame(for: thisMonth)) {
                zoomIn(to: .day, anchorFrame: frames.dayFrame(for: today))
            }
        }
    }
}
