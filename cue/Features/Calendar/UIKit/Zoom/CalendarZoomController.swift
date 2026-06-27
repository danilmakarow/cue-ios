//
//  CalendarZoomController.swift
//  cue
//

import UIKit

/// Drives the interactive, cell-anchored cross-zoom between two **adjacent**
/// calendar scopes (year↔month, month↔day) — the UIKit reimplementation of the
/// old SwiftUI `CalendarZoomContainer` zoom, with real gesture arbitration and
/// `CGAffineTransform`-based scaling instead of per-frame SwiftUI body
/// invalidation.
///
/// **Model.** A single in-flight ``ZoomTransition`` (when non-nil) holds the two
/// scopes of the pair and a scalar `innerVisibility` in `0...1` (1 = inner scope
/// fullscreen, 0 = outer). Every update applies the *cross transform*: the inner
/// scope is scaled up from its collapsed cell-footprint to full size, anchored on
/// the **anchor cell** and fading in; the outer scope is counter-magnified into
/// the same cell and fading out, so the pair reads as one continuous
/// magnification. The math mirrors the old `transform(for:in:)`:
/// `collapsedScale = max(cell.width / size.width, 0.06)`,
/// `outerMagnified = min(size.width / cell.width, 3.5)`, with smoothstep opacity
/// ramps.
///
/// **Driving it.** A `UIPinchGestureRecognizer` (added to the container's view)
/// drives `innerVisibility` interactively; cell taps and the Today action animate
/// it through ``commit(_:)``. On begin the pinch locks a direction once
/// magnification clears a noise threshold (`≈0.04`): `magnification < 1` ⇒
/// zoom-out to `activeScope.zoomedOut`; `> 1` ⇒ zoom-in to `activeScope.zoomedIn`.
/// On end it commits or cancels from progress + velocity, then animates to the
/// chosen endpoint and, on completion, swaps the active scope and resets
/// transforms/alpha. The whole thing is cancellable and retargetable: a new
/// gesture or tap mid-animation interrupts the running animator and starts fresh.
///
/// **Ownership.** The controller does *not* own the scope view controllers or
/// their mounting — the container does. It talks to the container through
/// ``CalendarZoomHost`` (provide the active/adjacent scope, mount an outer scope,
/// the shared coordinate space, freeze/unfreeze) so this file stays focused on
/// the geometry and the gesture lifecycle.
@MainActor
final class CalendarZoomController {

    // MARK: - Tuning (mirrors the old SwiftUI constants)

    /// Pinch magnification at which a zoom-out reaches `innerVisibility` 0.
    private static let zoomOutFloor: CGFloat = 0.35
    /// Pinch magnification span over which a zoom-in reaches visibility 1.
    private static let zoomInSpan: CGFloat = 1.2
    /// How far from 1.0 the magnification must move before a pinch commits to a
    /// direction (filters touch noise at gesture start).
    private static let directionThreshold: CGFloat = 0.04
    /// Magnification velocity (per second) that commits a fling-pinch regardless
    /// of progress.
    private static let commitVelocity: CGFloat = 1.0
    /// Lower bound on the inner scope's collapsed scale, so a tiny day cell still
    /// rasterizes a sane layer.
    private static let minCollapsedScale: CGFloat = 0.06
    /// Upper bound on the outer scope's counter-magnification, so a tiny day cell
    /// doesn't force a huge rasterized layer.
    private static let maxOuterMagnification: CGFloat = 3.5
    /// Settle-animation duration, matching the old `.smooth(duration: 0.32)`.
    private static let settleDuration: TimeInterval = 0.32

    // MARK: - Collaborators

    /// The container, which mounts scopes and exposes the shared coordinate space.
    private weak var host: CalendarZoomHost?
    /// Coordinates the pinch with the active scope's scroll recognizers.
    private let arbiter = ZoomGestureArbiter()

    // MARK: - Gesture / animation state

    /// The pinch recognizer added to the container's view.
    private(set) lazy var pinch: UIPinchGestureRecognizer = {
        let recognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        arbiter.attach(to: recognizer)
        return recognizer
    }()

    /// The in-flight transition, or nil at rest.
    private var transition: ZoomTransition?
    /// The running settle animator, retained so a new gesture/tap can interrupt it.
    private var settleAnimator: UIViewPropertyAnimator?
    /// A bounded poll that adopts a zoom-out anchor frame once the freshly-mounted
    /// outer scope realizes the cell. Cancelled when superseded.
    private var anchorResolveTask: Task<Void, Never>?

    /// True while a transition (interactive or animating) is in flight.
    var isTransitioning: Bool { transition != nil }

    // MARK: - Init

    /// - Parameter host: the container that mounts scopes and owns the coordinate
    ///   space. Held weakly to avoid a retain cycle (the container owns *this*).
    init(host: CalendarZoomHost) {
        self.host = host
    }

    // MARK: - Pinch

    /// The pinch lifecycle: begin locks a direction + captures the anchor, change
    /// maps magnification → `innerVisibility` and applies the cross transform, end
    /// commits or cancels.
    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            // A begin can arrive without any prior change; defer the actual
            // direction lock to the first meaningful magnification in `.changed`.
            break
        case .changed:
            if transition == nil {
                beginPinch(recognizer)
            }
            updatePinch(recognizer)
        case .ended, .cancelled, .failed:
            settlePinch(recognizer)
        default:
            break
        }
    }

    /// Locks the pinch to a direction once magnification clears the noise
    /// threshold, asks the host to mount the counterpart scope, captures the
    /// anchor cell, and freezes the active scope's scrolling.
    private func beginPinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let host else { return }
        let magnification = recognizer.scale
        guard abs(magnification - 1) > Self.directionThreshold else { return }

        let active = host.activeScope
        if magnification < 1 {
            beginZoomOut(from: active, host: host)
        } else {
            // The pinch is attached to the container's view, so the recognizer's
            // own view *is* the zoom coordinate space the anchor frames use.
            let centroid = recognizer.location(in: recognizer.view)
            beginZoomIn(from: active, host: host, at: centroid)
        }
    }

    /// Starts a zoom-out: the active scope is the inner; its outer neighbor is
    /// mounted and the anchor is the active scope's own unit as it appears in the
    /// just-mounted outer (polled briefly if not yet realized).
    private func beginZoomOut(from active: CalendarScopeViewController, host: CalendarZoomHost) {
        guard let outerKind = active.kind.zoomedOut,
              let outer = host.mountScope(outerKind) else { return }

        // Center the outer scope on the unit we're zooming out of, so its anchor
        // cell can realize, then read that cell's frame.
        let unit = host.currentUnit(for: outerKind)
        outer.center(on: unit, animated: false)
        let anchor = outer.anchorFrame(forUnit: unit, in: host.zoomCoordinateSpace)

        let new = ZoomTransition(
            inner: active,
            outer: outer,
            direction: .zoomOut,
            anchorFrame: anchor,
            innerVisibility: 1
        )
        startTransition(new)
        if anchor == nil {
            resolveAnchorFrameWhenRealized(for: outerKind, unit: unit)
        }
    }

    /// Starts a zoom-in: the active scope is the outer; its inner neighbor is
    /// mounted; the anchor is the cell under the pinch centroid (selection and the
    /// inner scope are pointed at that unit so the zoom lands on it).
    private func beginZoomIn(
        from active: CalendarScopeViewController,
        host: CalendarZoomHost,
        at centroid: CGPoint
    ) {
        guard let innerKind = active.kind.zoomedIn,
              let inner = host.mountScope(innerKind) else { return }

        let unit = active.unit(at: centroid, in: host.zoomCoordinateSpace)
        let anchor = anchorForZoomIn(outer: active, inner: inner, unit: unit, host: host)

        let new = ZoomTransition(
            inner: inner,
            outer: active,
            direction: .zoomIn,
            anchorFrame: anchor,
            innerVisibility: 0
        )
        startTransition(new)
    }

    /// Resolves the anchor cell for a zoom-in: the tapped/pinched unit's cell in
    /// the *outer* scope (where the gesture started), having first pointed the
    /// inner scope at that unit so the commit lands there.
    private func anchorForZoomIn(
        outer: CalendarScopeViewController,
        inner: CalendarScopeViewController,
        unit: Date?,
        host: CalendarZoomHost
    ) -> CGRect? {
        guard let unit else { return nil }
        host.willZoomIn(to: inner.kind, unit: unit)
        inner.center(on: unit, animated: false)
        return outer.anchorFrame(forUnit: unit, in: host.zoomCoordinateSpace)
    }

    /// Maps the live magnification to `innerVisibility` for the current direction
    /// and re-applies the cross transform.
    private func updatePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let current = transition else { return }
        let magnification = recognizer.scale
        switch current.direction {
        case .zoomOut:
            current.innerVisibility = Self.clamp(
                (magnification - Self.zoomOutFloor) / (1 - Self.zoomOutFloor)
            )
        case .zoomIn:
            current.innerVisibility = Self.clamp((magnification - 1) / Self.zoomInSpan)
        }
        transition = current
        applyTransform(current)
    }

    /// Commits or cancels the pinch from its resting progress and fling velocity,
    /// then animates to the chosen endpoint.
    private func settlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let current = transition else { return }
        let visibility = current.innerVisibility
        let velocity = recognizer.velocity
        let commit: Bool
        switch current.direction {
        case .zoomOut:
            commit = visibility < 0.55 || velocity < -Self.commitVelocity
        case .zoomIn:
            commit = visibility > 0.45 || velocity > Self.commitVelocity
        }
        animateToEndpoint(current, commit: commit)
    }

    // MARK: - Tap & programmatic zoom

    /// Animated zoom into the adjacent inner scope, anchored on `anchorFrame` —
    /// the path behind a cell tap and the progressive Today. Mounts the inner
    /// scope at visibility 0, points it at `unit`, then animates the commit.
    /// Ignored when a transition is already running *unless* it's interruptible
    /// (a settle animator), in which case the running one is cancelled first.
    func zoomIn(to innerKind: CalendarScopeKind, unit: Date, anchorFrame: CGRect?) {
        guard let host else { return }
        interruptSettleIfRunning()
        guard transition == nil else { return }
        guard host.activeScope.kind.zoomedIn == innerKind,
              let inner = host.mountScope(innerKind) else { return }

        host.willZoomIn(to: innerKind, unit: unit)
        inner.center(on: unit, animated: false)

        let new = ZoomTransition(
            inner: inner,
            outer: host.activeScope,
            direction: .zoomIn,
            anchorFrame: anchorFrame,
            innerVisibility: 0
        )
        startTransition(new)
        // Mount and zoom are separate transactions: let the mounted scope lay out
        // for one tick before animating the commit, so its first frame isn't the
        // collapsed transform mid-layout.
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, let current = self.transition, current === new else { return }
            self.animateToEndpoint(current, commit: true)
        }
    }

    // MARK: - Transition lifecycle

    /// Mounts the transition: freezes the active scope's scrolling, locks the
    /// arbiter, stacks the inner scope on top, and paints the first frame.
    private func startTransition(_ new: ZoomTransition) {
        guard let host else { return }
        cancelAnchorResolve()
        transition = new
        arbiter.setDirectionLocked(true)
        // Freeze both scopes' scrolling for the duration so pinch/pan don't fight.
        new.inner.setScrollEnabled(false)
        new.outer.setScrollEnabled(false)
        host.beginTransition(inner: new.inner, outer: new.outer)
        applyTransform(new)
    }

    /// Animates the in-flight transition to its endpoint, then settles the active
    /// scope and tears the transition down. Interruptible: a fresh gesture or tap
    /// stops the animator and supersedes it.
    private func animateToEndpoint(_ current: ZoomTransition, commit: Bool) {
        // Ends on the inner scope when a zoom-in commits or a zoom-out cancels.
        let endsInner = (current.direction == .zoomIn) == commit
        let target: CGFloat = endsInner ? 1 : 0

        settleAnimator?.stopAnimation(true)
        // The animator interpolates the view `transform`/`alpha` set by
        // `applyTransform` at the target visibility from their current values, so
        // setting the endpoint once inside the block yields a smooth cross-zoom.
        let animator = UIViewPropertyAnimator(duration: Self.settleDuration, dampingRatio: 0.9) { [weak self] in
            guard let self else { return }
            current.innerVisibility = target
            self.transition = current
            self.applyTransform(current)
        }
        animator.addCompletion { [weak self] position in
            guard let self, position == .end else { return }
            self.finishTransition(current, endedInner: endsInner)
        }
        settleAnimator = animator
        animator.startAnimation()
    }

    /// Settles `activeScope`, resets transforms/alpha, restores scrolling, and
    /// unmounts the outgoing scope — the single teardown path for every commit.
    private func finishTransition(_ current: ZoomTransition, endedInner: Bool) {
        guard let host else { return }
        let settled = endedInner ? current.inner : current.outer
        let outgoing = endedInner ? current.outer : current.inner

        // Reset both scopes' visual state before the container re-parents them.
        for scope in [current.inner, current.outer] {
            scope.view.transform = .identity
            scope.view.alpha = 1
        }
        settled.setScrollEnabled(true)

        transition = nil
        settleAnimator = nil
        arbiter.setDirectionLocked(false)
        host.endTransition(settled: settled, outgoing: outgoing)
    }

    /// Stops a running settle animator so a new interaction can supersede it
    /// without a visual hitch. Leaves the transition in place for the new path to
    /// re-target, or torn down by the caller.
    private func interruptSettleIfRunning() {
        guard let animator = settleAnimator, animator.isRunning else { return }
        animator.stopAnimation(true)
        settleAnimator = nil
        // A settle was mid-flight; finalize it to whichever endpoint it had nearly
        // reached so we don't leave a half-applied transform, then the new path
        // starts from a clean rest.
        if let current = transition {
            let endsInner = current.innerVisibility >= 0.5
            finishTransition(current, endedInner: endsInner)
        }
    }

    // MARK: - Cross transform

    /// Applies the cross-scale + cross-fade for both scopes of `transition` at its
    /// current `innerVisibility`. The inner scope grows from the anchor cell; the
    /// outer scope counter-magnifies into the same cell and fades — together they
    /// read as one continuous magnification. Mirrors the old `transform(for:in:)`.
    private func applyTransform(_ transition: ZoomTransition) {
        guard let host else { return }
        let size = host.zoomCoordinateSpace.bounds.size
        guard size.width > 0, size.height > 0 else { return }

        let visibility = transition.innerVisibility
        let cell = transition.anchorFrame ?? Self.fallbackAnchorFrame(in: size)
        let center = CGPoint(x: cell.midX, y: cell.midY)

        // Inner scope: rests at its cell footprint (collapsed), grows to full.
        let collapsedScale = max(cell.width / size.width, Self.minCollapsedScale)
        let innerScale = collapsedScale + (1 - collapsedScale) * visibility
        transition.inner.view.transform = Self.scaleAbout(center: center, scale: innerScale, in: size)
        transition.inner.view.alpha = Self.smoothstep(visibility, from: 0.15, to: 0.45)

        // Outer scope: magnifies into the anchor cell as the inner takes over.
        let magnified = min(size.width / max(cell.width, 1), Self.maxOuterMagnification)
        let outerScale = 1 + (magnified - 1) * visibility
        transition.outer.view.transform = Self.scaleAbout(center: center, scale: outerScale, in: size)
        transition.outer.view.alpha = 1 - Self.smoothstep(visibility, from: 0.3, to: 0.75)
    }

    /// A `CGAffineTransform` that scales a full-bleed view about `center`
    /// (expressed in the container's coordinate space). UIKit views have no
    /// `layer.anchorPoint` convenience mid-gesture without frame jumps, so we
    /// express the anchored scale as translate→scale→translate about the cell
    /// center: move the pivot to the origin, scale, move it back. The scope's view
    /// fills the container, so its own center is `size/2`; the offset from there
    /// to the cell center is what we pivot around.
    private static func scaleAbout(center: CGPoint, scale: CGFloat, in size: CGSize) -> CGAffineTransform {
        let viewCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        let pivotX = center.x - viewCenter.x
        let pivotY = center.y - viewCenter.y
        return CGAffineTransform(translationX: pivotX, y: pivotY)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -pivotX, y: -pivotY)
    }

    /// Generic center anchor used until (or in case) a real cell frame is unknown
    /// — e.g. a zoom-out whose outer scope hasn't realized the cell yet.
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

    // MARK: - Anchor realization (zoom-out)

    /// A zoom-out's outer scope mounts on the gesture's first frame, so its anchor
    /// cell usually hasn't reported a frame yet. Poll the scope for a few frames
    /// and adopt the real frame — but only while the gesture is still near its
    /// start state, so the anchor never visibly jumps mid-zoom. Bounded (8 frames)
    /// like the old `resolveAnchorFrameWhenRealized`.
    private func resolveAnchorFrameWhenRealized(for outerKind: CalendarScopeKind, unit: Date) {
        cancelAnchorResolve()
        anchorResolveTask = Task { @MainActor [weak self] in
            for _ in 0..<8 {
                try? await Task.sleep(for: .milliseconds(16))
                guard let self,
                      let host = self.host,
                      let current = self.transition,
                      current.direction == .zoomOut,
                      current.anchorFrame == nil,
                      current.outer.kind == outerKind else { return }
                // Only adopt while still near the start (inner still dominant), so
                // the anchor can't jump after the cross-zoom has visibly begun.
                guard current.innerVisibility > 0.8 else { return }
                if let frame = current.outer.anchorFrame(forUnit: unit, in: host.zoomCoordinateSpace) {
                    current.anchorFrame = frame
                    self.transition = current
                    self.applyTransform(current)
                    return
                }
            }
        }
    }

    private func cancelAnchorResolve() {
        anchorResolveTask?.cancel()
        anchorResolveTask = nil
    }
}

// MARK: - Transition model

/// One in-flight zoom between two adjacent scopes, driven by a single
/// `innerVisibility` scalar (1 = inner fullscreen, 0 = outer). A reference type so
/// the controller can compare instances by identity (`===`) when an async
/// continuation needs to confirm it's still acting on the same transition.
@MainActor
private final class ZoomTransition {
    /// Whether the gesture is zooming toward the inner or the outer scope.
    enum Direction { case zoomIn, zoomOut }

    let inner: CalendarScopeViewController
    let outer: CalendarScopeViewController
    let direction: Direction
    /// The anchor cell's frame in the container's coordinate space; nil until a
    /// zoom-out's outer scope realizes it (then a centered fallback is used).
    var anchorFrame: CGRect?
    /// Progress in `0...1`.
    var innerVisibility: CGFloat

    init(
        inner: CalendarScopeViewController,
        outer: CalendarScopeViewController,
        direction: Direction,
        anchorFrame: CGRect?,
        innerVisibility: CGFloat
    ) {
        self.inner = inner
        self.outer = outer
        self.direction = direction
        self.anchorFrame = anchorFrame
        self.innerVisibility = innerVisibility
    }
}

// MARK: - Host contract

/// The container surface the ``CalendarZoomController`` drives. Keeps scope
/// *mounting* and *containment* in the container while the controller owns only
/// the geometry and the gesture lifecycle.
@MainActor
protocol CalendarZoomHost: AnyObject {
    /// The currently-resting scope (the zoom's outer for a zoom-in, inner for a
    /// zoom-out).
    var activeScope: CalendarScopeViewController { get }

    /// The coordinate space anchor frames are expressed in (the container's view).
    var zoomCoordinateSpace: UICoordinateSpace { get }

    /// Lazily builds + adds (if needed) and returns the scope for `kind`, ready to
    /// be a transition party. Returns nil only if construction is impossible.
    func mountScope(_ kind: CalendarScopeKind) -> CalendarScopeViewController?

    /// The unit the given outer scope should center on when zooming out of the
    /// active scope (e.g. the active day's month, the active month's year).
    func currentUnit(for outerKind: CalendarScopeKind) -> Date

    /// Notifies the host that a zoom-in toward `kind` will land on `unit`, so it
    /// can point shared selection at it before the animation.
    func willZoomIn(to kind: CalendarScopeKind, unit: Date)

    /// Stacks `inner` above `outer` for the transition's duration.
    func beginTransition(inner: CalendarScopeViewController, outer: CalendarScopeViewController)

    /// Settles on `settled` and unmounts `outgoing` once a transition completes.
    func endTransition(settled: CalendarScopeViewController, outgoing: CalendarScopeViewController)
}
