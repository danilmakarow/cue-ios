//
//  TimelineDayPage.swift
//  cue
//

import SwiftUI

/// Timeline (hour-grid) view of a single day. Vertically scrollable,
/// pre-positioned so the current hour (on today) or 08:00 (on other days)
/// is centered when the page appears.
///
/// One of two interchangeable day-page types rendered by `CalendarView`
/// (the other is `ListDayPage`). Both accept the same inputs —
/// `(date, events, onToggleCompletion)` — so `CalendarView` can switch
/// between modes without any further plumbing.
struct TimelineDayPage: View {
    let date: Date
    let events: [ScheduleEvent]
    let onToggleCompletion: (ScheduleEvent) -> Void

    /// Per-page vertical scroll offset. Each page maintains its own so
    /// swiping horizontally back and forth preserves position.
    @State private var scrollPosition: ScrollPosition = ScrollPosition()
    /// Kept hidden (opacity 0) until the initial focus scroll lands, so
    /// users never see the unscrolled top-of-day frame.
    @State private var revealed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(scheduleHeading)
                .font(.headline)
                .padding(.horizontal, 16)

            ScrollView(.vertical, showsIndicators: false) {
                DayScheduleView(
                    date: date,
                    events: events,
                    onToggleCompletion: onToggleCompletion
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollPosition($scrollPosition)
        }
        .opacity(revealed ? 1 : 0)
        .task {
            // Allow SwiftUI to lay the ScrollView out before we ask it to
            // scroll. Without this delay, the scroll is ignored.
            try? await Task.sleep(for: .milliseconds(60))
            applyInitialScroll()
            try? await Task.sleep(for: .milliseconds(20))
            withAnimation(.easeIn(duration: 0.12)) {
                revealed = true
            }
        }
    }

    /// "Schedule Today" on today, otherwise "Schedule on <date>".
    private var scheduleHeading: String {
        if Calendar.current.isDateInToday(date) {
            return "Schedule Today"
        }
        return "Schedule on \(date.formatted(.dateTime.weekday().day().month(.abbreviated)))"
    }

    /// Centers the current hour on today, or anchors 08:00 near the top
    /// otherwise. The 500pt viewport estimate fits the iPhone 14/15/16
    /// family; off-centering on smaller/larger screens is negligible in
    /// practice.
    private func applyInitialScroll() {
        let targetCenterY: CGFloat
        if Calendar.current.isDateInToday(date) {
            targetCenterY = timelineY(for: Date())
        } else {
            targetCenterY = timelineY(forHour: 8)
        }
        let estimatedViewportHeight: CGFloat = 500
        let scrollY = max(0, targetCenterY - estimatedViewportHeight / 2)
        scrollPosition.scrollTo(y: scrollY)
    }

    private func timelineY(for date: Date) -> CGFloat {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hours = CGFloat(components.hour ?? 0) + CGFloat(components.minute ?? 0) / 60
        return hours * DayScheduleView.hourHeight + DayScheduleView.topPadding
    }

    private func timelineY(forHour hour: Int) -> CGFloat {
        CGFloat(hour) * DayScheduleView.hourHeight + DayScheduleView.topPadding
    }
}
