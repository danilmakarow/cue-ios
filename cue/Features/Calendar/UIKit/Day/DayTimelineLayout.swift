//
//  DayTimelineLayout.swift
//  cue
//

import UIKit

/// Pure timeline geometry for a single day, reproducing the SwiftUI
/// `DayScheduleView`'s math: a 0–24 hour grid at `hourHeight` (36) points per
/// hour with a `timelineTopPadding` (10) offset, hour rules + labels, and event
/// blocks positioned by start/end time — now with **time-skips**: any empty gap
/// of ≥ ``restThresholdMinutes`` (3h) between events (plus the leading/trailing
/// bookends to midnight) is COLLAPSED into a fixed ``restBandHeight`` (48pt)
/// "rest band", so the following hours move up ("hours skip"). The now-line and
/// hour gridlines stay correct across the compression because every y-mapping
/// runs through the same piecewise-linear ``y(for:)``.
///
/// This is *only* the math + frame computation — no view ownership — so the
/// owning ``DayTimelineDayView`` (and its tests) can position cells without
/// re-deriving the rules. Overlap columns are computed exactly as the old
/// SwiftUI view did.
struct DayTimelineLayout {

    // MARK: - Fixed structure

    /// First hour rendered (inclusive). Mirrors `DayScheduleView.startHour`.
    static let startHour: Int = 0
    /// Last hour rendered (inclusive). Mirrors `DayScheduleView.endHour`.
    static let endHour: Int = 24
    /// Width of the leading time-label column. Mirrors `DayScheduleView`.
    static let timeColumnWidth: CGFloat = 44
    /// Gutter between the time column and the events column.
    static let gutter: CGFloat = 8
    /// Minimum rendered height of an event block. Per the design spec a tile maps
    /// its duration to as little as ~14–18pt for the shortest slots (a 15–30 min
    /// event), so the block can be genuinely cramped — the timeline cell then
    /// fades its clipped title rather than hard-clipping it. Kept at 18 (not the
    /// spec's 14) to preserve a usable tap target while still letting the smallest
    /// tiles clip a full title line. The old flat 28 floor was tall enough to fit a
    /// full title line at every size, which is why the cell's fade mask was dead
    /// code — see ``DayTimelineEventCell``'s `contentClipped` geometry.
    static let minimumEventHeight: CGFloat = 18
    /// Horizontal inset shaved off each overlap column's width (matches the
    /// SwiftUI `columnWidth - 2`).
    static let columnInset: CGFloat = 2

    /// A gap of at least this many minutes with no events is collapsed into a
    /// single fixed-height rest band ("hours skip"). Per the design brief: any
    /// gap of MORE THAN 3 HOURS (≥ 180 min).
    static let restThresholdMinutes: Int = 180
    /// The fixed rendered height of a collapsed rest band, regardless of how many
    /// real minutes it spans.
    static let restBandHeight: CGFloat = 48

    /// The minimum compressed height any empty window is grown to once it receives
    /// a share of the fill-available slack — so even a hairline empty span becomes a
    /// tappable, visible breather rather than a zero-height sliver.
    static let minimumSlackWindowHeight: CGFloat = 24
    /// The minimum compressed height guaranteed to the empty window that contains
    /// "now" on today, so the now-line plus its `HH:mm` label always render with a
    /// little breathing room and are never compressed away. Sized for the label
    /// (~14pt) plus the line plus padding above and below.
    static let nowRegionMinimumHeight: CGFloat = 40

    private let hourHeight: CGFloat
    private let topPadding: CGFloat
    private let calendar = Calendar.current
    /// The day these segments describe (start-of-day), so `minutes(for:)` maps a
    /// `Date` to minutes-since-this-midnight even across DST-ish arithmetic.
    private let dayStart: Date
    /// The piecewise segments (active windows + collapsed rest bands) that define
    /// the compressed y-mapping, in ascending time order — AFTER the fill-available
    /// slack has been distributed across the empty windows.
    private let segments: [Segment]
    /// The total compressed content height of the segment stack (excludes
    /// `topPadding`), cached from the segment build.
    private let compressedHeight: CGFloat

    /// - Parameters:
    ///   - hourHeight: vertical points per hour (theme `hourHeight`, 36).
    ///   - topPadding: top inset before the first segment (theme
    ///     `timelineTopPadding`, 10).
    ///   - date: the day being laid out (used to anchor minute math).
    ///   - events: the day's TIMED occurrences (all-day are handled by the
    ///     owning view's separate band and must NOT be passed here) — their
    ///     active windows drive where gaps collapse.
    ///   - availableHeight: the viewport height the schedule should fill AT LEAST.
    ///     Any leftover beyond the natural content height is distributed across the
    ///     empty windows only (see ``TimelineSlackDistributor``). Pass `0` (default)
    ///     to skip filling and use the natural compressed height.
    ///   - now: the moment whose window is protected from compression on today, so
    ///     the now-line + label stay visible. Only consulted when `date` is today.
    init(
        hourHeight: CGFloat,
        topPadding: CGFloat,
        date: Date = Date(),
        events: [OccurrenceVM] = [],
        availableHeight: CGFloat = 0,
        now: Date = Date()
    ) {
        self.hourHeight = hourHeight
        self.topPadding = topPadding
        let start = Calendar.current.startOfDay(for: date)
        self.dayStart = start
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let built = Self.buildSegments(
            events: events,
            dayStart: start,
            calendar: calendar,
            hourHeight: hourHeight,
            isToday: isToday,
            now: now
        )
        // Fill-available: grow ONLY the empty windows so the schedule occupies at
        // least the viewport, protecting the now-region on today. The slack target
        // excludes `topPadding` (the distributor works in the segment stack's own
        // coordinate space), and the now-minute is only meaningful on today.
        let nowMinute = isToday ? Self.wallClockMinute(of: now, calendar: calendar) : nil
        let distributor = TimelineSlackDistributor(
            targetHeight: max(0, availableHeight - topPadding),
            nowMinute: nowMinute
        )
        let filled = distributor.distribute(segments: built.segments, baseHeight: built.height)
        self.segments = filled.segments
        self.compressedHeight = filled.height
    }

    // MARK: - Segment model

    /// One contiguous stretch of the compressed timeline.
    enum SegmentKind: Equatable {
        /// A normal, linearly-mapped active window (hours render at `hourHeight`).
        case active
        /// A collapsed empty gap, rendered as a fixed-height rest band with a
        /// `HH:MM – HH:MM` label of the real span it stands in for.
        case rest
    }

    /// A positioned slice of the day in the compressed coordinate space.
    struct Segment: Equatable {
        let kind: SegmentKind
        /// Real start, in minutes since midnight (0...1440).
        let startMinute: Int
        /// Real end, in minutes since midnight (0...1440).
        let endMinute: Int
        /// The segment's top y in the compressed content (excludes `topPadding`).
        let yTop: CGFloat
        /// The segment's rendered height in the compressed content.
        let height: CGFloat
        /// True when this stretch holds NO events — a collapsed `.rest` band or a
        /// sub-threshold empty span (leading/trailing bookend or inter-event gap)
        /// that still renders as ruled grid. Only these windows absorb fill-available
        /// slack; segments overlapping real events are never grown.
        let isEmpty: Bool

        /// Returns a copy re-flowed to a new `yTop`/`height`, preserving identity.
        func reflowed(yTop: CGFloat, height: CGFloat) -> Segment {
            Segment(
                kind: kind,
                startMinute: startMinute,
                endMinute: endMinute,
                yTop: yTop,
                height: height,
                isEmpty: isEmpty
            )
        }
    }

    /// The rest bands to render (label + frame), derived once from the segments.
    struct RestBand: Identifiable {
        /// Compressed top y (INCLUDING `topPadding`), ready for a view frame.
        let y: CGFloat
        let height: CGFloat
        /// Localized `HH:MM – HH:MM` label of the collapsed real span.
        let label: String
        var id: CGFloat { y }
    }

    // MARK: - Derived metrics

    /// Number of hour rows (24).
    var totalHours: Int { Self.endHour - Self.startHour }

    /// Height of the compressed segment stack (excludes `topPadding`).
    var gridHeight: CGFloat { compressedHeight }

    /// Total content height including the top padding — the timeline view's
    /// intrinsic height. A small tail is added by the owning view.
    var contentHeight: CGFloat { compressedHeight + topPadding }

    // MARK: - Time → y (compressed)

    /// Minutes since this day's midnight for `date`, clamped to 0...1440. Uses a
    /// wall-clock component read so the mapping is stable regardless of `dayStart`
    /// arithmetic.
    private func minutes(for date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let raw = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return min(max(raw, 0), Self.endHour * 60)
    }

    /// The compressed y (INCLUDING `topPadding`) for `minute` (0...1440). Active
    /// segments interpolate linearly; a moment inside a collapsed gap maps to the
    /// proportional point of that gap's fixed 48px band.
    private func compressedY(forMinute minute: Int) -> CGFloat {
        guard let first = segments.first else { return topPadding }
        if minute <= first.startMinute { return topPadding + first.yTop }
        for segment in segments where minute >= segment.startMinute && minute <= segment.endMinute {
            let span = max(segment.endMinute - segment.startMinute, 1)
            let fraction = CGFloat(minute - segment.startMinute) / CGFloat(span)
            return topPadding + segment.yTop + fraction * segment.height
        }
        // Past the last segment's end — pin to the bottom of the stack.
        return topPadding + compressedHeight
    }

    /// The y-position (within the content, including `topPadding`) of the hour
    /// line at `hour` (0...24), in the compressed space.
    func yForHourLine(_ hour: Int) -> CGFloat {
        compressedY(forMinute: hour * 60)
    }

    /// The y-position (including `topPadding`) for an arbitrary moment `date`,
    /// used for event placement and the now-indicator, in the compressed space.
    func y(for date: Date) -> CGFloat {
        compressedY(forMinute: minutes(for: date))
    }

    /// True when the hour at `hour` falls inside (or on the boundary of) an active
    /// segment — so its gridline + gutter label should render. Hours buried inside
    /// a collapsed rest band are suppressed (they'd all pile onto the 48px band).
    func hourLineIsVisible(_ hour: Int) -> Bool {
        let minute = hour * 60
        return segments.contains { segment in
            segment.kind == .active && minute >= segment.startMinute && minute <= segment.endMinute
        }
    }

    /// The rest bands to render, as ready-to-frame `(y, height, label)` triples.
    func restBands() -> [RestBand] {
        segments.compactMap { segment in
            guard segment.kind == .rest else { return nil }
            return RestBand(
                y: topPadding + segment.yTop,
                height: segment.height,
                label: Self.restLabel(startMinute: segment.startMinute, endMinute: segment.endMinute)
            )
        }
    }

    // MARK: - Segment building

    /// Builds the compressed segment stack for `events` on `dayStart`. Merges the
    /// events' active minute-windows, then walks 00:00→24:00: gaps ≥
    /// ``restThresholdMinutes`` (including the leading/trailing bookends to
    /// midnight) become fixed 48px rest segments; every other stretch is an active
    /// segment mapped linearly at `hourHeight`/60 px per minute. Every stretch is
    /// tagged `isEmpty` (no events overlapping it) so the fill-available slack pass
    /// can grow those windows only. On a today with no timed events the whole day is
    /// split into two empty windows at the now-line so the mark shows time before
    /// and after (spec §2).
    private static func buildSegments(
        events: [OccurrenceVM],
        dayStart: Date,
        calendar: Calendar,
        hourHeight: CGFloat,
        isToday: Bool,
        now: Date
    ) -> (segments: [Segment], height: CGFloat) {
        let pxPerMinute = hourHeight / 60
        let dayEnd = Self.endHour * 60

        // Collect each timed event's [start, end] window in minutes-since-midnight,
        // clamped to the day, with a minimum span so a zero-length event still
        // opens a window.
        var windows: [(start: Int, end: Int)] = []
        for event in events {
            let startMinute = Self.minute(of: event.startAt, dayStart: dayStart, calendar: calendar, cap: dayEnd)
            let rawEnd = Self.minute(of: event.endAt, dayStart: dayStart, calendar: calendar, cap: dayEnd)
            let endMinute = max(rawEnd, startMinute + 1)
            windows.append((start: startMinute, end: min(endMinute, dayEnd)))
        }
        windows.sort { $0.start < $1.start }

        // Merge overlapping/touching windows into disjoint active spans.
        var merged: [(start: Int, end: Int)] = []
        for window in windows {
            if var last = merged.last, window.start <= last.end {
                last.end = max(last.end, window.end)
                merged[merged.count - 1] = last
            } else {
                merged.append(window)
            }
        }

        var segments: [Segment] = []
        var cursorY: CGFloat = 0

        /// Appends a linearly-mapped active stretch, tagging whether it holds events.
        func appendActive(from startMinute: Int, to endMinute: Int, isEmpty: Bool) {
            guard endMinute > startMinute else { return }
            let height = CGFloat(endMinute - startMinute) * pxPerMinute
            segments.append(
                Segment(
                    kind: .active, startMinute: startMinute, endMinute: endMinute,
                    yTop: cursorY, height: height, isEmpty: isEmpty
                )
            )
            cursorY += height
        }

        /// Appends a collapsed fixed-height rest band (always an empty window).
        func appendRest(from startMinute: Int, to endMinute: Int) {
            guard endMinute > startMinute else { return }
            segments.append(
                Segment(
                    kind: .rest, startMinute: startMinute, endMinute: endMinute,
                    yTop: cursorY, height: restBandHeight, isEmpty: true
                )
            )
            cursorY += restBandHeight
        }

        // No events. On today, split the empty day at the now-line into a leading
        // (00:00 → now) and trailing (now → 24:00) empty window, so the fill pass
        // can grow both and the now mark sits between "time before" and "time after".
        // On any other day, a single empty full-day window (grows to fill).
        guard !merged.isEmpty else {
            if isToday {
                let nowMinute = min(max(Self.wallClockMinute(of: now, calendar: calendar), 0), dayEnd)
                appendActive(from: 0, to: nowMinute, isEmpty: true)
                appendActive(from: nowMinute, to: dayEnd, isEmpty: true)
            } else {
                appendActive(from: 0, to: dayEnd, isEmpty: true)
            }
            return (segments, cursorY)
        }

        // Assemble the ordered stretch list [0 ... 1440]: gaps ≥ threshold become
        // rest segments; empty sub-threshold gaps stay ruled active windows but are
        // tagged empty so they can still absorb slack.
        var cursorMinute = 0

        /// Emits an empty gap: a collapsed rest band when long enough, else a ruled
        /// active window flagged empty.
        func appendGap(from startMinute: Int, to endMinute: Int) {
            guard endMinute > startMinute else { return }
            if endMinute - startMinute >= restThresholdMinutes {
                appendRest(from: startMinute, to: endMinute)
            } else {
                appendActive(from: startMinute, to: endMinute, isEmpty: true)
            }
        }

        // Leading bookend: 00:00 → first active span start.
        appendGap(from: cursorMinute, to: merged[0].start)
        cursorMinute = merged[0].start

        for (index, span) in merged.enumerated() {
            // The active span itself (holds events).
            appendActive(from: span.start, to: span.end, isEmpty: false)
            cursorMinute = span.end
            // The gap to the next span (or to midnight for the last one).
            let nextStart = index + 1 < merged.count ? merged[index + 1].start : dayEnd
            appendGap(from: cursorMinute, to: nextStart)
            cursorMinute = nextStart
        }

        return (segments, cursorY)
    }

    /// Minutes-since-midnight of `date` relative to `dayStart`, clamped to
    /// `0...cap`. Uses wall-clock components so an event that starts before this
    /// day (a multi-day span) clamps to 0 and one ending after clamps to `cap`.
    private static func minute(of date: Date, dayStart: Date, calendar: Calendar, cap: Int) -> Int {
        if date <= dayStart { return 0 }
        let secondsFromStart = date.timeIntervalSince(dayStart)
        let minutes = Int(secondsFromStart / 60)
        return min(max(minutes, 0), cap)
    }

    /// Wall-clock minutes-since-midnight of `date` (0...1440), read from its hour +
    /// minute components — matching the instance ``minutes(for:)`` so the build-time
    /// now-split lands on the same coordinate the now-line later maps to.
    private static func wallClockMinute(of date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let raw = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return min(max(raw, 0), Self.endHour * 60)
    }

    /// Localized `HH:MM – HH:MM` (en dash) span label for a collapsed rest band.
    private static func restLabel(startMinute: Int, endMinute: Int) -> String {
        let start = String(format: "%02d:%02d", startMinute / 60, startMinute % 60)
        let end = String(format: "%02d:%02d", endMinute / 60, endMinute % 60)
        return "\(start) – \(end)"
    }

    // MARK: - Event placement

    /// A positioned event block: the occurrence plus its frame in the timeline's
    /// content coordinate space, ready to hand to a cell.
    struct PositionedEvent: Identifiable {
        let event: OccurrenceVM
        let frame: CGRect
        var id: String { event.id }
    }

    /// Lays out `events` into absolute frames inside a content rect of
    /// `eventsColumnWidth` width, accounting for overlap columns exactly as the
    /// SwiftUI timeline did. The returned frames are in the timeline content's
    /// coordinate space (origin at the events column's top-left), with y already
    /// mapped through the compressed ``y(for:)``.
    func positionedEvents(_ events: [OccurrenceVM], eventsColumnWidth: CGFloat) -> [PositionedEvent] {
        guard eventsColumnWidth > 0 else { return [] }
        let layouts = Self.overlapColumns(for: events)
        return layouts.map { layout in
            let columnWidth = eventsColumnWidth / CGFloat(layout.columnCount)
            let width = max(columnWidth - Self.columnInset, 0)
            let top = y(for: layout.event.startAt)
            let bottom = y(for: layout.event.endAt)
            let height = max(bottom - top, Self.minimumEventHeight)
            let frame = CGRect(
                x: CGFloat(layout.column) * columnWidth,
                y: top,
                width: width,
                height: height
            )
            return PositionedEvent(event: layout.event, frame: frame)
        }
    }

    /// The y-position (content space) for the now-indicator line at `now`.
    func nowIndicatorY(_ now: Date) -> CGFloat {
        y(for: now)
    }

    /// True when `date` falls on today, so the now-indicator should render.
    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    /// True when the now-line should render on today. Because the fill pass
    /// (``TimelineSlackDistributor``) guarantees the window containing "now" keeps at
    /// least ``nowRegionMinimumHeight``, the now-line is ALWAYS meaningful on today —
    /// even when "now" lands in a grown empty window or a rest band it protected. It
    /// is only false in the degenerate case of an empty segment stack.
    func nowIsVisible(_ now: Date) -> Bool {
        !segments.isEmpty
    }

    // MARK: - Overlap columns

    /// Column assignment for one event within its overlap cluster.
    private struct ColumnLayout {
        let event: OccurrenceVM
        let column: Int
        let columnCount: Int
    }

    /// Assigns each event a `(column, columnCount)` so overlapping events render
    /// side-by-side, while a non-overlapping event spans the full width. This is
    /// a faithful port of `DayScheduleView.layout(events:)` — same greedy
    /// free-column packing over time-sorted clusters.
    private static func overlapColumns(for events: [OccurrenceVM]) -> [ColumnLayout] {
        let sorted = events.sorted { $0.startAt < $1.startAt }
        var result: [ColumnLayout] = []
        var cluster: [OccurrenceVM] = []
        var clusterEnd: Date = .distantPast

        func flush() {
            guard !cluster.isEmpty else { return }
            var columnEnds: [Date] = []
            var assignments: [String: Int] = [:]
            for event in cluster {
                if let freeColumn = columnEnds.firstIndex(where: { $0 <= event.startAt }) {
                    columnEnds[freeColumn] = event.endAt
                    assignments[event.id] = freeColumn
                } else {
                    assignments[event.id] = columnEnds.count
                    columnEnds.append(event.endAt)
                }
            }
            let total = columnEnds.count
            for event in cluster {
                if let column = assignments[event.id] {
                    result.append(ColumnLayout(event: event, column: column, columnCount: total))
                }
            }
            cluster.removeAll()
            clusterEnd = .distantPast
        }

        for event in sorted {
            if cluster.isEmpty || event.startAt < clusterEnd {
                cluster.append(event)
                clusterEnd = max(clusterEnd, event.endAt)
            } else {
                flush()
                cluster.append(event)
                clusterEnd = event.endAt
            }
        }
        flush()
        return result
    }
}

/// Fill-available-height strategy for the day timeline: grows ONLY the empty
/// windows of a built segment stack so the schedule occupies at least a target
/// (viewport) height, while every event-bearing segment keeps its exact
/// proportional height. Isolating the redistribution here keeps
/// ``DayTimelineLayout``'s build step a pure piecewise map and makes the "where
/// does the slack go" policy readable and independently testable.
///
/// **Weighting.** The leftover `target − base` is split across the empty windows
/// (collapsed rest bands + leading/trailing bookends + inter-event gaps) in
/// proportion to each window's REAL collapsed duration, so longer empty spans
/// absorb more slack. Each grown window is floored at
/// ``DayTimelineLayout/minimumSlackWindowHeight`` so even a hairline gap becomes a
/// visible breather.
///
/// **Now-region protection.** The empty window that contains `nowMinute` (today
/// only) is additionally floored at ``DayTimelineLayout/nowRegionMinimumHeight`` —
/// applied even when there is no leftover — so the now-line and its `HH:mm` label
/// always render unclipped and are never compressed away.
struct TimelineSlackDistributor {

    /// The height the reflowed stack should reach at minimum (segment-stack space,
    /// i.e. excluding the view's `topPadding`).
    let targetHeight: CGFloat
    /// Minutes-since-midnight of "now" whose containing empty window is protected,
    /// or `nil` when the day being laid out is not today.
    let nowMinute: Int?

    /// Reflows `segments` so the empty windows absorb the fill slack and the
    /// now-region keeps its guaranteed minimum. Event-bearing segments are copied
    /// through unchanged (never shrunk, never grown); only `yTop` is re-cascaded.
    /// Returns the segments already re-stacked plus the new total height.
    func distribute(
        segments: [DayTimelineLayout.Segment],
        baseHeight: CGFloat
    ) -> (segments: [DayTimelineLayout.Segment], height: CGFloat) {
        guard !segments.isEmpty else { return (segments, baseHeight) }

        // Indices of the windows eligible to grow (empty stretches only).
        let emptyIndices = segments.indices.filter { segments[$0].isEmpty }

        // Per-window extra height, keyed by segment index. Start at zero (= keep
        // base height) for every segment; only empty windows accrue extra.
        var extraByIndex: [Int: CGFloat] = [:]

        // 1) Now-region floor — applied first and independent of any leftover, so a
        //    tiny empty window under "now" is lifted to a visible, unclipped band.
        if let nowIndex = nowRegionIndex(in: segments) {
            let deficit = DayTimelineLayout.nowRegionMinimumHeight - segments[nowIndex].height
            if deficit > 0 { extraByIndex[nowIndex] = deficit }
        }

        // 2) Fill leftover across empty windows, weighted by real duration. The
        //    now-region's already-granted floor counts toward the fill, so we don't
        //    double-spend past the target.
        let grantedSoFar = extraByIndex.values.reduce(0, +)
        let leftover = max(0, targetHeight - baseHeight - grantedSoFar)
        let isFilling = leftover > 0 && !emptyIndices.isEmpty
        if isFilling {
            let weights = emptyIndices.map { index -> CGFloat in
                CGFloat(max(segments[index].endMinute - segments[index].startMinute, 1))
            }
            let totalWeight = weights.reduce(0, +)
            if totalWeight > 0 {
                for (offset, index) in emptyIndices.enumerated() {
                    let share = leftover * (weights[offset] / totalWeight)
                    extraByIndex[index, default: 0] += share
                }
            }

            // 3) Minimum-per-window floor — ONLY while actively filling, so no grown
            //    gap collapses below a usable height. When there is no leftover we
            //    leave empty windows at their natural (ruled) height and don't inflate
            //    them just to hit a minimum.
            for index in emptyIndices {
                let grown = segments[index].height + extraByIndex[index, default: 0]
                if grown < DayTimelineLayout.minimumSlackWindowHeight {
                    extraByIndex[index] = DayTimelineLayout.minimumSlackWindowHeight - segments[index].height
                }
            }
        }

        // Nothing to do — no floors triggered and no leftover.
        guard !extraByIndex.isEmpty else { return (segments, baseHeight) }

        // Re-cascade yTop with the per-window extras applied.
        var reflowed: [DayTimelineLayout.Segment] = []
        reflowed.reserveCapacity(segments.count)
        var cursorY: CGFloat = 0
        for (index, segment) in segments.enumerated() {
            let height = segment.height + extraByIndex[index, default: 0]
            reflowed.append(segment.reflowed(yTop: cursorY, height: height))
            cursorY += height
        }
        return (reflowed, cursorY)
    }

    /// The index of the empty window that contains `nowMinute` (today only), or
    /// `nil` when there is no now-minute or it lands only on non-empty segments.
    /// Prefers an empty window; an event-bearing segment under "now" needs no floor
    /// because its own event tiles already keep it tall.
    private func nowRegionIndex(in segments: [DayTimelineLayout.Segment]) -> Int? {
        guard let nowMinute else { return nil }
        return segments.firstIndex { segment in
            segment.isEmpty && nowMinute >= segment.startMinute && nowMinute <= segment.endMinute
        }
    }
}

/// The day timeline rendered as a single self-sizing UIKit view: hour rules,
/// half-hour ticks, hourly time labels, collapsed rest bands, absolutely-
/// positioned event blocks (``DayTimelineEventCell``), and a clay now-indicator
/// on today (refreshed each minute). This is the UIKit body of `DayScheduleView`;
/// it owns no data, taking events + theme through ``configure(events:date:theme:)``
/// and forwarding the two cell intents through `onToggle` / `onSelect`.
final class DayTimelineDayView: UIView {

    // MARK: - Intents (forwarded from cells)

    var onToggle: ((OccurrenceVM) -> Void)?
    var onSelect: ((OccurrenceVM) -> Void)?

    // MARK: - Geometry

    /// The layout math. Rebuilt (with the day's events, for time-skips, and the
    /// current viewport height for fill-available) on every `configure` and whenever
    /// the available height changes.
    private(set) var layout = DayTimelineLayout(hourHeight: 36, topPadding: 10)

    /// Extra tail below the last segment so the final tile is never cut off — the
    /// spec's 8px tail plus ~30 minutes' worth of breathing room.
    private var tailPadding: CGFloat { (theme?.hourHeight ?? 36) / 2 + 8 }

    /// Right-aligned `HH:mm` mono formatter for the now-line time label, fixed to a
    /// 24-hour clock (POSIX) to match the timeline's other mono times.
    private static let nowTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var events: [OccurrenceVM] = []
    private var date = Date()
    private var theme: CalendarTheme?
    /// The last viewport height the layout was filled to, so a pure height change in
    /// `layoutSubviews` can rebuild the fill without a redundant rebuild every pass.
    private var availableHeight: CGFloat = 0

    private var eventCells: [DayTimelineEventCell] = []
    private var hourLineLayers: [CALayer] = []
    private var halfHourLineLayers: [CALayer] = []
    private var hourLabels: [UILabel] = []
    private var restBandViews: [DayTimelineRestBandView] = []
    private let nowLine = UIView()
    private let nowDot = UIView()
    /// The exact current `HH:mm`, rendered just above the now-line at its right edge.
    private let nowTimeLabel = UILabel()
    private var nowTimer: Timer?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        nowLine.isUserInteractionEnabled = false
        nowDot.isUserInteractionEnabled = false
        nowDot.layer.cornerRadius = 4
        nowTimeLabel.isUserInteractionEnabled = false
        nowTimeLabel.textAlignment = .right
        addSubview(nowLine)
        addSubview(nowDot)
        addSubview(nowTimeLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        nowTimer?.invalidate()
    }

    // MARK: - Sizing

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: layout.contentHeight + tailPadding)
    }

    // MARK: - Configuration

    /// Rebuilds the timeline for `events` on `date` with `theme`. Rebuilds the
    /// layout math (with the day's timed events, so gaps collapse, filled to the
    /// current viewport), refreshes the grid + labels + rest bands, and rebuilds the
    /// event blocks.
    func configure(events: [OccurrenceVM], date: Date, theme: CalendarTheme) {
        self.events = events
        self.date = date
        self.theme = theme
        availableHeight = currentAvailableHeight()
        rebuildLayout()
        invalidateIntrinsicContentSize()
        rebuildGrid()
        rebuildLabels()
        rebuildRestBands()
        rebuildEventCells()
        updateNowIndicator()
        startNowTimerIfNeeded()
        setNeedsLayout()
    }

    /// (Re)builds the layout math from the current `events` / `date` / `theme` and
    /// the cached ``availableHeight``, so the schedule fills at least the viewport
    /// and the now-region stays protected. Split out so a pure viewport-height change
    /// in `layoutSubviews` can re-fill without re-creating cells.
    private func rebuildLayout() {
        guard let theme else { return }
        layout = DayTimelineLayout(
            hourHeight: theme.hourHeight,
            topPadding: theme.timelineTopPadding,
            date: date,
            events: events,
            availableHeight: availableHeight,
            now: Date()
        )
    }

    /// The viewport height the schedule should fill: the enclosing scroll view's
    /// bounds height (this view is pinned to that scroll's content guide, so its own
    /// bounds are the CONTENT height, not the viewport). Falls back to `0` — meaning
    /// "don't fill" — until the view is in a sized scroll view.
    private func currentAvailableHeight() -> CGFloat {
        guard let scrollView = superview as? UIScrollView else { return 0 }
        return max(0, scrollView.bounds.height - scrollView.adjustedContentInset.top)
    }

    // MARK: - Grid

    /// Builds (once) the hour + half-hour line layers, then re-colors them.
    private func rebuildGrid() {
        guard let theme else { return }
        if hourLineLayers.isEmpty {
            for _ in 0...layout.totalHours {
                let lineLayer = CALayer()
                layer.addSublayer(lineLayer)
                hourLineLayers.append(lineLayer)
            }
            for _ in 0..<layout.totalHours {
                let lineLayer = CALayer()
                layer.addSublayer(lineLayer)
                halfHourLineLayers.append(lineLayer)
            }
        }
        for lineLayer in hourLineLayers { lineLayer.backgroundColor = theme.separator.cgColor }
        for lineLayer in halfHourLineLayers {
            lineLayer.backgroundColor = theme.separator.withAlphaComponent(0.5).cgColor
        }
    }

    /// Builds the hourly time labels (00:00, 01:00, …, 24:00) once and re-styles
    /// them. Colon-separated `HH:mm`, one per hour, mono — matching the spec's
    /// gutter hour labels.
    private func rebuildLabels() {
        guard let theme else { return }
        if hourLabels.isEmpty {
            for hour in stride(from: DayTimelineLayout.startHour, through: DayTimelineLayout.endHour, by: 1) {
                let label = UILabel()
                label.text = String(format: "%02d:00", hour)
                label.isUserInteractionEnabled = false
                addSubview(label)
                hourLabels.append(label)
            }
        }
        for label in hourLabels {
            label.font = theme.codeSmall
            label.textColor = theme.textSecondary
        }
    }

    // MARK: - Rest bands

    /// Recreates the collapsed rest-band strips for the current layout.
    private func rebuildRestBands() {
        guard let theme else { return }
        for view in restBandViews { view.removeFromSuperview() }
        restBandViews = layout.restBands().map { band in
            let view = DayTimelineRestBandView()
            view.configure(label: band.label, theme: theme)
            insertSubview(view, belowSubview: nowLine)
            return view
        }
    }

    // MARK: - Event cells

    /// Recreates the absolutely-positioned event blocks for the current events.
    private func rebuildEventCells() {
        guard let theme else { return }
        for cell in eventCells { cell.removeFromSuperview() }
        eventCells = events.map { event in
            let cell = DayTimelineEventCell(frame: .zero)
            cell.configure(with: event, theme: theme)
            cell.onToggle = { [weak self] event in self?.onToggle?(event) }
            cell.onSelect = { [weak self] event in self?.onSelect?(event) }
            insertSubview(cell, belowSubview: nowLine)
            return cell
        }
        setNeedsLayout()
    }

    // MARK: - Now indicator

    private func startNowTimerIfNeeded() {
        nowTimer?.invalidate()
        nowTimer = nil
        guard layout.isToday(date) else {
            hideNowIndicator()
            return
        }
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            // Timer fires on the main run loop; hop to the MainActor explicitly,
            // binding `self` to a `let` first so nothing captures the weak `var`
            // inside the concurrently-executing task (Swift 6 strictness).
            MainActor.assumeIsolated {
                guard let self else { return }
                self.updateNowIndicator()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        nowTimer = timer
    }

    /// Hides the now-line, dot, and time label together.
    private func hideNowIndicator() {
        nowLine.isHidden = true
        nowDot.isHidden = true
        nowTimeLabel.isHidden = true
    }

    private func updateNowIndicator() {
        // The now-line renders on today whenever "now" maps onto the timeline. The
        // fill pass guarantees the window under "now" keeps enough height, so — per
        // spec §3 — the indicator is never hidden on today, even in a rest band.
        let now = Date()
        guard let theme, layout.isToday(date), layout.nowIsVisible(now) else {
            hideNowIndicator()
            return
        }
        nowLine.isHidden = false
        nowDot.isHidden = false
        nowTimeLabel.isHidden = false
        nowLine.backgroundColor = theme.secondary
        nowDot.backgroundColor = theme.secondary
        nowTimeLabel.font = theme.codeSmall
        nowTimeLabel.textColor = theme.secondary
        nowTimeLabel.text = Self.nowTimeFormatter.string(from: now)
        setNeedsLayout()
    }

    // MARK: - Layout pass

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        guard width > 0 else { return }

        // Re-fill the schedule when the viewport height changed (rotation, tab-bar
        // show/hide) so it keeps occupying at least the visible area. Only the
        // fill/y-mapping changes — segment/band/label COUNTS are unaffected — so a
        // cheap layout rebuild + intrinsic-size refresh suffices; cells are not
        // recreated.
        let latestAvailable = currentAvailableHeight()
        if abs(latestAvailable - availableHeight) > 0.5 {
            availableHeight = latestAvailable
            rebuildLayout()
            invalidateIntrinsicContentSize()
        }

        let eventsColumnX = DayTimelineLayout.timeColumnWidth + DayTimelineLayout.gutter
        let eventsColumnWidth = max(width - eventsColumnX, 0)

        // Hour lines span the full width; half-hour ticks only the events column.
        // Both are HIDDEN when their hour is buried in a collapsed rest band.
        for (index, lineLayer) in hourLineLayers.enumerated() {
            let hour = DayTimelineLayout.startHour + index
            let visible = layout.hourLineIsVisible(hour)
            lineLayer.isHidden = !visible
            guard visible else { continue }
            let yPosition = layout.yForHourLine(hour)
            lineLayer.frame = CGRect(x: 0, y: yPosition, width: width, height: 0.5)
        }
        let halfHourOffset = (theme?.hourHeight ?? 36) / 2
        for (index, lineLayer) in halfHourLineLayers.enumerated() {
            let hour = DayTimelineLayout.startHour + index
            // A half-hour tick is only shown when both its bounding hours are in an
            // active window (i.e. the half-hour itself is inside an active span).
            let visible = layout.hourLineIsVisible(hour) && layout.hourLineIsVisible(hour + 1)
            lineLayer.isHidden = !visible
            guard visible else { continue }
            let yPosition = layout.yForHourLine(hour) + halfHourOffset
            lineLayer.frame = CGRect(
                x: eventsColumnX, y: yPosition, width: eventsColumnWidth, height: 0.5
            )
        }

        // Hour labels sit just above their hour line, left-aligned in the gutter —
        // hidden together with a suppressed hour line.
        for (index, label) in hourLabels.enumerated() {
            let hour = DayTimelineLayout.startHour + index
            let visible = layout.hourLineIsVisible(hour)
            label.isHidden = !visible
            guard visible else { continue }
            label.sizeToFit()
            let yPosition = layout.yForHourLine(hour) - label.bounds.height / 2 - 4
            label.frame = CGRect(
                x: 0, y: yPosition,
                width: DayTimelineLayout.timeColumnWidth, height: label.bounds.height
            )
        }

        // Rest bands span the events column, at their compressed y.
        let restInsetLeft: CGFloat = eventsColumnX - 6
        for (view, band) in zip(restBandViews, layout.restBands()) {
            view.frame = CGRect(
                x: restInsetLeft,
                y: band.y,
                width: max(width - restInsetLeft - 6, 0),
                height: band.height
            )
        }

        // Event blocks, offset into the events column.
        let positioned = layout.positionedEvents(events, eventsColumnWidth: eventsColumnWidth)
        for (cell, placement) in zip(eventCells, positionedByID(positioned)) {
            var frame = placement.frame
            frame.origin.x += eventsColumnX
            cell.frame = frame
        }

        // Now indicator inset 8px from both edges on today, with the dot at the
        // leading edge (matches the design's left:8/right:8 clay rule).
        if !nowLine.isHidden {
            let nowInset: CGFloat = 8
            let yPosition = layout.nowIndicatorY(Date())
            nowLine.frame = CGRect(
                x: nowInset, y: yPosition - 0.75, width: max(width - nowInset * 2, 0), height: 1.5
            )
            nowDot.frame = CGRect(
                x: nowInset, y: yPosition - 4, width: 8, height: 8
            )
            layoutNowTimeLabel(lineY: yPosition, inset: nowInset, width: width)
        }
    }

    /// Positions the `HH:mm` now-label right-aligned near the right inset, anchored
    /// just above the now-line so it rides WITH the line as the timeline scrolls.
    /// There is no viewport-top clamp: `timelineScroll` has no scroll delegate, so a
    /// clamp would only re-evaluate on unrelated layout passes and slide off during a
    /// drag — and a now-line scrolled off-screen taking its label with it is fine,
    /// since the line itself is no longer visible either.
    private func layoutNowTimeLabel(lineY: CGFloat, inset: CGFloat, width: CGFloat) {
        nowTimeLabel.sizeToFit()
        let labelHeight = nowTimeLabel.bounds.height
        let labelWidth = min(nowTimeLabel.bounds.width, max(width - inset * 2, 0))
        // 2pt above the line, pinned to the line so the label moves with it.
        let gapAboveLine: CGFloat = 2
        let top = lineY - gapAboveLine - labelHeight
        nowTimeLabel.frame = CGRect(
            x: max(width - inset - labelWidth, inset),
            y: top,
            width: labelWidth,
            height: labelHeight
        )
    }

    /// Reorders the positioned events to match `eventCells` order (cells were
    /// created in `events` order; positioning sorts internally), so zip aligns.
    private func positionedByID(_ positioned: [DayTimelineLayout.PositionedEvent]) -> [DayTimelineLayout.PositionedEvent] {
        let byID = Dictionary(uniqueKeysWithValues: positioned.map { ($0.id, $0) })
        return events.compactMap { byID[$0.id] }
    }
}

/// A collapsed empty-gap "rest band": a centered mono `HH:MM – HH:MM` label
/// flanked left and right by 1px dashed separator rules (theme separator @0.7),
/// standing in for hours the day skips.
final class DayTimelineRestBandView: UIView {

    private let leftRule = CAShapeLayer()
    private let rightRule = CAShapeLayer()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        label.textAlignment = .center
        label.numberOfLines = 1
        addSubview(label)
        for rule in [leftRule, rightRule] {
            rule.lineWidth = 1
            rule.lineDashPattern = [3, 3]
            rule.fillColor = UIColor.clear.cgColor
            layer.addSublayer(rule)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Sets the collapsed-span label + theme colors.
    func configure(label text: String, theme: CalendarTheme) {
        label.text = text
        label.font = theme.codeSmall
        label.textColor = theme.textSecondary
        let ruleColor = theme.separator.withAlphaComponent(0.7).cgColor
        leftRule.strokeColor = ruleColor
        rightRule.strokeColor = ruleColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.sizeToFit()
        let labelWidth = min(label.bounds.width, bounds.width)
        let centerY = bounds.midY
        label.frame = CGRect(
            x: (bounds.width - labelWidth) / 2,
            y: centerY - label.bounds.height / 2,
            width: labelWidth,
            height: label.bounds.height
        )
        // Dashed rules flank the label with an 8px gap on each side.
        let gap: CGFloat = 8
        let leftEnd = label.frame.minX - gap
        let rightStart = label.frame.maxX + gap
        let leftPath = UIBezierPath()
        leftPath.move(to: CGPoint(x: 0, y: centerY))
        leftPath.addLine(to: CGPoint(x: max(leftEnd, 0), y: centerY))
        leftRule.path = leftPath.cgPath
        let rightPath = UIBezierPath()
        rightPath.move(to: CGPoint(x: min(rightStart, bounds.width), y: centerY))
        rightPath.addLine(to: CGPoint(x: bounds.width, y: centerY))
        rightRule.path = rightPath.cgPath
    }
}
