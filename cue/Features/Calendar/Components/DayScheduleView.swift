//
//  DayScheduleView.swift
//  cue
//

import SwiftUI

/// Hourly schedule for a single day. Events are positioned absolutely by
/// their start time and sized by duration. Overlapping events are laid
/// out side-by-side in columns so all of them remain visible.
///
/// Horizontal gray lines mark each hour (full-width, more visible) and
/// each half hour (fainter). Hour labels render on top of the hour lines.
///
/// When the selected date is today, a live current-time indicator is
/// drawn across the timeline (refreshed every minute via `TimelineView`).
struct DayScheduleView: View {
    let date: Date
    let events: [ScheduleEvent]
    /// Callback invoked when the user taps the completion checkbox on an
    /// event. Only fired for events whose `requiresCompletion` is true.
    var onToggleCompletion: (ScheduleEvent) -> Void = { _ in }

    /// Vertical points per hour. Exposed so callers can compute scroll
    /// targets in the same coordinate space as this view.
    static let hourHeight: CGFloat = 36
    /// Top padding applied to the timeline. Callers computing scroll
    /// targets should add this offset to their hour math.
    static let topPadding: CGFloat = 10

    // Layout constants
    private let startHour: Int = 0
    private let endHour: Int = 24
    private let timeColumnWidth: CGFloat = 44
    private let gutter: CGFloat = 8

    private let calendar = Calendar.current

    private var hourHeight: CGFloat { Self.hourHeight }
    private var topPadding: CGFloat { Self.topPadding }
    private var totalHours: Int { endHour - startHour }
    private var totalHeight: CGFloat { CGFloat(totalHours) * hourHeight }

    /// Computed once per `events` change — assigns each event a column
    /// within its overlap cluster.
    private var layouts: [EventLayout] { Self.layout(events: events) }

    var body: some View {
        HStack(alignment: .top, spacing: gutter) {
            timeLabelColumn
                .frame(width: timeColumnWidth)
            eventsColumn
                .frame(maxWidth: .infinity)
        }
        .frame(height: totalHeight)
        .background(alignment: .topLeading) { hourGridLines }
        .padding(.top, topPadding)
        .overlay(alignment: .topLeading) {
            if calendar.isDateInToday(date) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    currentTimeIndicator(now: context.date)
                        .offset(y: topPadding)
                }
            }
        }
    }

    // MARK: - Grid lines

    /// Solid hour lines spanning the full width of the timeline (both the
    /// time-label column and the events column). Hour labels render just
    /// above each line so the line sits under the text, not through it.
    private var hourGridLines: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0...totalHours, id: \.self) { offset in
                Rectangle()
                    .fill(Color.secondary.opacity(0.22))
                    .frame(height: 0.5)
                    .offset(y: CGFloat(offset) * hourHeight)
            }
        }
    }

    /// Half-hour lines — only inside the events column. Fainter than hour
    /// lines; used as secondary tick marks for estimating times between
    /// hour marks.
    private var halfHourGridLines: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<totalHours, id: \.self) { offset in
                Rectangle()
                    .fill(Color.secondary.opacity(0.10))
                    .frame(height: 0.5)
                    .offset(y: CGFloat(offset) * hourHeight + hourHeight / 2)
            }
        }
    }

    // MARK: - Columns

    private var timeLabelColumn: some View {
        ZStack(alignment: .topLeading) {
            Color.clear.frame(height: totalHeight)

            ForEach(Array(stride(from: startHour, through: endHour, by: 2)), id: \.self) { hour in
                Text(String(format: "%02d.00", hour))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Position text just above the hour line (sits on top
                    // of it) rather than centered on it (bisected by it).
                    .offset(y: CGFloat(hour - startHour) * hourHeight - 15)
            }
        }
    }

    private var eventsColumn: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            ZStack(alignment: .topLeading) {
                Color.clear.frame(height: totalHeight)
                halfHourGridLines
                eventLayer(totalWidth: totalWidth)
            }
        }
        .frame(height: totalHeight)
    }

    @ViewBuilder
    private func eventLayer(totalWidth: CGFloat) -> some View {
        ForEach(layouts) { layout in
            let columnWidth = totalWidth / CGFloat(layout.columnCount)
            eventCard(layout.event)
                .frame(
                    width: max(columnWidth - 2, 0),
                    height: max(heightFor(layout.event), 28),
                    alignment: .topLeading
                )
                .offset(
                    x: CGFloat(layout.column) * columnWidth,
                    y: offsetY(layout.event.startAt)
                )
        }
    }

    // MARK: - Subviews

    private func eventCard(_ event: ScheduleEvent) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.tint)
            .overlay(alignment: .topLeading) {
                HStack(alignment: .top, spacing: 8) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .strikethrough(event.isCompleted, color: .white)
                    Spacer(minLength: 0)
                    if event.requiresCompletion {
                        completionToggle(for: event)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .opacity(event.isCompleted ? 0.45 : 1.0)
            .animation(.snappy, value: event.isCompleted)
    }

    /// Circle checkbox rendered on the right of a task card. Fires the
    /// parent's `onToggleCompletion` callback; no local state — the
    /// parent owns the events list.
    private func completionToggle(for event: ScheduleEvent) -> some View {
        Button {
            onToggleCompletion(event)
        } label: {
            Image(systemName: event.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(event.isCompleted ? LocalizedStringKey("task.toggle.markNotDone") : LocalizedStringKey("task.toggle.markDone"))
    }

    private func currentTimeIndicator(now: Date) -> some View {
        let y = offsetY(now)
        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(.red)
                .frame(height: 1.5)
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .offset(x: timeColumnWidth - 4)
        }
        .offset(y: y - 0.75)
        .allowsHitTesting(false)
    }

    // MARK: - Time math

    /// Returns the vertical offset (in points, from the top of the timeline)
    /// that corresponds to the hour-of-day in `date`.
    private func offsetY(_ date: Date) -> CGFloat {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hours = CGFloat(components.hour ?? 0) + CGFloat(components.minute ?? 0) / 60
        return max((hours - CGFloat(startHour)) * hourHeight, 0)
    }

    /// Visual height of the event block based on its duration.
    private func heightFor(_ event: ScheduleEvent) -> CGFloat {
        offsetY(event.endAt) - offsetY(event.startAt)
    }

    // MARK: - Overlap layout

    /// Positioning metadata for a single event: which column it occupies
    /// within its overlap cluster, and how many columns the cluster has.
    private struct EventLayout: Identifiable {
        let event: ScheduleEvent
        let column: Int
        let columnCount: Int
        var id: String { event.id }
    }

    /// Assigns each event a `(column, columnCount)` so overlapping events
    /// render side-by-side. Non-overlapping clusters are laid out
    /// independently, so a single event always spans the full width.
    private static func layout(events: [ScheduleEvent]) -> [EventLayout] {
        let sorted = events.sorted { $0.startAt < $1.startAt }
        var result: [EventLayout] = []
        var cluster: [ScheduleEvent] = []
        var clusterEnd: Date = .distantPast

        func flushCluster() {
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
                    result.append(EventLayout(event: event, column: column, columnCount: total))
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
                flushCluster()
                cluster.append(event)
                clusterEnd = event.endAt
            }
        }
        flushCluster()
        return result
    }
}

#Preview {
    let today = Calendar.current.startOfDay(for: Date())
    let cal = Calendar.current
    let events: [ScheduleEvent] = [
        ScheduleEvent(
            id: UUID().uuidString,
            title: "Team sync",
            startAt: cal.date(bySettingHour: 9, minute: 0, second: 0, of: today) ?? today,
            endAt: cal.date(bySettingHour: 10, minute: 0, second: 0, of: today) ?? today,
            requiresCompletion: true
        ),
        ScheduleEvent(
            id: UUID().uuidString,
            title: "1:1 with manager",
            startAt: cal.date(bySettingHour: 9, minute: 30, second: 0, of: today) ?? today,
            endAt: cal.date(bySettingHour: 10, minute: 30, second: 0, of: today) ?? today,
            requiresCompletion: true,
            completedAt: Date()
        ),
        ScheduleEvent(
            id: UUID().uuidString,
            title: "Deep work",
            startAt: cal.date(bySettingHour: 11, minute: 0, second: 0, of: today) ?? today,
            endAt: cal.date(bySettingHour: 13, minute: 0, second: 0, of: today) ?? today
        ),
    ]
    return ScrollView {
        DayScheduleView(date: today, events: events)
            .padding(.horizontal)
    }
}
