//
//  DayTimelineLayout.swift
//  cue
//

import UIKit

/// Pure timeline geometry for a single day, reproducing the SwiftUI
/// `DayScheduleView`'s math: a 0–24 hour grid at `hourHeight` (36) points per
/// hour with a `timelineTopPadding` (10) offset, hour rules + labels, and event
/// blocks positioned by start/end time with overlapping events split into
/// side-by-side columns.
///
/// This is *only* the math + frame computation — no view ownership — so the
/// owning ``DayTimelineDayView`` (and its tests) can position cells without
/// re-deriving the rules. Hours, offsets, and overlap columns are computed
/// exactly as the old SwiftUI view did, so the visual result is byte-identical.
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
    /// Minimum height of an event block, so very short events stay tappable.
    static let minimumEventHeight: CGFloat = 28
    /// Horizontal inset shaved off each overlap column's width (matches the
    /// SwiftUI `columnWidth - 2`).
    static let columnInset: CGFloat = 2

    private let hourHeight: CGFloat
    private let topPadding: CGFloat
    private let calendar = Calendar.current

    /// - Parameters:
    ///   - hourHeight: vertical points per hour (theme `hourHeight`, 36).
    ///   - topPadding: top inset before hour 0 (theme `timelineTopPadding`, 10).
    init(hourHeight: CGFloat, topPadding: CGFloat) {
        self.hourHeight = hourHeight
        self.topPadding = topPadding
    }

    // MARK: - Derived metrics

    /// Number of hour rows (24).
    var totalHours: Int { Self.endHour - Self.startHour }

    /// Height of the hour grid itself (excludes `topPadding`).
    var gridHeight: CGFloat { CGFloat(totalHours) * hourHeight }

    /// Total content height including the top padding — the timeline view's
    /// intrinsic height.
    var contentHeight: CGFloat { gridHeight + topPadding }

    /// The y-position (within the content, including `topPadding`) of the hour
    /// line at `hour` (0...24).
    func yForHourLine(_ hour: Int) -> CGFloat {
        topPadding + CGFloat(hour - Self.startHour) * hourHeight
    }

    /// The y-position (including `topPadding`) for an arbitrary moment `date`,
    /// used for event placement and the now-indicator. Clamped at 0.
    func y(for date: Date) -> CGFloat {
        topPadding + offsetWithinGrid(for: date)
    }

    /// The hours-since-midnight offset *within the grid* (excludes padding),
    /// matching `DayScheduleView.offsetY`.
    private func offsetWithinGrid(for date: Date) -> CGFloat {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hours = CGFloat(components.hour ?? 0) + CGFloat(components.minute ?? 0) / 60
        return max((hours - CGFloat(Self.startHour)) * hourHeight, 0)
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
    /// coordinate space (origin at the events column's top-left, i.e. already
    /// offset past the time column by the caller).
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
/// half-hour ticks, two-hourly time labels, absolutely-positioned event blocks
/// (``DayTimelineEventCell``), and a clay now-indicator on today (refreshed each
/// minute). This is the UIKit body of `DayScheduleView`; it owns no data, taking
/// events + theme through ``configure(events:date:theme:)`` and forwarding the
/// two cell intents through `onToggle` / `onSelect`.
final class DayTimelineDayView: UIView {

    // MARK: - Intents (forwarded from cells)

    var onToggle: ((OccurrenceVM) -> Void)?
    var onSelect: ((OccurrenceVM) -> Void)?

    // MARK: - Geometry

    /// The layout math. Rebuilt when the theme's hour metrics change.
    private(set) var layout = DayTimelineLayout(hourHeight: 36, topPadding: 10)

    private var events: [OccurrenceVM] = []
    private var date = Date()
    private var theme: CalendarTheme?

    private var eventCells: [DayTimelineEventCell] = []
    private var hourLineLayers: [CALayer] = []
    private var halfHourLineLayers: [CALayer] = []
    private var hourLabels: [UILabel] = []
    private let nowLine = UIView()
    private let nowDot = UIView()
    private var nowTimer: Timer?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        nowLine.isUserInteractionEnabled = false
        nowDot.isUserInteractionEnabled = false
        nowDot.layer.cornerRadius = 4
        addSubview(nowLine)
        addSubview(nowDot)
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
        CGSize(width: UIView.noIntrinsicMetric, height: layout.contentHeight)
    }

    // MARK: - Configuration

    /// Rebuilds the timeline for `events` on `date` with `theme`. Rebuilds the
    /// layout math from the theme's hour metrics, refreshes the grid + labels,
    /// and rebuilds the event blocks.
    func configure(events: [OccurrenceVM], date: Date, theme: CalendarTheme) {
        self.events = events
        self.date = date
        self.theme = theme
        layout = DayTimelineLayout(hourHeight: theme.hourHeight, topPadding: theme.timelineTopPadding)
        invalidateIntrinsicContentSize()
        rebuildGrid()
        rebuildLabels()
        rebuildEventCells()
        updateNowIndicator()
        startNowTimerIfNeeded()
        setNeedsLayout()
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

    /// Builds the two-hourly time labels (00.00, 02.00, …) once and re-styles them.
    private func rebuildLabels() {
        guard let theme else { return }
        if hourLabels.isEmpty {
            for hour in stride(from: DayTimelineLayout.startHour, through: DayTimelineLayout.endHour, by: 2) {
                let label = UILabel()
                label.text = String(format: "%02d.00", hour)
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
            nowLine.isHidden = true
            nowDot.isHidden = true
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

    private func updateNowIndicator() {
        guard let theme, layout.isToday(date) else {
            nowLine.isHidden = true
            nowDot.isHidden = true
            return
        }
        nowLine.isHidden = false
        nowDot.isHidden = false
        nowLine.backgroundColor = theme.secondary
        nowDot.backgroundColor = theme.secondary
        setNeedsLayout()
    }

    // MARK: - Layout pass

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        guard width > 0 else { return }

        let eventsColumnX = DayTimelineLayout.timeColumnWidth + DayTimelineLayout.gutter
        let eventsColumnWidth = max(width - eventsColumnX, 0)

        // Hour lines span the full width; half-hour ticks only the events column.
        for (index, lineLayer) in hourLineLayers.enumerated() {
            let yPosition = layout.yForHourLine(index)
            lineLayer.frame = CGRect(x: 0, y: yPosition, width: width, height: 0.5)
        }
        let halfHourOffset = (theme?.hourHeight ?? layout.gridHeight / CGFloat(max(layout.totalHours, 1))) / 2
        for (index, lineLayer) in halfHourLineLayers.enumerated() {
            let yPosition = layout.yForHourLine(index) + halfHourOffset
            lineLayer.frame = CGRect(
                x: eventsColumnX, y: yPosition, width: eventsColumnWidth, height: 0.5
            )
        }

        // Hour labels sit just above their hour line, left-aligned in the gutter.
        for (index, label) in hourLabels.enumerated() {
            let hour = DayTimelineLayout.startHour + index * 2
            label.sizeToFit()
            let yPosition = layout.yForHourLine(hour) - label.bounds.height / 2 - 4
            label.frame = CGRect(
                x: 0, y: yPosition,
                width: DayTimelineLayout.timeColumnWidth, height: label.bounds.height
            )
        }

        // Event blocks, offset into the events column.
        let positioned = layout.positionedEvents(events, eventsColumnWidth: eventsColumnWidth)
        for (cell, placement) in zip(eventCells, positionedByID(positioned)) {
            var frame = placement.frame
            frame.origin.x += eventsColumnX
            cell.frame = frame
        }

        // Now indicator across the full width on today.
        if !nowLine.isHidden {
            let yPosition = layout.nowIndicatorY(Date())
            nowLine.frame = CGRect(x: 0, y: yPosition - 0.75, width: width, height: 1.5)
            nowDot.frame = CGRect(
                x: DayTimelineLayout.timeColumnWidth - 4, y: yPosition - 4, width: 8, height: 8
            )
        }
    }

    /// Reorders the positioned events to match `eventCells` order (cells were
    /// created in `events` order; positioning sorts internally), so zip aligns.
    private func positionedByID(_ positioned: [DayTimelineLayout.PositionedEvent]) -> [DayTimelineLayout.PositionedEvent] {
        let byID = Dictionary(uniqueKeysWithValues: positioned.map { ($0.id, $0) })
        return events.compactMap { byID[$0.id] }
    }
}
