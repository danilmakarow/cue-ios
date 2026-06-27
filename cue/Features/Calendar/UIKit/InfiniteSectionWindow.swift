//
//  InfiniteSectionWindow.swift
//  cue
//

import Foundation

/// A pure, scope-agnostic sliding window of ordered `Date` anchors (month-starts
/// or year-starts) for an infinitely-scrolling calendar scope.
///
/// It owns *only* the ordered set of section anchors and the growth/trim policy
/// — no UIKit, no collection view, no I/O — so it is trivially testable. The
/// caller supplies a `step` function that maps "N units before/after an anchor"
/// to concrete dates (e.g. `CalendarMath.months(before:count:)` /
/// `CalendarMath.years(after:count:)`), which is what makes it work for both the
/// month and year scopes without the window knowing which it is.
///
/// Usage shape, per scroll-settle (never mid-fling):
/// ```swift
/// if window.isNearLeadingEdge(of: centeredIndex) {
///     let added = window.prepend()          // grow older side
///     window.trimTrailing()                 // bound memory from the far edge
///     // correct contentOffset by `added`'s height; reload the snapshot
/// }
/// ```
/// Defaults mirror the proven SwiftUI month scope: `seedRadius` 18, `growBy` 12,
/// `maxWindowSize` 60, `edgeThreshold` 6.
struct InfiniteSectionWindow {

    // MARK: - Step function

    /// Produces `count` anchors immediately before / after `anchor`, ascending
    /// (oldest first), for one direction of growth. The caller binds this to the
    /// appropriate `CalendarMath` stepping pair so the window stays scope-agnostic.
    struct Step {
        /// `count` anchors immediately before `anchor`, ascending (oldest first).
        let before: (_ anchor: Date, _ count: Int) -> [Date]
        /// `count` anchors immediately after `anchor`, ascending.
        let after: (_ anchor: Date, _ count: Int) -> [Date]

        /// Builds a step pair from two stepping closures.
        init(
            before: @escaping (_ anchor: Date, _ count: Int) -> [Date],
            after: @escaping (_ anchor: Date, _ count: Int) -> [Date]
        ) {
            self.before = before
            self.after = after
        }

        /// Month stepping bound to `CalendarMath.months(before:/after:)`.
        static let month = Step(
            before: { CalendarMath.months(before: $0, count: $1) },
            after: { CalendarMath.months(after: $0, count: $1) }
        )

        /// Year stepping bound to `CalendarMath.years(before:/after:)`.
        static let year = Step(
            before: { CalendarMath.years(before: $0, count: $1) },
            after: { CalendarMath.years(after: $0, count: $1) }
        )
    }

    // MARK: - Tuning

    /// How many units to add per growth step.
    let growBy: Int
    /// Hard cap on the window; the far edge is trimmed past this so a long
    /// session can't accumulate unbounded sections.
    let maxWindowSize: Int
    /// How close (in index) to either end before the window should grow.
    let edgeThreshold: Int

    private let step: Step

    /// The current ordered anchors (ascending). The scope's section list.
    private(set) var anchors: [Date]

    // MARK: - Init

    /// Creates an empty window. Call ``seed(around:radius:)`` before use, or pass
    /// `seedAround` to seed immediately.
    ///
    /// - Parameters:
    ///   - step: the stepping pair (`.month` or `.year`, or a custom one).
    ///   - growBy: anchors added per growth (default 12).
    ///   - maxWindowSize: hard cap before far-edge trimming (default 60).
    ///   - edgeThreshold: index proximity that triggers growth (default 6).
    init(
        step: Step,
        growBy: Int = 12,
        maxWindowSize: Int = 60,
        edgeThreshold: Int = 6
    ) {
        self.step = step
        self.growBy = growBy
        self.maxWindowSize = maxWindowSize
        self.edgeThreshold = edgeThreshold
        self.anchors = []
    }

    // MARK: - Seeding

    /// Seeds the window with `radius` anchors on each side of `center`
    /// (inclusive), ascending — `2 * radius + 1` sections. Replaces any existing
    /// anchors. Default `radius` 18 mirrors the SwiftUI month scope's seed.
    mutating func seed(around center: Date, radius: Int = 18) {
        let leading = step.before(center, max(radius, 0))
        let trailing = step.after(center, max(radius, 0))
        anchors = leading + [center] + trailing
    }

    // MARK: - Growth

    /// Prepends `growBy` older anchors to the leading (oldest) edge and returns
    /// them (ascending). No-op returning `[]` when the window is empty.
    @discardableResult
    mutating func prepend() -> [Date] {
        prepend(by: growBy)
    }

    /// Prepends `count` older anchors and returns them (ascending, oldest first),
    /// so the caller can measure their height to correct `contentOffset`.
    @discardableResult
    mutating func prepend(by count: Int) -> [Date] {
        guard let first = anchors.first, count > 0 else { return [] }
        let added = step.before(first, count)
        anchors.insert(contentsOf: added, at: 0)
        return added
    }

    /// Appends `growBy` newer anchors to the trailing (newest) edge and returns
    /// them (ascending). No-op returning `[]` when the window is empty.
    @discardableResult
    mutating func append() -> [Date] {
        append(by: growBy)
    }

    /// Appends `count` newer anchors and returns them (ascending).
    @discardableResult
    mutating func append(by count: Int) -> [Date] {
        guard let last = anchors.last, count > 0 else { return [] }
        let added = step.after(last, count)
        anchors.append(contentsOf: added)
        return added
    }

    // MARK: - Trimming

    /// Drops anchors beyond `maxWindowSize` from the leading (oldest) edge and
    /// returns the removed anchors. Call after ``append()`` so growth at one end
    /// is balanced by trimming the far end, bounding memory.
    @discardableResult
    mutating func trimLeading() -> [Date] {
        let excess = anchors.count - maxWindowSize
        guard excess > 0 else { return [] }
        let removed = Array(anchors.prefix(excess))
        anchors.removeFirst(excess)
        return removed
    }

    /// Drops anchors beyond `maxWindowSize` from the trailing (newest) edge and
    /// returns the removed anchors. Call after ``prepend()``.
    @discardableResult
    mutating func trimTrailing() -> [Date] {
        let excess = anchors.count - maxWindowSize
        guard excess > 0 else { return [] }
        let removed = Array(anchors.suffix(excess))
        anchors.removeLast(excess)
        return removed
    }

    // MARK: - Edge detection

    /// True when `index` is within `edgeThreshold` of the leading (oldest) edge,
    /// so the window should grow older.
    func isNearLeadingEdge(of index: Int) -> Bool {
        index < edgeThreshold
    }

    /// True when `index` is within `edgeThreshold` of the trailing (newest) edge,
    /// so the window should grow newer.
    func isNearTrailingEdge(of index: Int) -> Bool {
        index > anchors.count - 1 - edgeThreshold
    }

    /// The index of `anchor` in the current window, or nil when it isn't present.
    func index(of anchor: Date) -> Int? {
        anchors.firstIndex(of: anchor)
    }

    /// True when `anchor` is currently in the window.
    func contains(_ anchor: Date) -> Bool {
        anchors.contains(anchor)
    }
}
