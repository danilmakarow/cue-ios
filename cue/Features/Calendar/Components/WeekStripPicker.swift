//
//  WeekStripPicker.swift
//  cue
//

import SwiftUI

/// Horizontally paged strip of day pills, grouped in 7-day "pages".
///
/// The home group is centered on today (today sits at index 3 of 7).
/// Adjacent groups are 7 days to either side. A drag carries inertia to
/// the nearest group boundary via `.scrollTargetBehavior(.paging)` —
/// the usual modern magnetic-snap feel.
///
/// Dates outside today ± 3 days show a small month abbreviation beneath
/// the weekday label so you always know which month you're scrolling
/// through.
struct WeekStripPicker: View {
    @Binding var selectedDate: Date

    /// The group (start-date) currently visible in the strip.
    @State private var visibleGroupStart: Date?

    private let calendar = Calendar.current
    private static let daysPerGroup: Int = 7
    /// Days either side of today for the paged window (±12 groups = ±84 days).
    private static let groupRange: ClosedRange<Int> = -12...12

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._visibleGroupStart = State(initialValue: Self.homeGroupStart())
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(groups) { group in
                    groupView(group)
                        .containerRelativeFrame(.horizontal)
                        .id(group.startDate)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $visibleGroupStart)
        .frame(height: 80)
        .onChange(of: selectedDate) { _, newDate in
            alignGroupIfNeeded(for: newDate)
        }
    }

    // MARK: - Groups

    private struct WeekGroup: Identifiable, Hashable {
        let startDate: Date
        let dates: [Date]
        var id: Date { startDate }
    }

    private var groups: [WeekGroup] {
        Self.groupRange.compactMap { Self.makeGroup(offset: $0) }
    }

    /// Builds the group that's `offset` groups away from the home group.
    /// The home group (offset 0) contains today at its center index.
    private static func makeGroup(offset groupIndex: Int) -> WeekGroup? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let centerDayOffset = groupIndex * daysPerGroup
        let firstDayOffset = centerDayOffset - daysPerGroup / 2
        let dates = (0..<daysPerGroup).compactMap { index in
            calendar.date(byAdding: .day, value: firstDayOffset + index, to: today)
        }
        guard let first = dates.first else { return nil }
        return WeekGroup(startDate: first, dates: dates)
    }

    private static func homeGroupStart() -> Date? {
        makeGroup(offset: 0)?.startDate
    }

    /// When the selected date is no longer in the visible group (e.g. the
    /// user paged the main schedule to a different week), scroll the strip
    /// to the group containing that date.
    private func alignGroupIfNeeded(for date: Date) {
        let targetGroup = groups.first { group in
            group.dates.contains { calendar.isDate($0, inSameDayAs: date) }
        }
        guard let targetGroup, targetGroup.startDate != visibleGroupStart else { return }
        withAnimation(.snappy) {
            visibleGroupStart = targetGroup.startDate
        }
    }

    // MARK: - Subviews

    private func groupView(_ group: WeekGroup) -> some View {
        HStack(spacing: 4) {
            ForEach(group.dates, id: \.self) { date in
                DatePill(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(date),
                    showMonthLabel: isOutsideCurrentWindow(date)
                )
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .onTapGesture {
                    withAnimation(.snappy) { selectedDate = date }
                }
            }
        }
        .padding(.horizontal, 12)
    }

    /// Days more than 3 days away from today get a month abbreviation
    /// under their weekday label.
    private func isOutsideCurrentWindow(_ date: Date) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents(
            [.day],
            from: today,
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        return abs(days) > 3
    }
}

// MARK: - DatePill

/// Single day pill inside `WeekStripPicker`. Fills the width it's given
/// so 7 pills evenly fill a paged group.
private struct DatePill: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    /// When true, show the 3-letter month abbreviation in the bottom slot.
    /// Otherwise the slot is empty (or holds a dot if this is today).
    let showMonthLabel: Bool

    private static let shortWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEEE"   // Two-letter weekday: "Mo", "Tu", …
        return formatter
    }()

    private static let shortMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"       // "Apr", "May", …
        return formatter
    }()

    private var dayNumber: String {
        date.formatted(.dateTime.day())
    }

    private var dayLabel: String {
        Self.shortWeekdayFormatter.string(from: date)
    }

    private var monthLabel: String {
        Self.shortMonthFormatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(.title3.weight(.bold))
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            Text(dayLabel)
                .font(.caption)
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            bottomSlot
                .frame(height: 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentColor.opacity(0.15))
            }
        }
    }

    /// Fixed-height row below the weekday. Renders the month abbreviation
    /// (outside current window), a today-dot, or nothing — keeping every
    /// pill the same size.
    @ViewBuilder
    private var bottomSlot: some View {
        if showMonthLabel {
            Text(monthLabel)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
        } else if isToday {
            Circle()
                .fill(.tint)
                .frame(width: 4, height: 4)
        } else {
            Color.clear
        }
    }
}

#Preview {
    @Previewable @State var date = Date()
    return WeekStripPicker(selectedDate: $date)
}
