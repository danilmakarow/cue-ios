//
//  PrefetchCoordinator.swift
//  cue
//

import Foundation
import QuartzCore

/// Direction/velocity-aware prefetch planner shared by all three calendar scopes
/// (year, month, day). It does **not** fetch anything itself — it observes the
/// stream of scroll offsets each scope feeds it, derives the current scroll
/// **direction** (sign of the offset delta) and **velocity** (points/sec,
/// exponentially smoothed), and from those computes *which* anchors a scope
/// should sync *ahead* of visibility.
///
/// ## Why a separate coordinator
/// The scopes already sync every visible/prefetched unit through `willDisplay` +
/// `prefetchItemsAt` (the correctness floor — never removed). The coordinator is
/// a pure **optimization layer** stacked on top: it computes a buffer of `N`
/// units extended *only in the current scroll direction* so the synced window
/// strictly leads the visible window, eliminating the empty/loading flash a
/// freshly-realized cell would otherwise show before its `?? []` fallback is
/// replaced by real SwiftData rows.
///
/// ## How a scope uses it
/// On each `scrollViewDidScroll`, the scope calls ``track(offset:axis:)`` to feed
/// the offset sample (which updates direction + velocity and schedules a trailing
/// debounce). On settle (`scrollViewDidEndDecelerating`) the scope calls the
/// relevant `compute*` method with its own window/anchor data and dispatches the
/// returned anchors through its existing `ensure*Synced` path (each call is
/// idempotent on the store's caches, so over-asking is free). On
/// `scrollViewWillBeginDragging` the scope calls ``resetVelocity()`` to drop stale
/// history so a new gesture starts clean.
///
/// All members run on the main actor (the scopes, store, and adapter are all
/// `@MainActor` under Swift 6's MainActor-default isolation), so the mutable
/// state needs no extra synchronization.
@MainActor
final class PrefetchCoordinator {

    // MARK: - Scroll direction

    /// The derived scroll direction along a single axis. Calendar scopes scroll
    /// either vertically (month/year sections) or horizontally (day pager / week
    /// strip), so a scope reports its axis and reads back a same-axis direction.
    enum ScrollDirection: Hashable {
        case up, down, left, right, none

        /// True for the backward/older directions (up = earlier sections, left =
        /// earlier pages).
        func isBackward() -> Bool { self == .up || self == .left }

        /// True for the forward/newer directions (down = later sections, right =
        /// later pages).
        func isForward() -> Bool { self == .down || self == .right }
    }

    /// Which axis a scope scrolls along, so the coordinator maps an offset delta
    /// to the correct direction pair.
    enum ScrollAxis {
        case vertical
        case horizontal
    }

    // MARK: - Tuning

    /// Month buffer ahead in the scroll direction at normal velocity.
    private let monthBufferAhead = 2
    /// Month buffer behind (the abandoned direction) — asymmetric, smaller.
    private let monthBufferBehind = 1
    /// Widened ahead buffer on a fast fling.
    private let monthBufferFastVelocity = 4
    /// Velocity (pt/s) above which the ahead buffer widens.
    private let velocityThreshold: CGFloat = 2000

    /// Months prefetched ahead of the leading visible mini-month in the year scope.
    private let yearMonthsAhead = 2
    /// Hard cap on concurrent month syncs the year scope may dispatch per settle,
    /// to avoid a thundering herd on zoom-out.
    let yearConcurrentSyncCap = 6

    /// Days prefetched ahead in the day pager's scroll direction.
    private let dayEventsPrefetchDays = 5
    /// Max distinct month anchors a day-pager prefetch maps onto.
    private let dayMaxMonthAnchors = 2
    /// Weeks prefetched ahead/behind for the day-strip counts.
    private let dayCountsPrefetchWeeks = 2

    /// Trailing debounce on the offset stream (80–120ms window; 100ms chosen).
    private let debounceNanos: UInt64 = 100_000_000
    /// Exponential-moving-average smoothing factor for velocity.
    private let velocityAlpha: CGFloat = 0.3
    /// How many directions to remember when detecting a reversal.
    private let directionHistoryLimit = 5

    // MARK: - Scroll state

    private var lastContentOffset: CGPoint = .zero
    private var lastSampleTime: CFTimeInterval = 0
    private var hasSample = false

    private var currentDirection: ScrollDirection = .none
    private var currentVelocity: CGFloat = 0
    private var directionHistory: [ScrollDirection] = []

    private var debounceTask: Task<Void, Never>?
    private var pendingFlush: (() -> Void)?

    // MARK: - Init

    /// Creates a coordinator. Instantiated once by the container and injected into
    /// all three scopes so they share one direction/velocity estimate.
    init() {}

    // MARK: - Derived state (read by scopes)

    /// The current derived scroll direction.
    var direction: ScrollDirection { currentDirection }

    /// The current smoothed scroll speed in points/sec.
    var velocity: CGFloat { currentVelocity }

    /// True when the smoothed velocity exceeds the fast-fling threshold.
    var isFastFling: Bool { currentVelocity > velocityThreshold }

    // MARK: - Tracking

    /// Feeds a scroll-offset sample, updating direction + velocity and (re)arming
    /// the trailing debounce that will invoke `onSettle` if the scroll pauses. The
    /// scope passes a closure that recomputes + dispatches its prefetch buffer; the
    /// debounce coalesces a burst of `scrollViewDidScroll` calls into one dispatch.
    ///
    /// - Parameters:
    ///   - offset: the scroll view's current `contentOffset`.
    ///   - axis: the scope's scroll axis (vertical for month/year, horizontal for
    ///     the day pager / week strip).
    ///   - onSettle: invoked on the trailing edge of the debounce; recomputes and
    ///     dispatches the scope's ahead-buffer.
    func track(offset: CGPoint, axis: ScrollAxis, onSettle: @escaping () -> Void) {
        let now = CACurrentMediaTime()
        updateDirection(from: offset, axis: axis)
        if hasSample {
            updateVelocity(from: offset, elapsed: now - lastSampleTime)
        }
        lastContentOffset = offset
        lastSampleTime = now
        hasSample = true
        scheduleDebounce(onSettle)
    }

    /// Resets the velocity + direction history. Called on
    /// `scrollViewWillBeginDragging` so a new gesture isn't biased by the previous
    /// fling's samples, and the next direction sample re-seeds cleanly.
    func resetVelocity() {
        currentVelocity = 0
        hasSample = false
        directionHistory.removeAll()
        debounceTask?.cancel()
        debounceTask = nil
        pendingFlush = nil
    }

    /// Immediately runs `flush` and cancels any pending debounce. Called on
    /// `scrollViewDidEndDecelerating` so the now-visible window + buffer settle-sync
    /// happens without waiting out the debounce.
    func settleNow(_ flush: () -> Void) {
        debounceTask?.cancel()
        debounceTask = nil
        pendingFlush = nil
        flush()
    }

    // MARK: - Direction / velocity derivation

    /// Updates `currentDirection` from the signed offset delta along `axis`, and
    /// records the direction so a reversal can be detected. A near-zero delta keeps
    /// the prior direction (avoids flicker at the apex of a bounce).
    private func updateDirection(from offset: CGPoint, axis: ScrollAxis) {
        guard hasSample else { return }
        let derived: ScrollDirection
        switch axis {
        case .vertical:
            let delta = offset.y - lastContentOffset.y
            if abs(delta) < 0.5 { return }
            derived = delta > 0 ? .down : .up
        case .horizontal:
            let delta = offset.x - lastContentOffset.x
            if abs(delta) < 0.5 { return }
            derived = delta > 0 ? .right : .left
        }
        registerDirection(derived)
    }

    /// Records a freshly-derived direction, clearing history on a reversal so the
    /// buffer stops extending the abandoned direction and re-seeds the new one.
    private func registerDirection(_ direction: ScrollDirection) {
        if direction != currentDirection, !directionHistory.contains(direction) {
            // Reversal (or first sample): abandon the old direction's history.
            directionHistory.removeAll()
        }
        directionHistory.append(direction)
        if directionHistory.count > directionHistoryLimit {
            directionHistory.removeFirst()
        }
        currentDirection = direction
    }

    /// Folds a fresh raw velocity sample into the exponential moving average.
    private func updateVelocity(from offset: CGPoint, elapsed: CFTimeInterval) {
        guard elapsed > 0 else { return }
        let delta = CGPoint(x: offset.x - lastContentOffset.x, y: offset.y - lastContentOffset.y)
        let rawVelocity = hypot(delta.x, delta.y) / CGFloat(elapsed)
        currentVelocity = velocityAlpha * rawVelocity + (1 - velocityAlpha) * currentVelocity
    }

    // MARK: - Debounce

    /// (Re)schedules the trailing debounce. Cancels any in-flight timer so only the
    /// last sample in a burst fires `flush` after the quiet window elapses.
    private func scheduleDebounce(_ flush: @escaping () -> Void) {
        pendingFlush = flush
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.debounceNanos ?? 100_000_000)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            let pending = self.pendingFlush
            self.pendingFlush = nil
            self.debounceTask = nil
            pending?()
        }
    }

    // MARK: - Month buffer computation

    /// The month anchors the month scope should sync, given the leading visible
    /// month anchor and the surrounding window. Extends `monthBufferAhead`
    /// (`monthBufferFastVelocity` on a fast fling) in the current scroll direction
    /// and `monthBufferBehind` in the opposite one. On a reversal the abandoned
    /// direction is no longer extended (only `currentDirection` drives the ahead
    /// side), satisfying cancel-on-reversal without aborting in-flight syncs.
    ///
    /// - Parameters:
    ///   - leadingMonth: the month anchor at the leading edge of the viewport
    ///     (the one the scroll is moving toward).
    ///   - windowAnchors: the scope's current ordered month anchors, so the buffer
    ///     is clamped to held sections (out-of-window months are handled by the
    ///     scope's own window growth + `willDisplay`).
    /// - Returns: month-start anchors to sync, ordered ahead-first.
    func computePrefetchMonths(leadingMonth: Date, windowAnchors: [Date]) -> [Date] {
        computeVerticalBuffer(
            leadingAnchor: CalendarMath.startOfMonth(leadingMonth),
            windowAnchors: windowAnchors,
            aheadCount: isFastFling ? monthBufferFastVelocity : monthBufferAhead,
            behindCount: monthBufferBehind
        )
    }

    /// The month anchors the year scope should sync, given the leading visible
    /// mini-month and the year scope's `monthAnchors` (twelve per visible year).
    /// Extends `yearMonthsAhead` months in the scroll direction, then caps the
    /// total at ``yearConcurrentSyncCap`` so a zoom-out fling can't fan out an
    /// unbounded burst of GET /tasks calls.
    ///
    /// - Parameters:
    ///   - leadingMonth: the leading visible mini-month anchor.
    ///   - monthAnchors: every month anchor currently materialized across the
    ///     visible year sections (ascending), used to bound the buffer.
    /// - Returns: at most ``yearConcurrentSyncCap`` month-start anchors.
    func computePrefetchYearMonths(leadingMonth: Date, monthAnchors: [Date]) -> [Date] {
        let buffer = computeVerticalBuffer(
            leadingAnchor: CalendarMath.startOfMonth(leadingMonth),
            windowAnchors: monthAnchors,
            aheadCount: yearMonthsAhead,
            behindCount: 0
        )
        return Array(buffer.prefix(yearConcurrentSyncCap))
    }

    /// Shared engine for the month/year vertical buffers: walks `aheadCount`
    /// anchors in `currentDirection` and `behindCount` the other way, clamped to
    /// the supplied `windowAnchors`, ahead-first.
    private func computeVerticalBuffer(
        leadingAnchor: Date,
        windowAnchors: [Date],
        aheadCount: Int,
        behindCount: Int
    ) -> [Date] {
        guard let pivot = windowAnchors.firstIndex(of: leadingAnchor) else {
            // Leading anchor isn't in the window yet — the scope's window growth +
            // `willDisplay` will cover it; nothing to prefetch ahead of it here.
            return []
        }
        // `.down`/`.right` move toward higher indices (newer); `.up`/`.left` lower.
        let aheadStride = currentDirection.isBackward() ? -1 : 1
        var result: [Date] = []
        // Ahead-first, so the most-urgent (next-to-be-revealed) months dispatch
        // before the behind ones.
        for step in 1...max(aheadCount, 1) where step <= aheadCount {
            let index = pivot + step * aheadStride
            guard windowAnchors.indices.contains(index) else { break }
            result.append(windowAnchors[index])
        }
        for step in 1...max(behindCount, 1) where step <= behindCount {
            let index = pivot - step * aheadStride
            guard windowAnchors.indices.contains(index) else { break }
            result.append(windowAnchors[index])
        }
        return result
    }

    // MARK: - Day pager buffer computation

    /// The distinct month anchors covering a `dayEventsPrefetchDays`-day window
    /// ahead of `leadingDate` in the day pager's scroll direction, capped at
    /// ``dayMaxMonthAnchors``. The day scope dispatches `ensureDaySynced` for each
    /// (which delegates to `ensureMonthSynced`, idempotent on the store cache).
    ///
    /// - Parameter leadingDate: the leading visible page's date.
    /// - Returns: up to ``dayMaxMonthAnchors`` month-start anchors, ordered nearest-first.
    func computePrefetchDayMonths(leadingDate: Date) -> [Date] {
        let calendar = Calendar.current
        let stride = currentDirection.isBackward() ? -1 : 1
        let base = CalendarMath.startOfDay(leadingDate)
        var anchors: [Date] = []
        for step in 1...dayEventsPrefetchDays {
            guard let day = calendar.date(byAdding: .day, value: step * stride, to: base) else { continue }
            let month = CalendarMath.startOfMonth(day)
            if !anchors.contains(month) {
                anchors.append(month)
                if anchors.count >= dayMaxMonthAnchors { break }
            }
        }
        return anchors
    }

    // MARK: - Day-strip counts buffer computation

    /// The week ranges the day strip should prefetch counts for: the visible week
    /// plus `dayCountsPrefetchWeeks` weeks extended in the current scroll direction
    /// (and one week the other way so a small reversal stays warm). Each returned
    /// range is a locale-week `[weekStart, weekStart+6]` aligned to `weekRange`.
    ///
    /// - Parameter weekRange: the strip's currently-selected locale-week range.
    /// - Returns: ordered closed week ranges, leading-edge first.
    func computePrefetchCountsWindows(around weekRange: ClosedRange<Date>) -> [ClosedRange<Date>] {
        let calendar = Calendar.current
        let center = CalendarMath.startOfDay(weekRange.lowerBound)
        let aheadStride = currentDirection.isBackward() ? -1 : 1
        var offsets: [Int] = [0]
        for step in 1...dayCountsPrefetchWeeks {
            offsets.append(step * aheadStride)
        }
        // Keep one week warm in the opposite direction for a quick reversal.
        offsets.append(-aheadStride)

        var ranges: [ClosedRange<Date>] = []
        for offset in offsets {
            guard let start = calendar.date(byAdding: .day, value: offset * 7, to: center),
                  let end = calendar.date(byAdding: .day, value: 6, to: start) else { continue }
            let range = start...end
            if !ranges.contains(where: { $0 == range }) {
                ranges.append(range)
            }
        }
        return ranges
    }
}
