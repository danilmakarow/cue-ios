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
    /// The real reason the series-detail fetch failed, surfaced verbatim in the
    /// inline notice (instead of a silent generic message) so a decode/HTTP fault
    /// is diagnosable. `nil` while loading succeeds or hasn't run. Editing is NO
    /// LONGER blocked by this — the edit screen lazy-loads the series itself.
    @State private var detailLoadError: String?

    /// Locally-synced groups, used only to resolve the owning group's display name
    /// for the header meta row (the wire DTOs carry the group's color + id but not
    /// its name).
    @Query private var groups: [EventTaskGroup]

    /// Effective completion state — local optimistic value wins over the event's.
    private var isDone: Bool { localDone ?? event.isCompleted }

    /// The event's EFFECTIVE accent — its own per-task color, else the owning
    /// group's color, else the neutral gray (`task ?? group ?? gray`). Drives the
    /// header spine, group dot, title underline tick, and every ledger leading icon
    /// (clock / repeat / notes) so the whole sheet reads by the task's real color
    /// rather than a generic clay. Done state overrides this with olive at the use
    /// site (spine / title / check).
    private var accentColor: Color {
        TaskColorResolver.effectiveColor(
            taskToken: event.colorToken,
            groupToken: event.groupColorToken
        )
    }

    /// The owning group's display name, resolved from the locally-synced groups by
    /// `event.groupId`. `nil` when the event has no group or it isn't synced yet.
    private var groupName: String? {
        guard let groupId = event.groupId else { return nil }
        return groups.first { $0.id == groupId }?.name
    }

    /// The meta-row group dot color — the GROUP's OWN color (`groupColorToken`),
    /// falling back to the neutral gray. This is deliberately NOT the effective
    /// task color: the dot identifies the group, while the effective task color
    /// (which may be a per-task override) drives the spine, underline tick, and
    /// ledger icons.
    private var groupDotColor: Color {
        TaskColorResolver.color(from: event.groupColorToken) ?? TaskColorResolver.neutral
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
                if detailLoadError != nil {
                    detailLoadFailedRow
                }
                actionsSection
            }
            .padding(.horizontal, Spacing.lg)
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
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                // Present with whatever series detail we already have (possibly
                // `nil` when the detail fetch failed). The edit screen lazy-loads
                // it itself, so Edit stays usable for recurring occurrences even
                // when THIS screen's fetch failed — see `loadSeriesDetail`.
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
                if (groupName?.isEmpty == false) || event.isRecurring {
                    HStack(spacing: Spacing.sm) {
                        if let groupName, !groupName.isEmpty {
                            HStack(spacing: Spacing.xs) {
                                Circle()
                                    .fill(groupDotColor)
                                    .frame(width: 8, height: 8)
                                Text(groupName)
                                    .cueText(.label)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                        if event.isRecurring {
                            Label("taskDetail.recurring.badge", systemImage: "repeat")
                                .cueText(.codeSmall)
                                .textCase(.uppercase)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
                // `.center` (not `.firstTextBaseline`) so the title sits vertically
                // centered against the leading done-check — the baseline alignment
                // pushed a multi-line title low relative to the recurrence mark and
                // the check glyph. Centering keeps the title optically balanced.
                HStack(alignment: .center, spacing: Spacing.sm) {
                    if isDone {
                        OliveCheck(isDone: true, size: 22)
                    }
                    Text(event.title)
                        .strikethrough(isDone, color: theme.success)
                        .cueText(.titleL)
                        .foregroundStyle(isDone ? theme.success : theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // The structural tick under the title — the effective task color
                // while active, flipping to olive (success) once done, matching the
                // done spine + title + check rather than merely dimming.
                Capsule()
                    .fill((isDone ? theme.success : accentColor).opacity(0.55))
                    .frame(width: 44, height: 2)
            }
            .opacity(isDone ? 0.7 : 1)
        }
    }

    private var timeSection: some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                // Human-friendly countdown for upcoming (and next-occurrence /
                // recurring) context — e.g. "in 18 min", "in 3 d". Kept above the
                // absolute range so the sheet reads both "when" and "how soon".
                if let relative = relativeTimeUntil {
                    Text(relative)
                        .cueText(.callout)
                        .foregroundStyle(theme.textSecondary)
                }
                Text(formattedDateRange)
                    .cueText(.code)
                    .foregroundStyle(theme.textPrimary)
            }
        } icon: {
            Image(systemName: "clock")
                .foregroundStyle(accentColor)
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
                .foregroundStyle(accentColor)
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
                .foregroundStyle(accentColor)
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
    /// Surfaces the REAL underlying error (decode / HTTP) verbatim instead of a
    /// generic message, so a fault like the recurrence decode mismatch is
    /// diagnosable rather than silent. Editing is NOT blocked by this state.
    private var detailLoadFailedRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
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
            if let detailLoadError {
                Text(detailLoadError)
                    .cueText(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

    /// Bottom action stack — Edit + Delete, BOTH outlined `.cue(.secondary)` per
    /// the brief (scope selection lives only on the Edit screen now). Recurring
    /// tasks additionally get a Skip-this-occurrence outlined button. Edit is
    /// tappable even when the series-detail fetch failed — the edit screen
    /// lazy-loads its own detail — so recurring occurrences are always editable.
    private var actionsSection: some View {
        VStack(spacing: Spacing.md) {
            if event.isRecurring {
                Button {
                    performSkip()
                } label: {
                    Label("taskDetail.skip.action", systemImage: "forward.end.fill")
                }
                .buttonStyle(.cue(.secondary))
                .disabled(isSkipping || isDeleting)
                .overlay {
                    if isSkipping {
                        ProgressView().tint(theme.primary)
                    }
                }
            }

            Button {
                isEditing = true
            } label: {
                Label("taskDetail.edit.action", systemImage: "pencil")
            }
            .buttonStyle(.cue(.secondary))
            .disabled(isDeleting || isSkipping)

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label(deleteActionLabel, systemImage: "trash")
            }
            .buttonStyle(.cue(.secondary))
            .disabled(isDeleting || isSkipping)
            .overlay {
                if isDeleting {
                    ProgressView().tint(theme.primary)
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
                        Label("taskDetail.markNotDone", systemImage: "checkmark.seal.fill")
                    }
                    .buttonStyle(.cue(.secondary))
                } else {
                    Button { toggleCompletion() } label: {
                        Label("taskDetail.markDone", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.cue(.decisivePositive))
                }
            }
            .disabled(isToggling || isDeleting)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)
        }
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

    /// Inline destructive button label — communicates scope (whole series vs a
    /// single task) the same way `deletePrimaryLabel` does for the confirm sheet.
    private var deleteActionLabel: String {
        event.isRecurring
            ? String(localized: "taskDetail.delete.series.action", defaultValue: "Delete series")
            : String(localized: "taskDetail.delete.action", defaultValue: "Delete")
    }

    private var deletePrimaryLabel: String {
        event.isRecurring
            ? String(localized: "taskDetail.delete.series.action")
            : String(localized: "taskDetail.delete.confirm.action")
    }

    /// For a recurring task the delete confirm offers a softer second branch —
    /// skip just this occurrence instead of removing the whole series. With the
    /// "Applies to" scope control gone from this screen (it belongs on Edit), the
    /// sensible default is: the primary destructive action deletes the series,
    /// and this branch is always offered as the single-occurrence alternative.
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

    /// Human-friendly countdown to this occurrence's start ("in 18 min", "in 3 d")
    /// via ``RelativeTimeFormatter``. Rendered only while the start is still in the
    /// future (or within the current minute) — a completed or already-past
    /// occurrence shows just the absolute range, since a "5 min ago" countdown adds
    /// no planning value there. For recurring tasks this reads as the next
    /// occurrence's lead time.
    private var relativeTimeUntil: String? {
        // A one-minute grace so an event that just started still reads "now"
        // rather than flipping to a past phrasing the instant it begins.
        let grace: TimeInterval = 60
        guard !isDone, event.startAt.timeIntervalSinceNow >= -grace else {
            return nil
        }
        return RelativeTimeFormatter.timeUntil(event.startAt)
    }

    // MARK: - Actions

    private func loadSeriesDetail() async {
        guard seriesDTO == nil else { return }
        isLoadingDetail = true
        detailLoadError = nil
        defer { isLoadingDetail = false }

        do {
            let dto: TaskDTO = try await APIClient.shared.get("/tasks/\(event.seriesId)")
            seriesDTO = dto
            detailLoadError = nil
        } catch {
            // Surface the REAL cause (decode / HTTP) rather than a silent generic
            // notice. The recurring-occurrence failure is a decode mismatch —
            // `RecurrenceRuleDTO.id` is required client-side but the backend's
            // inline `RecurrenceConfigDTO` (ADR 0054) no longer sends `id`, so a
            // recurring task's `recurrence` object fails `keyNotFound(.id)`.
            detailLoadError = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
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
        guard let originalStart = event.originalStart ?? event.occurrenceStart else {
            errorMessage = String(
                localized: "taskDetail.skip.unavailable",
                defaultValue: "This occurrence can't be skipped right now."
            )
            return
        }
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
