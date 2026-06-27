//
//  TaskDetailScreen.swift
//  cue
//

import SwiftData
import SwiftUI

/// Full-detail screen for a task occurrence. Pushed from the day views when the
/// user taps an event card (not the completion checkbox).
///
/// Displays all occurrence fields (incl. attached reminders), allows editing the
/// full series via `PATCH /tasks/:id`, completing the occurrence (the CLAY
/// roots-commit "done" moment), deleting the series via `DELETE /tasks/:id`, and
/// skipping this specific occurrence via `POST /tasks/:id/skip` (recurring only).
struct TaskDetailScreen: View {
    let event: ScheduleEvent

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(CalendarStore.self) private var store

    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var isSkipping = false
    @State private var isToggling = false
    @State private var errorMessage: String?
    @State private var seriesDTO: TaskDTO?
    @State private var isLoadingDetail = false
    /// Local optimistic completion mirror so the header + CTA update instantly
    /// while the store round-trips. `nil` falls back to `event.isCompleted`.
    @State private var localDone: Bool?
    /// Bumped on a successful completion to fire the CLAY roots-commit motion.
    @State private var commitTrigger = 0
    /// True when the series-detail fetch failed. Editing is blocked in this state
    /// so a failed load can't make the form read recurrence as "off" and then
    /// clear an existing rule on save.
    @State private var detailLoadFailed = false

    /// Locally-synced groups, used only to resolve the owning group's display name
    /// for the header meta row (the wire DTOs carry the group's color + id but not
    /// its name).
    @Query private var groups: [EventTaskGroup]

    /// Effective completion state — local optimistic value wins over the event's.
    private var isDone: Bool { localDone ?? event.isCompleted }

    /// The event's GROUP-resolved accent (clay fallback when ungrouped/uncolored).
    /// Drives the header accent bar, group dot, and the title underline so every
    /// event reads by its group identity rather than the generic clay.
    private var accentColor: Color {
        TaskColorResolver.color(from: event.groupColorToken) ?? theme.primary
    }

    /// The owning group's display name, resolved from the locally-synced groups by
    /// `event.groupId`. `nil` when the event has no group or it isn't synced yet.
    private var groupName: String? {
        guard let groupId = event.groupId else { return nil }
        return groups.first { $0.id == groupId }?.name
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                headerSection
                timeSection
                if event.isRecurring {
                    recurrenceSection
                }
                if let notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !notes.isEmpty {
                    notesSection(notes: notes)
                }
                if let reminders = seriesDTO?.reminders, !reminders.isEmpty {
                    remindersSection(reminders: reminders)
                }
                if detailLoadFailed {
                    detailLoadFailedRow
                }
                actionsSection
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.huge)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(String(localized: "taskDetail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            primaryCTA
        }
        .overlay {
            // Fires once per completion (CLAY done motion); never on mount.
            if commitTrigger > 0 {
                RootsCommitView(tone: .done, trigger: commitTrigger)
                    .frame(width: 96, height: 96)
                    .allowsHitTesting(false)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                editButton
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                if let seriesDTO {
                    TaskEditScreen(
                        event: event,
                        seriesDTO: seriesDTO
                    ) { _ in
                        isEditing = false
                        Task {
                            await store.invalidateAndResync(
                                around: event.startAt,
                                context: modelContext
                            )
                        }
                    }
                }
            }
        }
        .confirmActionSheet(
            isPresented: $showDeleteConfirm,
            title: deleteConfirmTitle,
            message: deleteConfirmMessage,
            primary: ConfirmAction(deletePrimaryLabel) { performDelete() },
            secondary: deleteSecondaryAction
        )
        .alert(
            "taskDetail.error.title",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .disabled(isDeleting)
        .task {
            await loadSeriesDetail()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(isDone ? theme.success : accentColor)
                .frame(width: 4)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let groupName, !groupName.isEmpty {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 8, height: 8)
                        Text(groupName)
                            .cueText(.label)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                if event.isRecurring {
                    Label("taskDetail.recurring.badge", systemImage: "repeat")
                        .cueText(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    if isDone {
                        OliveCheck(isDone: true, size: 22)
                    }
                    Text(event.title)
                        .strikethrough(isDone, color: theme.success)
                        .cueText(.titleL)
                        .foregroundStyle(isDone ? theme.success : theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Capsule()
                    .fill(accentColor.opacity(0.55))
                    .frame(width: 44, height: 2)
            }
            .opacity(isDone ? 0.7 : 1)
        }
    }

    private var timeSection: some View {
        Label {
            Text(formattedDateRange)
                .cueText(.code)
                .foregroundStyle(theme.textPrimary)
        } icon: {
            Image(systemName: "clock")
                .foregroundStyle(theme.primary)
        }
    }

    private func notesSection(notes: String) -> some View {
        Label {
            Text(notes)
                .cueText(.body)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "note.text")
                .foregroundStyle(theme.primary)
        }
    }

    private var recurrenceSection: some View {
        Label {
            if let rule = seriesDTO?.recurrence {
                Text(rule.humanSummary)
                    .cueText(.callout)
                    .foregroundStyle(theme.textSecondary)
            } else if isLoadingDetail {
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.primary)
            } else {
                Text("taskDetail.recurrence.unknown")
                    .cueText(.callout)
                    .foregroundStyle(theme.textSecondary)
            }
        } icon: {
            Image(systemName: "repeat")
                .foregroundStyle(theme.primary)
        }
    }

    /// Lists the task's attached reminders (offset + channel), earliest first.
    private func remindersSection(reminders: [ReminderDTO]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("taskDetail.reminders.header", systemImage: "bell")
                .cueText(.label)
                .foregroundStyle(theme.textSecondary)
            ForEach(reminders, id: \.id) { reminder in
                HStack(spacing: Spacing.sm) {
                    Text(ReminderOffset.nearest(to: reminder.offsetMinutes).label)
                        .cueText(.code)
                        .foregroundStyle(theme.textPrimary)
                    Spacer(minLength: 0)
                    CueChip(reminder.channel.reminderLabel, isSelected: false) {}
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.leading, Spacing.xl)
    }

    /// Inline, non-blocking notice shown when the series detail failed to load.
    private var detailLoadFailedRow: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(theme.warning)
            Text("taskDetail.detailLoad.failed")
                .cueText(.callout)
                .foregroundStyle(theme.textPrimary)
            Spacer(minLength: 0)
            Button(String(localized: "taskDetail.detailLoad.retry")) {
                Task { await loadSeriesDetail() }
            }
            .cueText(.label)
            .foregroundStyle(theme.accentText)
            .disabled(isLoadingDetail)
        }
        .padding(Spacing.md)
        .background(
            theme.warning.opacity(0.12),
            in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .strokeBorder(theme.warning.opacity(0.4), lineWidth: 1)
        )
    }

    /// Secondary actions — skip (recurring) + delete. The delete fork (series vs
    /// occurrence) is surfaced via the ConfirmActionSheet.
    private var actionsSection: some View {
        VStack(spacing: Spacing.md) {
            if event.isRecurring {
                Button {
                    performSkip()
                } label: {
                    Label("taskDetail.skip.action", systemImage: "forward.fill")
                }
                .buttonStyle(.cue(.secondary))
                .disabled(isSkipping || isDeleting)
                .overlay {
                    if isSkipping {
                        ProgressView().tint(theme.primary)
                    }
                }
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("taskDetail.delete.action", systemImage: "trash")
            }
            .buttonStyle(.cue(.destructive))
            .disabled(isDeleting || isSkipping)
            .overlay {
                if isDeleting {
                    ProgressView().tint(theme.onAccent)
                }
            }
        }
    }

    /// Pinned bottom CTA — the completion fork. A task that requires completion
    /// shows Mark done (decisive clay) / Mark not done; a pure event shows nothing.
    @ViewBuilder
    private var primaryCTA: some View {
        if event.requiresCompletion {
            Group {
                if isDone {
                    Button { toggleCompletion() } label: {
                        Label("taskDetail.markNotDone", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.cue(.secondary))
                } else {
                    Button { toggleCompletion() } label: {
                        Label("taskDetail.markDone", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.cue(.decisive))
                }
            }
            .disabled(isToggling || isDeleting)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)
        }
    }

    private var editButton: some View {
        Button(String(localized: "taskDetail.edit.action")) {
            isEditing = true
        }
        .disabled(isDeleting || isSkipping || isLoadingDetail || seriesDTO == nil)
    }

    // MARK: - Delete confirmation copy

    private var deleteConfirmTitle: String {
        event.isRecurring
            ? String(localized: "taskDetail.delete.confirm.series.title")
            : String(localized: "taskDetail.delete.confirm.title")
    }

    private var deleteConfirmMessage: String? {
        event.isRecurring
            ? String(localized: "taskDetail.delete.confirm.series.message")
            : String(localized: "taskDetail.delete.confirm.message")
    }

    private var deletePrimaryLabel: String {
        event.isRecurring
            ? String(localized: "taskDetail.delete.series.action")
            : String(localized: "taskDetail.delete.confirm.action")
    }

    /// For recurring tasks, the confirm sheet offers a second branch: skip just
    /// this occurrence instead of deleting the whole series.
    private var deleteSecondaryAction: ConfirmAction? {
        guard event.isRecurring else { return nil }
        return ConfirmAction(String(localized: "taskDetail.delete.occurrence.action"), isDestructive: false) {
            performSkip()
        }
    }

    // MARK: - Formatting

    private var formattedDateRange: String {
        let start = event.startAt.formatted(.dateTime.weekday().day().month(.abbreviated).hour().minute())
        let end = event.endAt.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    // MARK: - Actions

    private func loadSeriesDetail() async {
        guard seriesDTO == nil else { return }
        isLoadingDetail = true
        detailLoadFailed = false
        defer { isLoadingDetail = false }

        do {
            let dto: TaskDTO = try await APIClient.shared.get("/tasks/\(event.seriesId)")
            seriesDTO = dto
            detailLoadFailed = false
        } catch {
            detailLoadFailed = true
        }
    }

    /// Toggles completion through the store, mirroring the result locally and
    /// firing the CLAY roots-commit motion when transitioning to done. On a
    /// store-side failure (which rolls back its own `completedAt` and posts an
    /// error banner) the local mirror + commit motion are reverted so the header
    /// doesn't diverge from the rolled-back store value.
    private func toggleCompletion() {
        guard !isToggling else { return }
        let previous = localDone
        let willComplete = !isDone
        isToggling = true
        localDone = willComplete
        if willComplete { commitTrigger += 1 }
        Task {
            let succeeded = await store.toggleCompletion(occurrenceKey: event.id, context: modelContext)
            if !succeeded {
                localDone = previous
                if willComplete { commitTrigger -= 1 }
            }
            isToggling = false
        }
    }

    private func performDelete() {
        isDeleting = true
        Task {
            do {
                try await store.deleteTask(
                    seriesId: event.seriesId,
                    around: event.startAt,
                    context: modelContext
                )
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
            isDeleting = false
        }
    }

    private func performSkip() {
        let displayStart = event.occurrenceStart ?? event.startAt
        guard let originalStart = event.originalStart ?? event.occurrenceStart else { return }
        isSkipping = true
        Task {
            do {
                try await store.skipOccurrence(
                    seriesId: event.seriesId,
                    originalStart: originalStart,
                    displayStart: displayStart,
                    context: modelContext
                )
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
            isSkipping = false
        }
    }
}

// MARK: - Recurrence summary helper

private extension RecurrenceRuleDTO {
    /// Human-readable summary, e.g. "Every 2 weeks on Mon, Wed".
    var humanSummary: String {
        RecurrenceRuleInput(
            frequency: frequency,
            interval: interval,
            byWeekday: byWeekday,
            byMonthDay: byMonthDay,
            byMonth: byMonth,
            bySetPos: bySetPos,
            monthlyAnchor: monthlyAnchor,
            endType: endType,
            endDate: endDate,
            count: count
        ).humanSummary
    }
}
