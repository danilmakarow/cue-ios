//
//  TaskEditScreen.swift
//  cue
//

import SwiftUI

/// Modal sheet for editing a task series. Patches `PATCH /tasks/:id` with the
/// updated fields. Called from `TaskDetailScreen` only once the authoritative
/// `seriesDTO` has loaded — so the recurrence baseline below is always real and
/// a save never accidentally clears a rule the form failed to see.
struct TaskEditScreen: View {
    let event: ScheduleEvent
    /// The authoritative series (guaranteed loaded by the caller). Its
    /// `recurrence` is the baseline used to compute the recurrence tri-state.
    let seriesDTO: TaskDTO
    let onSaved: (TaskDTO) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var startAt: Date = .now
    @State private var endAt: Date = .now.addingTimeInterval(3600)
    @State private var isAllDay: Bool = false
    @State private var requiresCompletion: Bool = false
    /// Current edited recurrence (`nil` == off). Compared against
    /// `initialRecurrence` at save time to decide unchanged / clear / set.
    @State private var recurrenceInput: RecurrenceRuleInput?
    /// The rule the form started with, derived from `seriesDTO.recurrence`.
    @State private var initialRecurrence: RecurrenceRuleInput?

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let api: APIClient = .shared

    var body: some View {
        Form {
            Section {
                TextField("newEvent.titleField", text: $title)
                    .textInputAutocapitalization(.sentences)
                TextField("newEvent.notesField", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("newEvent.details")
                    .cueText(.label)
                    .textCase(nil)
                    .foregroundStyle(theme.textSecondary)
            }

            Section {
                Toggle("newEvent.allDay", isOn: $isAllDay.animation(.default))
                if isAllDay {
                    DatePicker("newEvent.date", selection: $startAt, displayedComponents: .date)
                } else {
                    DatePicker(
                        "newEvent.start",
                        selection: $startAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    DatePicker(
                        "newEvent.end",
                        selection: $endAt,
                        in: startAt...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            } header: {
                Text("newEvent.time")
                    .cueText(.label)
                    .textCase(nil)
                    .foregroundStyle(theme.textSecondary)
            }

            Section {
                Toggle("newEvent.requiresCompletion", isOn: $requiresCompletion)
            }

            RecurrenceSection(recurrence: $recurrenceInput)
        }
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(String(localized: "taskDetail.edit.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "common.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "taskDetail.edit.save")) {
                    performSave()
                }
                .fontWeight(.semibold)
                .tint(theme.primary)
                .disabled(isSubmitting || title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .overlay {
            if isSubmitting {
                theme.textPrimary.opacity(0.08).ignoresSafeArea()
                ProgressView()
                    .tint(theme.primary)
            }
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
        .onAppear { populateFromDTO() }
    }

    // MARK: - Population

    private func populateFromDTO() {
        title = seriesDTO.title
        notes = seriesDTO.notes ?? ""
        startAt = seriesDTO.startAt ?? event.startAt
        endAt = seriesDTO.endAt ?? event.endAt
        isAllDay = seriesDTO.isAllDay
        requiresCompletion = seriesDTO.requiresCompletion
        let baseline = seriesDTO.recurrence.map(Self.input(from:))
        initialRecurrence = baseline
        recurrenceInput = baseline
    }

    /// Maps a response rule into the request-shaped input used by the editor.
    /// `nonisolated` (pure transform) so it's callable from the `Optional.map`
    /// closure in `populateFromDTO` without an actor-isolation warning.
    private nonisolated static func input(from rule: RecurrenceRuleDTO) -> RecurrenceRuleInput {
        RecurrenceRuleInput(
            frequency: rule.frequency,
            interval: rule.interval,
            byWeekday: rule.byWeekday,
            byMonthDay: rule.byMonthDay,
            byMonth: rule.byMonth,
            endType: rule.endType,
            endDate: rule.endDate,
            count: rule.count
        )
    }

    // MARK: - Save

    private func performSave() {
        isSubmitting = true
        Task {
            do {
                let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                let body = UpdateTaskRequest(
                    title: title.trimmingCharacters(in: .whitespaces),
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    startAt: startAt,
                    endAt: isAllDay ? nil : endAt,
                    isAllDay: isAllDay,
                    requiresCompletion: requiresCompletion,
                    groupId: seriesDTO.groupId,
                    recurrence: recurrenceFieldUpdate
                )
                let updated: TaskDTO = try await api.patch(
                    "/tasks/\(event.seriesId)",
                    body: body
                )
                onSaved(updated)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
            isSubmitting = false
        }
    }

    /// Tri-state for the recurrence field, comparing the current edited value
    /// against the baseline loaded from the series:
    /// - identical → `.unchanged` (omit the key; backend leaves the rule alone)
    /// - now `nil`, was a rule → `.clear` (explicit JSON null; backend removes it)
    /// - a (new or changed) rule → `.set(...)`
    private var recurrenceFieldUpdate: FieldUpdate<RecurrenceRuleInput> {
        if recurrenceInput == initialRecurrence {
            return .unchanged
        }
        guard let recurrenceInput else {
            return .clear
        }
        return .set(recurrenceInput)
    }
}

// MARK: - Recurrence Section

/// Inline section used by both `TaskEditScreen` and `NewEventScreen`.
struct RecurrenceSection: View {
    @Environment(\.theme) private var theme

    @Binding var recurrence: RecurrenceRuleInput?

    @State private var showEditor = false

    var body: some View {
        Section {
            Button {
                showEditor = true
            } label: {
                HStack {
                    Text("recurrence.label")
                    Spacer()
                    Text(recurrenceSummary)
                        .foregroundStyle(theme.textSecondary)
                    Image(systemName: "chevron.right")
                        .cueText(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .foregroundStyle(theme.textPrimary)
        } header: {
            Text("recurrence.section.title")
                .cueText(.label)
                .textCase(nil)
                .foregroundStyle(theme.textSecondary)
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                RecurrenceEditor(recurrence: $recurrence)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(String(localized: "common.done")) { showEditor = false }
                        }
                    }
            }
        }
    }

    private var recurrenceSummary: String {
        recurrence?.humanSummary ?? String(localized: "recurrence.off")
    }
}
