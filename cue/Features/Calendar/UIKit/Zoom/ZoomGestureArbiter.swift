//
//  ZoomGestureArbiter.swift
//  cue
//

import UIKit

/// Governs how the calendar's zoom **pinch** coexists with each scope's own
/// internal scrolling (the month/year vertical scroll, and the day scope's
/// horizontal pager *plus* its per-page vertical timeline/list scroll).
///
/// This is the UIKit answer to the SwiftUI version's gesture fighting (see
/// [ADR 0004](../../../../docs/adr/0004-uikit-calendar.md)): SwiftUI gave no
/// `require(toFail:)` / `shouldRecognizeSimultaneouslyWith` arbitration, so the
/// pinch swallowed scrolls and vice-versa. Here the policy is explicit:
///
/// - **Before a direction locks** the pinch is allowed to recognize *alongside*
///   the active scope's pan recognizers (`shouldRecognizeSimultaneouslyWith`
///   returns `true`). A two-finger gesture that's still ambiguous must not be
///   blocked by an in-progress single-finger scroll, and a scroll already under
///   way must not be killed the instant a second finger lands — the noise
///   threshold in ``CalendarZoomController`` decides which one wins.
/// - **The moment a direction locks** (the controller reports
///   ``directionDidLock``) the controller calls `setScrollEnabled(false)` on the
///   active scope, so the scope's scroll views stop tracking for the rest of the
///   transition. The pinch then owns the touches uncontested. On settle the
///   scope's scrolling is restored.
///
/// The arbiter itself is intentionally tiny — the *freezing* is done by the
/// controller via `CalendarScopeViewController.setScrollEnabled`; the arbiter
/// only governs the brief pre-lock window where both could legitimately run.
///
/// React analogy: this is the equivalent of deciding, in a pointer-events layer,
/// whether a pinch handler and a scroll handler may both observe the same touch
/// stream until one of them "claims" the gesture.
@MainActor
final class ZoomGestureArbiter: NSObject, UIGestureRecognizerDelegate {

    // MARK: - State

    /// Whether the pinch has locked to a zoom direction. While `false` the pinch
    /// may recognize simultaneously with scrolls; the controller flips this via
    /// ``setDirectionLocked(_:)`` so the arbiter never inspects controller
    /// internals directly.
    private var isDirectionLocked = false

    // MARK: - Configuration

    /// The pinch recognizer this arbiter coordinates. Held weakly: the
    /// recognizer is owned by the container's view, not the arbiter.
    private weak var pinch: UIPinchGestureRecognizer?

    /// Wires the arbiter to the zoom pinch. Call once, after the pinch is built.
    func attach(to pinch: UIPinchGestureRecognizer) {
        self.pinch = pinch
        pinch.delegate = self
    }

    /// Updates the locked flag. The controller calls this on lock (true) and on
    /// settle (false) so the simultaneous-recognition policy tracks the gesture's
    /// lifecycle. Returns immediately when unchanged.
    func setDirectionLocked(_ locked: Bool) {
        isDirectionLocked = locked
    }

    // MARK: - UIGestureRecognizerDelegate

    /// Allows the pinch to recognize *with* the active scope's scroll pans until a
    /// direction locks. The pinch is the recognizer we care about coordinating;
    /// any other pairing (e.g. two scroll pans) is left to the system.
    nonisolated func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        MainActor.assumeIsolated {
            // Only govern pairings involving our pinch.
            guard gestureRecognizer === pinch || other === pinch else { return false }
            // A pan/scroll recognizer is a `UIPanGestureRecognizer` (the
            // collection views' built-in pan). Permit simultaneity only while the
            // direction is still ambiguous; once locked the scope's scroll is
            // disabled anyway, so this returning false is a belt-and-braces guard.
            return !isDirectionLocked
        }
    }

    /// Never require the pinch to wait on a scroll pan to fail, and never require
    /// a scroll pan to wait on the pinch — a forced failure dependency would make
    /// one feel laggy. Simultaneity (above) plus the post-lock scroll freeze is
    /// the cleaner coordination, so we opt out of both `require(toFail:)` edges.
    nonisolated func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool {
        false
    }

    nonisolated func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf other: UIGestureRecognizer
    ) -> Bool {
        false
    }

    /// The pinch should always be allowed to begin — two fingers landing is an
    /// unambiguous intent to *consider* a zoom; the controller's noise threshold,
    /// not this gate, decides whether it actually commits to a direction.
    nonisolated func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
