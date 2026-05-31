//
//  FlingClampBehavior.swift
//  cue
//

import SwiftUI

/// A `ScrollTargetBehavior` that caps how far a single fling can travel in the
/// vertical infinite-scroll scopes (month, year).
///
/// Without a cap, a fast flick on an infinitely-growing list can coast through
/// a century or more in one gesture — the window keeps extending while the
/// content is still decelerating. This behavior clamps the resting target so a
/// single fling moves at most `maxTravel` points from where the gesture
/// started, then the list settles. Releasing and flicking again continues from
/// the new position, so navigation still feels natural — it just can't blow
/// past ~10 units (months/years) in one throw.
///
/// `flingStartOffsetY` is the vertical content offset captured at the moment
/// the drag began (the hosting view records it via `onScrollPhaseChange`); the
/// clamp is measured relative to that origin, not the proposed landing point.
struct FlingClampBehavior: ScrollTargetBehavior {
    /// Vertical content offset when the current gesture started.
    let flingStartOffsetY: CGFloat
    /// Maximum distance, in points, a single fling may settle from the start.
    let maxTravel: CGFloat

    /// Below this vertical speed (points/sec) the resolution is treated as a
    /// settle or a programmatic jump (e.g. the "Today" button) rather than a
    /// fling, and is left unclamped — otherwise tapping "Today" couldn't scroll
    /// past the cap.
    private static let flingVelocityThreshold: CGFloat = 50

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        // Only constrain real vertical flings; ignore programmatic jumps and
        // gentle settles (near-zero velocity).
        guard context.axes.contains(.vertical), maxTravel > 0 else { return }
        guard abs(context.velocity.dy) > Self.flingVelocityThreshold else { return }

        let proposedY = target.rect.origin.y
        let lowerBound = flingStartOffsetY - maxTravel
        let upperBound = flingStartOffsetY + maxTravel
        let clampedY = min(max(proposedY, lowerBound), upperBound)

        guard clampedY != proposedY else { return }
        target.rect.origin.y = clampedY
    }
}
