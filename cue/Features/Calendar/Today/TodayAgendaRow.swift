//
//  TodayAgendaRow.swift
//  cue
//

import SwiftUI

/// One agenda row in the Today screen — the SwiftUI render of `Today.dc.html`'s
/// "up next" / "this evening" cards: a leading time (or "all-day"), a GROUP-colored
/// rail, the task title (strikethrough + faded when done), an optional recurring
/// glyph, and — for tasks — the ``OliveCheck`` done marker.
///
/// Completing a task plays the ``RootsCommitView`` `.done` (CLAY) commit motion in
/// place of the check for a beat, then settles to the olive check — the heavier
/// "this is finished" signature reserved for the deliberate tap, while the quiet
/// olive dot carries the resting done state.
struct TodayAgendaRow: View {
    @Environment(\.theme) private var theme

    let occurrence: OccurrenceVM
    /// Fires when the done marker is tapped (tasks only). The host routes it to
    /// `CalendarStore.toggleCompletion`.
    let onToggle: () -> Void

    /// Bumped on each local completion tap to replay the commit motion from frame 0.
    @State private var commitTrigger = 0

    var body: some View {
        HStack(spacing: Spacing.md) {
            timeColumn
                .frame(width: 60, alignment: .trailing)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(railColor)
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            Text(occurrence.title)
                .cueText(.body)
                .foregroundStyle(occurrence.isCompleted ? theme.textSecondary : theme.textPrimary)
                .strikethrough(occurrence.isCompleted, color: theme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if occurrence.isRecurring {
                Image(systemName: "repeat")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.accentText)
                    .accessibilityHidden(true)
            }

            if occurrence.requiresCompletion {
                doneControl
            }
        }
        .frame(minHeight: 44)
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.lg)
        .opacity(occurrence.isCompleted ? 0.62 : 1)
    }

    // MARK: - Time

    @ViewBuilder
    private var timeColumn: some View {
        Text(timeText)
            .cueText(.code)
            .foregroundStyle(theme.textSecondary)
            .lineLimit(1)
    }

    /// The leading time stamp — the start time, or the "all-day" label when the
    /// occurrence spans the whole day and has no meaningful intra-day placement.
    private var timeText: String {
        if occurrence.isAllDay {
            return String(localized: "newEvent.allDay")
        }
        return occurrence.startAt.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Done control (OliveCheck + commit motion)

    @ViewBuilder
    private var doneControl: some View {
        Button {
            commitTrigger += 1
            onToggle()
        } label: {
            ZStack {
                OliveCheck(isDone: occurrence.isCompleted, size: 24)
                // The CLAY commit signature fires for a beat on each tap, over the
                // settling olive check.
                if occurrence.isCompleted {
                    RootsCommitView(tone: .done, trigger: commitTrigger)
                        .frame(width: 30, height: 30)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: 30, height: 30)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            occurrence.isCompleted
                ? "task.toggle.markNotDone"
                : "task.toggle.markDone"
        )
    }

    // MARK: - Color

    /// The rail color: the resolved GROUP color, olive once done, else clay.
    private var railColor: Color {
        if occurrence.isCompleted { return theme.success }
        return TaskColorResolver.color(from: occurrence.groupColorToken) ?? theme.primary
    }
}
