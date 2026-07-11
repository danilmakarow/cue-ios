//
//  DayTimelineLayout.swift
//  cue
//

import UIKit

/// Pure timeline geometry for a single day. The schedule is a top-aligned stack
/// (`align-content: start` — never stretched to fill evenly), where:
///
/// - **Every empty interval that would waste space is COLLAPSED** into a fixed
///   ``restBandHeight`` "rest band" — a compact, tappable placeholder labelled with
///   the real span it stands in for. A gap is only collapsed when collapsing
///   actually SAVES space (its real height exceeds the band height); a short gap
///   between back-to-back events keeps its real (small) height, so collapsing never
///   *adds* empty space.
/// - **On today, "now" is treated as a 2-hour task**: a synthetic active window of
///   `[now − 1h, now + 1h]` is merged into the event windows, so the hour before and
///   after the current moment always render at real scale with the now-line through
///   the middle.
/// - **Fill only when there is slack, and only around now.** If the natural stacked
///   height is SHORTER than the viewport, the ONE collapsed gap adjacent to the
///   now-window on the side of its nearest task is un-collapsed (rendered at real
///   duration). Nothing else is stretched — leftover space simply sits below the
///   stack. This replaces the old "distribute slack across every empty window"
///   behaviour, which padded the schedule with unwanted gaps.
/// - **Collapsed gaps can be expanded by tapping them.** The owning view tracks the
///   set of user-expanded gap keys and rebuilds; an expanded gap renders at real
///   duration (ruled grid + hour labels), exactly like the auto-expanded now-gap.
///
/// The now-line and hour gridlines stay correct across the compression because every
/// y-mapping runs through the same piecewise-linear ``y(for:)``.
///
/// This is *only* the math + frame computation — no view ownership — so the owning
/// ``DayTimelineDayView`` (and its tests) can position cells without re-deriving the
/// rules. Overlap columns are computed exactly as the old SwiftUI view did.
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
    /// fades its clipped title rather than hard-clipping it.
    static let minimumEventHeight: CGFloat = 18
    /// Horizontal inset shaved off each overlap column's width (matches the
    /// SwiftUI `columnWidth - 2`).
    static let columnInset: CGFloat = 2

    /// The fixed rendered height of a collapsed rest band, regardless of how many
    /// real minutes it spans. An empty gap is collapsed to this height ONLY when its
    /// real (proportional) height would exceed it — so collapsing always saves space
    /// and never inflates a short gap.
    static let restBandHeight: CGFloat = 48

    /// The synthetic "now" window's half-span, in minutes: the current moment is
    /// treated as a 2-hour task spanning `[now − nowHalfSpan, now + nowHalfSpan]`.
    static let nowHalfSpanMinutes: Int = 60

    private let hourHeight: CGFloat
    private let topPadding: CGFloat
    private let calendar = Calendar.current
    /// The day these segments describe (start-of-day), so `minutes(for:)` maps a
    /// `Date` to minutes-since-this-midnight even across DST-ish arithmetic.
    private let dayStart: Date
    /// The piecewise segments (active windows + collapsed rest bands) that define
    /// the compressed y-mapping, in ascending time order.
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
    ///   - availableHeight: the viewport height the schedule may fill UP TO. When the
    ///     natural stacked height is shorter, the single collapsed gap next to "now"
    ///     is un-collapsed to occupy real time toward the nearest task; the schedule
    ///     is never stretched beyond that. Pass `0` (default) to skip the fill.
    ///   - now: the current moment — treated as a 2-hour task window on today.
    ///   - expandedGapKeys: gap keys (`"start-end"` minute ranges) the user has
    ///     tapped to expand; those gaps render at real duration instead of collapsed.
    init(
        hourHeight: CGFloat,
        topPadding: CGFloat,
        date: Date = Date(),
        events: [OccurrenceVM] = [],
        availableHeight: CGFloat = 0,
        now: Date = Date(),
        expandedGapKeys: Set<String> = []
    ) {
        self.hourHeight = hourHeight
        self.topPadding = topPadding
        let start = Calendar.current.startOfDay(for: date)
        self.dayStart = start
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let nowMinute = isToday ? Self.wallClockMinute(of: now, calendar: calendar) : nil

        // First pass: collapse empty gaps (except any the user already expanded),
        // with "now" injected as a 2-hour active window on today.
        var built = Self.buildSegments(
            events: events,
            dayStart: start,
            calendar: calendar,
            hourHeight: hourHeight,
            nowMinute: nowMinute,
            expandedGapKeys: expandedGapKeys
        )

        // Fill-when-slack (today only): if the stack is shorter than the viewport,
        // un-collapse the ONE collapsed gap adjacent to the now-window that leads to
        // the nearest real task, then rebuild once. No other window is grown —
        // leftover space sits below the stack (align-content: start).
        if let nowMinute {
            let target = max(0, availableHeight - topPadding)
            let realBoundaries = Self.realEventBoundaries(events: events, dayStart: start, calendar: calendar)
            if built.height < target,
               let autoKey = Self.autoExpandGapKey(
                   segments: built.segments, nowMinute: nowMinute, realBoundaries: realBoundaries
               ),
               !expandedGapKeys.contains(autoKey) {
                built = Self.buildSegments(
                    events: events,
                    dayStart: start,
                    calendar: calendar,
                    hourHeight: hourHeight,
                    nowMinute: nowMinute,
                    expandedGapKeys: expandedGapKeys.union([autoKey])
                )
            }
        }

        self.segments = built.segments
        self.compressedHeight = built.height
    }

    // MARK: - Segment model

    /// One contiguous stretch of the compressed timeline.
    enum SegmentKind: Equatable {
        /// A normal, linearly-mapped active window (hours render at `hourHeight`) —
        /// an event window, the now-window, an expanded gap, or a short empty gap.
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

        /// Real duration of the stretch, in minutes.
        var durationMinutes: Int { endMinute - startMinute }
    }

    /// The rest bands to render (label + frame + tap key), derived once from the
    /// segments.
    struct RestBand: Identifiable {
        /// Stable identity of the collapsed gap (its `"start-end"` minute range),
        /// handed back to the layout when the user taps to expand it.
        let gapKey: String
        let startMinute: Int
        let endMinute: Int
        /// Compressed top y (INCLUDING `topPadding`), ready for a view frame.
        let y: CGFloat
        let height: CGFloat
        /// Localized `HH:MM – HH:MM` label of the collapsed real span.
        let label: String
        var id: String { gapKey }
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
    /// proportional point of that gap's fixed band.
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
    /// a collapsed rest band are suppressed (they'd all pile onto the band).
    func hourLineIsVisible(_ hour: Int) -> Bool {
        let minute = hour * 60
        return segments.contains { segment in
            segment.kind == .active && minute >= segment.startMinute && minute <= segment.endMinute
        }
    }

    /// The rest bands to render, as ready-to-frame `(gapKey, span, y, height, label)`
    /// values.
    func restBands() -> [RestBand] {
        segments.compactMap { segment in
            guard segment.kind == .rest else { return nil }
            return RestBand(
                gapKey: Self.gapKey(startMinute: segment.startMinute, endMinute: segment.endMinute),
                startMinute: segment.startMinute,
                endMinute: segment.endMinute,
                y: topPadding + segment.yTop,
                height: segment.height,
                label: Self.restLabel(startMinute: segment.startMinute, endMinute: segment.endMinute)
            )
        }
    }

    // MARK: - Segment building

    /// Builds the compressed segment stack for `events` on `dayStart`. Merges the
    /// events' active minute-windows (plus a 2-hour now-window on today), then walks
    /// 00:00→24:00: every empty gap (leading/trailing bookends + inter-event gaps) is
    /// collapsed to a fixed ``restBandHeight`` band WHEN collapsing saves space and
    /// the gap isn't in `expandedGapKeys`; otherwise it renders at real duration.
    /// Active windows render linearly at `hourHeight`/60 px per minute. The stack is
    /// top-aligned — never stretched.
    private static func buildSegments(
        events: [OccurrenceVM],
        dayStart: Date,
        calendar: Calendar,
        hourHeight: CGFloat,
        nowMinute: Int?,
        expandedGapKeys: Set<String>
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

        // On today, treat "now" as a 2-hour task so the current moment always renders
        // at real scale with the now-line through its middle. Merged with events.
        if let nowMinute {
            let start = min(max(nowMinute - Self.nowHalfSpanMinutes, 0), dayEnd)
            let end = min(max(nowMinute + Self.nowHalfSpanMinutes, 0), dayEnd)
            if end > start { windows.append((start: start, end: end)) }
        }

        // Merge overlapping/touching windows into disjoint active spans.
        let merged = Self.merge(windows)

        var segments: [Segment] = []
        var cursorY: CGFloat = 0

        /// Appends a linearly-mapped active stretch (event window, now-window,
        /// expanded gap, or a short empty gap kept at real height).
        func appendActive(from startMinute: Int, to endMinute: Int) {
            guard endMinute > startMinute else { return }
            let height = CGFloat(endMinute - startMinute) * pxPerMinute
            segments.append(
                Segment(kind: .active, startMinute: startMinute, endMinute: endMinute, yTop: cursorY, height: height)
            )
            cursorY += height
        }

        /// Emits an empty gap: a collapsed fixed-height rest band when collapsing
        /// saves space and the gap isn't user-expanded; otherwise a real-height
        /// active window (short gaps and expanded gaps stay at real scale).
        func appendGap(from startMinute: Int, to endMinute: Int) {
            guard endMinute > startMinute else { return }
            let realHeight = CGFloat(endMinute - startMinute) * pxPerMinute
            let key = Self.gapKey(startMinute: startMinute, endMinute: endMinute)
            let shouldCollapse = realHeight > restBandHeight && !expandedGapKeys.contains(key)
            guard shouldCollapse else {
                appendActive(from: startMinute, to: endMinute)
                return
            }
            segments.append(
                Segment(kind: .rest, startMinute: startMinute, endMinute: endMinute, yTop: cursorY, height: restBandHeight)
            )
            cursorY += restBandHeight
        }

        // No events and not today (today always injects the now-window): a single
        // full-day empty gap, collapsed to one band.
        guard !merged.isEmpty else {
            appendGap(from: 0, to: dayEnd)
            return (segments, cursorY)
        }

        // Leading bookend, then each active span followed by the gap after it.
        appendGap(from: 0, to: merged[0].start)
        for (index, span) in merged.enumerated() {
            appendActive(from: span.start, to: span.end)
            let nextStart = index + 1 < merged.count ? merged[index + 1].start : dayEnd
            appendGap(from: span.end, to: nextStart)
        }

        return (segments, cursorY)
    }

    /// The gap key adjacent to the now-window to auto-expand when there is slack: the
    /// collapsed rest band immediately before or after the active window containing
    /// "now" whose FAR edge touches a real event boundary (i.e. the gap actually
    /// leads to a task, never to a day edge), preferring the SHORTER such band (the
    /// nearer task); ties break toward the later (after) side. Returns `nil` when
    /// neither neighbour qualifies — a task already adjacent to "now" (its gap open),
    /// or an empty day — so nothing is stretched and leftover space sits below.
    private static func autoExpandGapKey(
        segments: [Segment],
        nowMinute: Int,
        realBoundaries: Set<Int>
    ) -> String? {
        guard let nowIndex = segments.firstIndex(where: { segment in
            segment.kind == .active && nowMinute >= segment.startMinute && nowMinute <= segment.endMinute
        }) else { return nil }

        /// A neighbour qualifies only if it is a collapsed gap whose far edge (the
        /// side away from "now") lands on a real event boundary — so expanding it
        /// reveals real time between "now" and an actual task, not empty day-edge.
        func qualifyingNeighbor(at index: Int, farEdge: (Segment) -> Int) -> Segment? {
            guard index >= 0, index < segments.count else { return nil }
            let segment = segments[index]
            guard segment.kind == .rest, realBoundaries.contains(farEdge(segment)) else { return nil }
            return segment
        }
        let before = qualifyingNeighbor(at: nowIndex - 1, farEdge: { $0.startMinute })
        let after = qualifyingNeighbor(at: nowIndex + 1, farEdge: { $0.endMinute })

        let chosen: Segment?
        switch (before, after) {
        case let (before?, after?):
            chosen = before.durationMinutes < after.durationMinutes ? before : after
        case let (before?, nil):
            chosen = before
        case let (nil, after?):
            chosen = after
        default:
            chosen = nil
        }
        guard let chosen else { return nil }
        return gapKey(startMinute: chosen.startMinute, endMinute: chosen.endMinute)
    }

    /// Merges overlapping/touching `[start, end]` minute windows into disjoint spans,
    /// ascending. Shared by the segment build (events + now-window) and the
    /// real-event boundary set used to decide which gap leads to a task.
    private static func merge(_ windows: [(start: Int, end: Int)]) -> [(start: Int, end: Int)] {
        let sorted = windows.sorted { $0.start < $1.start }
        var merged: [(start: Int, end: Int)] = []
        for window in sorted {
            if var last = merged.last, window.start <= last.end {
                last.end = max(last.end, window.end)
                merged[merged.count - 1] = last
            } else {
                merged.append(window)
            }
        }
        return merged
    }

    /// The set of merged REAL-event boundary minutes (starts + ends, no now-window),
    /// used to confirm a collapsed gap actually abuts a task before auto-expanding it.
    private static func realEventBoundaries(events: [OccurrenceVM], dayStart: Date, calendar: Calendar) -> Set<Int> {
        let dayEnd = Self.endHour * 60
        var windows: [(start: Int, end: Int)] = []
        for event in events {
            let startMinute = Self.minute(of: event.startAt, dayStart: dayStart, calendar: calendar, cap: dayEnd)
            let rawEnd = Self.minute(of: event.endAt, dayStart: dayStart, calendar: calendar, cap: dayEnd)
            let endMinute = max(rawEnd, startMinute + 1)
            windows.append((start: startMinute, end: min(endMinute, dayEnd)))
        }
        return Set(Self.merge(windows).flatMap { [$0.start, $0.end] })
    }

    /// Stable `"start-end"` identity for an empty gap, shared by the build (to honour
    /// `expandedGapKeys`), the rendered ``RestBand``, and the tap-to-expand handler.
    private static func gapKey(startMinute: Int, endMinute: Int) -> String {
        "\(startMinute)-\(endMinute)"
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
    /// now-window lands on the same coordinate the now-line later maps to.
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

    /// True when the now-line should render on today. Because "now" is always laid
    /// out as a 2-hour active window, the now-line is meaningful whenever the segment
    /// stack is non-empty on today.
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

/// The day timeline rendered as a single self-sizing UIKit view: hour rules,
/// half-hour ticks, hourly time labels, collapsed (tappable) rest bands,
/// absolutely-positioned event blocks (``DayTimelineEventCell``), and a now-indicator
/// on today (refreshed each minute). This is the UIKit body of `DayScheduleView`;
/// it owns no data, taking events + theme through ``configure(events:date:theme:)``
/// and forwarding the two cell intents through `onToggle` / `onSelect`. Tapping a
/// collapsed rest band expands it in place.
final class DayTimelineDayView: UIView {

    // MARK: - Intents (forwarded from cells)

    var onToggle: ((OccurrenceVM) -> Void)?
    var onSelect: ((OccurrenceVM) -> Void)?

    // MARK: - Geometry

    /// The layout math. Rebuilt (with the day's events, the current viewport height
    /// for the slack-fill, and the set of user-expanded gaps) on every `configure`,
    /// on a gap tap, and whenever the available height changes.
    private(set) var layout = DayTimelineLayout(hourHeight: 36, topPadding: 10)

    /// Gap keys the user has tapped to expand. Reset when the day's data changes
    /// (a new day has different gaps); preserved across pure viewport-height rebuilds.
    private var expandedGapKeys: Set<String> = []

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

    /// Rebuilds the timeline for `events` on `date` with `theme`. New data resets any
    /// user-expanded gaps (a different day has different gaps), then refreshes the
    /// layout math, grid, labels, rest bands, and event blocks.
    func configure(events: [OccurrenceVM], date: Date, theme: CalendarTheme) {
        self.events = events
        self.date = date
        self.theme = theme
        expandedGapKeys = []
        refresh()
    }

    /// Rebuilds every derived view (layout math + grid + labels + rest bands + event
    /// blocks + now-indicator) from the current `events` / `date` / `theme` /
    /// `expandedGapKeys`. Shared by `configure` and the tap-to-expand path.
    private func refresh() {
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

    /// (Re)builds the layout math from the current inputs and the cached
    /// ``availableHeight`` + ``expandedGapKeys``. Split out so a pure viewport-height
    /// change in `layoutSubviews` can re-fill without re-creating cells.
    private func rebuildLayout() {
        guard let theme else { return }
        layout = DayTimelineLayout(
            hourHeight: theme.hourHeight,
            topPadding: theme.timelineTopPadding,
            date: date,
            events: events,
            availableHeight: availableHeight,
            now: Date(),
            expandedGapKeys: expandedGapKeys
        )
    }

    /// Marks a collapsed gap as expanded and rebuilds so it renders at real duration.
    private func expandGap(_ gapKey: String) {
        guard !expandedGapKeys.contains(gapKey) else { return }
        expandedGapKeys.insert(gapKey)
        refresh()
    }

    /// The viewport height the schedule may fill up to: the enclosing scroll view's
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

    /// Recreates the collapsed rest-band strips for the current layout, wiring each
    /// to expand its gap on tap.
    private func rebuildRestBands() {
        guard let theme else { return }
        for view in restBandViews { view.removeFromSuperview() }
        restBandViews = layout.restBands().map { band in
            let view = DayTimelineRestBandView()
            view.configure(label: band.label, theme: theme)
            view.onTap = { [weak self] in self?.expandGap(band.gapKey) }
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
        // "now" is laid out as a 2-hour active window on today, so the indicator is
        // always meaningful whenever the day is today and the stack is non-empty.
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

        // Re-fill the schedule when the viewport height changed (first real layout
        // after hosting, rotation, tab-bar show/hide) so it keeps occupying at least
        // the visible area. The slack-fill can un-collapse a gap — which CHANGES the
        // rest-band set — so the band views must be rebuilt in lockstep with the new
        // layout, otherwise a stale band view is framed at another band's position
        // and shows the wrong span. Event cells re-frame from `layout` below, so they
        // need no rebuild here.
        let latestAvailable = currentAvailableHeight()
        if abs(latestAvailable - availableHeight) > 0.5 {
            availableHeight = latestAvailable
            rebuildLayout()
            invalidateIntrinsicContentSize()
            rebuildRestBands()
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
        // leading edge (matches the design's left:8/right:8 rule).
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

/// A collapsed empty-gap "rest band": a centered mono `HH:MM – HH:MM` label with a
/// trailing `chevron.down` affordance, flanked by 1px dashed separator rules (theme
/// separator @0.7), standing in for hours the day skips. Tapping it expands the gap
/// to real duration.
final class DayTimelineRestBandView: UIView {

    /// Fired when the band is tapped — the owning view expands its gap.
    var onTap: (() -> Void)?

    private let leftRule = CAShapeLayer()
    private let rightRule = CAShapeLayer()
    private let label = UILabel()
    /// A small disclosure chevron hinting the band expands on tap.
    private let chevron = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        // The band is tappable to expand its collapsed gap.
        isUserInteractionEnabled = true
        accessibilityTraits = .button
        label.textAlignment = .center
        label.numberOfLines = 1
        addSubview(label)
        chevron.image = UIImage(
            systemName: "chevron.down",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 8, weight: .semibold)
        )
        chevron.contentMode = .center
        addSubview(chevron)
        for rule in [leftRule, rightRule] {
            rule.lineWidth = 1
            rule.lineDashPattern = [3, 3]
            rule.fillColor = UIColor.clear.cgColor
            layer.addSublayer(rule)
        }
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        onTap?()
    }

    /// Sets the collapsed-span label + theme colors.
    func configure(label text: String, theme: CalendarTheme) {
        label.text = text
        label.font = theme.codeSmall
        label.textColor = theme.textSecondary
        chevron.tintColor = theme.textSecondary
        accessibilityLabel = String(
            format: String(localized: "calendar.timeline.expandGap", defaultValue: "Expand %@"),
            text
        )
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
        // Chevron just to the right of the label.
        let chevronSize: CGFloat = 12
        chevron.frame = CGRect(
            x: label.frame.maxX + 3,
            y: centerY - chevronSize / 2,
            width: chevronSize,
            height: chevronSize
        )
        // Dashed rules flank the [label + chevron] group with an 8px gap on each side.
        let gap: CGFloat = 8
        let leftEnd = label.frame.minX - gap
        let rightStart = chevron.frame.maxX + gap
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
