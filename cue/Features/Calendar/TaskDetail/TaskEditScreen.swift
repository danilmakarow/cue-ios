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
    /// Per-task icon (SF Symbol name); nil == iconless.
    @State private var icon: String?
    /// The icon the form started with, used to compute the icon tri-state.
    @State private var initialIcon: String?
    /// Editable reminder rows. Compared against `initialReminders` to decide
    /// whether to send a replacement set at save.
    @State private var reminders: [EditableReminder] = []
    /// The reminders the form started with (offset+channel only — ids are local).
    @State private var initialReminders: [ReminderInput] = []
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
                HStack {
                    Text("newEvent.icon")
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    IconPickerButton(selection: $icon)
                }
            } header: {
                sectionHeader("newEvent.details")
            }

            Section {
                Toggle("newEvent.allDay", isOn: $isAllDay.animation(.default))
                if isAllDay {
                    InlineDateTimePicker(
                        label: String(localized: "newEvent.date"),
                        date: $startAt,
                        mode: .date
                    )
                    .listRowInsets(timeRowInsets)
                } else {
                    InlineDateTimePicker(
                        label: String(localized: "newEvent.start"),
                        date: $startAt,
                        mode: .dateAndTime
                    )
                    .listRowInsets(timeRowInsets)
                    InlineDateTimePicker(
                        label: String(localized: "newEvent.end"),
                        date: $endAt,
                        mode: .dateAndTime
                    )
                    .listRowInsets(timeRowInsets)
                }
            } header: {
                sectionHeader("newEvent.time")
            }

            Section {
                Toggle("newEvent.requiresCompletion", isOn: $requiresCompletion)
            }

            RecurrenceSection(recurrence: $recurrenceInput)

            Section {
                ReminderEditor(reminders: $reminders)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                sectionHeader("reminder.section")
            }
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

    /// Standard insets for the inline date-time picker rows.
    private var timeRowInsets: EdgeInsets {
        EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg)
    }

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .cueText(.label)
            .textCase(nil)
            .foregroundStyle(theme.textSecondary)
    }

    // MARK: - Population

    private func populateFromDTO() {
        title = seriesDTO.title
        notes = seriesDTO.notes ?? ""
        startAt = seriesDTO.startAt ?? event.startAt
        endAt = seriesDTO.endAt ?? event.endAt
        isAllDay = seriesDTO.isAllDay
        requiresCompletion = seriesDTO.requiresCompletion
        icon = seriesDTO.icon
        initialIcon = seriesDTO.icon
        let editable = seriesDTO.reminders.map(EditableReminder.init(from:))
        reminders = editable
        initialReminders = editable.map(\.input)
        let baseline = seriesDTO.recurrence.map(Self.input(from:))
        initialRecurrence = baseline
        recurrenceInput = baseline
    }

    /// Maps a response rule into the request-shaped input used by the editor,
    /// carrying the advanced monthly fields (`bySetPos`, `monthlyAnchor`) so the
    /// baseline round-trips losslessly. `nonisolated` (pure transform) so it's
    /// callable from the `Optional.map` closure in `populateFromDTO`.
    private nonisolated static func input(from rule: RecurrenceRuleDTO) -> RecurrenceRuleInput {
        RecurrenceRuleInput(
            frequency: rule.frequency,
            interval: rule.interval,
            byWeekday: rule.byWeekday,
            byMonthDay: rule.byMonthDay,
            byMonth: rule.byMonth,
            bySetPos: rule.bySetPos,
            monthlyAnchor: rule.monthlyAnchor,
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
                    icon: iconFieldUpdate,
                    reminders: remindersUpdate,
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

    /// Tri-state for the icon: unchanged when identical to the baseline, `.clear`
    /// (explicit null) when removed, `.set` when added/changed.
    private var iconFieldUpdate: FieldUpdate<String> {
        if icon == initialIcon { return .unchanged }
        guard let icon else { return .clear }
        return .set(icon)
    }

    /// Reminders replacement set: `nil` (omit the key, leave untouched) when the
    /// edited rows match the baseline; otherwise the full replacement array (an
    /// empty array clears all reminders, a populated one replaces them).
    private var remindersUpdate: [ReminderInput]? {
        let current = reminders.map(\.input)
        return current == initialReminders ? nil : current
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
