//
//  TaskDetailScreen.swift
//  cue
//

import SwiftData
import SwiftUI

/// Full-detail screen for a task occurrence. Pushed from the day views when the
/// user taps an event card (not the completion checkbox).
///
/// Displays all occurrence fields, allows editing the full series via
/// `PATCH /tasks/:id`, deleting the series via `DELETE /tasks/:id`, and skipping
/// this specific occurrence via `POST /tasks/:id/skip` (recurring only).
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
    @State private var errorMessage: String?
    @State private var seriesDTO: TaskDTO?
    @State private var isLoadingDetail = false
    /// True when the series-detail fetch failed. Editing is blocked in this state
    /// so a failed load can't make the form read recurrence as "off" and then
    /// clear an existing rule on save.
    @State private var detailLoadFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                headerSection
                timeSection
                if let notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !notes.isEmpty {
                    notesSection(notes: notes)
                }
                if event.isRecurring {
                    recurrenceSection
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
                        // After a successful edit, refresh the affected month(s).
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
        .confirmationDialog(
            String(localized: "taskDetail.delete.confirm.title"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "taskDetail.delete.confirm.action"), role: .destructive) {
                performDelete()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text("taskDetail.delete.confirm.message")
        }
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
        .task {
            await loadSeriesDetail()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(event.title)
                .cueText(.titleL)
                .foregroundStyle(theme.textPrimary)
            Capsule()
                .fill(theme.secondary)
                .frame(width: 44, height: 2)
            if event.isRecurring {
                Label("taskDetail.recurring.badge", systemImage: "repeat")
                    .cueText(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label {
                Text(formattedDateRange)
                    .cueText(.code)
                    .foregroundStyle(theme.textSecondary)
            } icon: {
                Image(systemName: "clock")
                    .foregroundStyle(theme.primary)
            }
        }
    }

    private func notesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label {
                Text(notes)
                    .cueText(.body)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "note.text")
                    .foregroundStyle(theme.primary)
            }
        }
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
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
    }

    /// Inline, non-blocking notice shown when the series detail failed to load.
    /// Editing is disabled in this state (see `editButton`); Retry re-attempts the
    /// fetch so the user can recover without leaving the screen.
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
                        ProgressView()
                            .tint(theme.primary)
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
                    ProgressView()
                        .tint(theme.onAccent)
                }
            }
        }
    }

    private var editButton: some View {
        Button(String(localized: "taskDetail.edit.action")) {
            isEditing = true
        }
        // Editing requires the authoritative series (for the recurrence baseline).
        // Disabled while loading or after a failed load — the inline retry in
        // `recurrenceSection` lets the user recover.
        .disabled(isDeleting || isSkipping || isLoadingDetail || seriesDTO == nil)
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
            // Editing stays disabled (see editButton) so we never wipe the rule
            // from a form that couldn't load the authoritative series.
            detailLoadFailed = true
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
        // Skip keys on the stable originalStart; the effective occurrenceStart is
        // only used to choose which months to refresh. Fall back to the display
        // start if originalStart is somehow absent.
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
            endType: endType,
            endDate: endDate,
            count: count
        ).humanSummary
    }
}
