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
            VStack(alignment: .leading, spacing: 20) {
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
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
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
        VStack(alignment: .leading, spacing: 6) {
            Text(event.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            if event.isRecurring {
                Label("taskDetail.recurring.badge", systemImage: "repeat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(formattedDateRange)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "clock")
                    .foregroundStyle(.tint)
            }
        }
    }

    private func notesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "note.text")
                    .foregroundStyle(.tint)
            }
        }
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                if let rule = seriesDTO?.recurrence {
                    Text(rule.humanSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if isLoadingDetail {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("taskDetail.recurrence.unknown")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "repeat")
                    .foregroundStyle(.tint)
            }
        }
    }

    /// Inline, non-blocking notice shown when the series detail failed to load.
    /// Editing is disabled in this state (see `editButton`); Retry re-attempts the
    /// fetch so the user can recover without leaving the screen.
    private var detailLoadFailedRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text("taskDetail.detailLoad.failed")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button(String(localized: "taskDetail.detailLoad.retry")) {
                Task { await loadSeriesDetail() }
            }
            .font(.footnote.weight(.semibold))
            .disabled(isLoadingDetail)
        }
        .padding(12)
        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 12))
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if event.isRecurring {
                Button {
                    performSkip()
                } label: {
                    Label("taskDetail.skip.action", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isSkipping || isDeleting)
                .overlay {
                    if isSkipping {
                        ProgressView()
                    }
                }
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("taskDetail.delete.action", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isDeleting || isSkipping)
            .overlay {
                if isDeleting {
                    ProgressView()
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
