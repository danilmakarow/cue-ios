//
//  ListDayPage.swift
//  cue
//

import SwiftUI

/// TODO-list view of a single day. Renders events as stacked cards with
/// title, time, optional notes and (for tasks) a completion checkbox.
///
/// One of two interchangeable day-page types rendered by `CalendarView`
/// (the other is `TimelineDayPage`). Both accept the same inputs —
/// `(date, events, onToggleCompletion)` — so `CalendarView` can switch
/// between modes without any further plumbing.
struct ListDayPage: View {
    let date: Date
    let events: [ScheduleEvent]
    let onToggleCompletion: (ScheduleEvent) -> Void
    /// Called when the user taps an event card body (not the completion checkbox).
    var onSelect: (ScheduleEvent) -> Void = { _ in }

    /// Events sorted by start time. Incomplete tasks stay in chronological
    /// order; completed ones sink to the bottom so the TODO feels like a
    /// real list.
    private var sortedEvents: [ScheduleEvent] {
        events.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted
            }
            return lhs.startAt < rhs.startAt
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(heading)
                .font(.headline)
                .padding(.horizontal, 16)

            if events.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(sortedEvents) { event in
                            EventListCard(event: event, onToggle: onToggleCompletion, onSelect: onSelect)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .animation(.snappy, value: sortedEvents)
                }
            }
        }
    }

    /// "Today's Tasks" on today, otherwise "Tasks on <date>". Localized; the
    /// date itself is formatted locale-aware by `FormatStyle`.
    private var heading: String {
        if Calendar.current.isDateInToday(date) {
            return String(localized: "calendar.list.heading.today")
        }
        let formattedDate = date.formatted(.dateTime.weekday().day().month(.abbreviated))
        return String(format: String(localized: "calendar.list.heading.other"), formattedDate)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "calendar.list.empty.title",
            systemImage: "checkmark.circle",
            description: Text("calendar.list.empty.description")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - EventListCard

/// Single event rendered as a list card. Private to `ListDayPage` — it's
/// not reused elsewhere.
private struct EventListCard: View {
    let event: ScheduleEvent
    let onToggle: (ScheduleEvent) -> Void
    var onSelect: (ScheduleEvent) -> Void = { _ in }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            accentStripe

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .strikethrough(event.isCompleted)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(timeString)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                if let notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onSelect(event) }

            Spacer(minLength: 0)

            if event.requiresCompletion {
                completionToggle
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.12))
        }
        .opacity(event.isCompleted ? 0.55 : 1.0)
        .animation(.snappy, value: event.isCompleted)
    }

    /// Narrow colored bar at the leading edge — brands the card with the
    /// app accent without washing out the readable neutral background.
    private var accentStripe: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(.tint)
            .frame(width: 4)
            .frame(maxHeight: .infinity)
    }

    /// Localized accessibility label for the completion checkbox.
    private var toggleAccessibilityLabel: LocalizedStringKey {
        event.isCompleted ? "task.toggle.markNotDone" : "task.toggle.markDone"
    }

    private var completionToggle: some View {
        Button {
            onToggle(event)
        } label: {
            Image(systemName: event.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(
                    event.isCompleted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(toggleAccessibilityLabel)
    }

    /// Formatted time range (e.g. "9:00 – 10:30"), localized.
    private var timeString: String {
        let start = event.startAt.formatted(date: .omitted, time: .shortened)
        let end = event.endAt.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}

#Preview {
    let today = Calendar.current.startOfDay(for: Date())
    let cal = Calendar.current
    let events: [ScheduleEvent] = [
        ScheduleEvent(
            id: "key1", seriesId: UUID().uuidString,
            title: "Team sync",
            notes: "Discuss Q2 roadmap priorities and unblock data-layer work.",
            startAt: cal.date(bySettingHour: 9, minute: 0, second: 0, of: today) ?? today,
            endAt: cal.date(bySettingHour: 10, minute: 0, second: 0, of: today) ?? today,
            requiresCompletion: true
        ),
        ScheduleEvent(
            id: "key2", seriesId: UUID().uuidString,
            title: "1:1 with manager",
            notes: nil,
            startAt: cal.date(bySettingHour: 14, minute: 0, second: 0, of: today) ?? today,
            endAt: cal.date(bySettingHour: 14, minute: 30, second: 0, of: today) ?? today,
            requiresCompletion: true,
            completedAt: Date()
        ),
        ScheduleEvent(
            id: "key3", seriesId: UUID().uuidString,
            title: "Gym",
            startAt: cal.date(bySettingHour: 18, minute: 0, second: 0, of: today) ?? today,
            endAt: cal.date(bySettingHour: 19, minute: 0, second: 0, of: today) ?? today
        ),
    ]
    ListDayPage(date: today, events: events, onToggleCompletion: { _ in }, onSelect: { _ in })
}
