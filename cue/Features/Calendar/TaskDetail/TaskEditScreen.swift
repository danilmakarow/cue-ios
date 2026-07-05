//
//  TaskEditScreen.swift
//  cue
//

import SwiftUI

/// Which occurrences a recurring-task edit should apply to. Surfaced by the
/// "Apply changes to" card (recurring tasks only) and threaded into the save
/// path. The backend this-occurrence-vs-series split is not yet wired, so `.this`
/// currently falls back to the existing whole-series PATCH behaviour — see
/// `performSave`.
enum TaskEditScope: String, CaseIterable, Identifiable, Sendable {
    /// Edit only the tapped occurrence.
    case this
    /// Edit the whole repeating series.
    case all

    var id: String { rawValue }

    /// Segment label for the scope selector.
    var label: String {
        switch self {
        case .this: return String(localized: "taskEdit.scope.this", defaultValue: "This occurrence")
        case .all: return String(localized: "taskEdit.scope.all", defaultValue: "All occurrences")
        }
    }
}

/// Modal sheet for editing a task series. Patches `PATCH /tasks/:id` with the
/// updated fields.
///
/// The caller MAY hand in an already-loaded `seriesDTO`, but is not required to:
/// `TaskDetailScreen`'s own series fetch can fail (e.g. the recurring-occurrence
/// decode mismatch), and Edit must stay usable regardless. So this screen
/// lazy-loads the series itself when `seriesDTO == nil`, guarding the form behind
/// a loading state until the authoritative DTO resolves. The recurrence baseline
/// is only computed from that resolved DTO, so a save never clears a rule the
/// form never saw.
///
/// CUE — Clean layout: a scrolling stack of floating white `CueCard` sections
/// (scope · details · color · time · requires-completion · repeat · reminder ·
/// group) over the page canvas, NOT a grouped `Form`. The pinned clay
/// `Save changes` CTA lives in the bottom safe area.
struct TaskEditScreen: View {
    let event: ScheduleEvent
    /// The series detail the caller already had, if any. `nil` when the caller's
    /// own fetch failed — the form then lazy-loads it via ``loadSeriesDetail``.
    let providedSeriesDTO: TaskDTO?
    let onSaved: (TaskDTO) -> Void

    /// - Parameters:
    ///   - event: the tapped occurrence (always available; drives the URL + the
    ///     lazy-load fallback).
    ///   - seriesDTO: an already-loaded series detail, or `nil` to lazy-load.
    ///   - onSaved: called with the patched series on a successful save.
    init(event: ScheduleEvent, seriesDTO: TaskDTO?, onSaved: @escaping (TaskDTO) -> Void) {
        self.event = event
        self.providedSeriesDTO = seriesDTO
        self.onSaved = onSaved
    }

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// The authoritative series once resolved — either the one the caller passed
    /// in or the one this screen lazy-loaded. `nil` until it resolves; the form is
    /// gated behind a loading/error state until then. Its `recurrence` is the
    /// baseline used to compute the recurrence tri-state.
    @State private var seriesDTO: TaskDTO?
    /// True while the lazy series fetch is in flight.
    @State private var isLoadingSeries = false
    /// The real reason a lazy series fetch failed (surfaced verbatim), or `nil`.
    @State private var seriesLoadError: String?

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var startAt: Date = .now
    @State private var endAt: Date = .now.addingTimeInterval(3600)
    @State private var isAllDay: Bool = false
    @State private var requiresCompletion: Bool = false
    /// Selected preset duration. `nil` when the user has switched to the explicit
    /// start + end pickers and is freely editing `endAt`.
    @State private var duration: EventDuration? = .oneHour
    /// When true, the time card shows the explicit start + end pickers instead of
    /// the duration-preset row + single "Starts" anchor.
    @State private var useExplicitEnd: Bool = false
    /// Apply-changes-to scope for a recurring task. Defaults to `.all` (the
    /// existing whole-series behaviour). Only surfaced when the task is recurring.
    @State private var scope: TaskEditScope = .all
    /// Per-task icon (SF Symbol name); nil == iconless.
    @State private var icon: String?
    /// The icon the form started with, used to compute the icon tri-state.
    @State private var initialIcon: String?
    /// Per-task color token (a `TaskColor` preset name or `#RRGGBB` hex); nil ==
    /// none / inherit the group color. Bound to the `ColorTokenPicker`.
    @State private var colorToken: String?
    /// The color the form started with, used to compute the color tri-state.
    @State private var initialColorToken: String?
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
    /// Currently-selected owning group (`nil` == ungrouped). Editable, unlike the
    /// previous behaviour where the series' group was silently re-sent unchanged.
    @State private var selectedGroupId: String?
    /// Loaded task groups for the picker. Empty until `/task-groups` resolves.
    @State private var groups: [TaskGroupDTO] = []

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let api: APIClient = .shared

    /// Whether the recurring-only scope card should appear.
    private var isRecurring: Bool {
        event.isRecurring || initialRecurrence != nil
    }

    var body: some View {
        ScrollView {
            if seriesDTO != nil {
                editForm
            } else {
                loadingOrErrorState
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.huge)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.surfaceGrouped.ignoresSafeArea())
        .navigationTitle(String(localized: "taskDetail.edit.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // The global appearance does NOT serif SwiftUI inline titles, so
                // the design's Source Serif 4 "Edit task" is supplied explicitly.
                Text(String(localized: "taskDetail.edit.title"))
                    .font(.custom(Typography.serifSemiboldFamily, size: 18, relativeTo: .headline))
                    .tracking(-0.2)
                    .foregroundStyle(theme.textPrimary)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "common.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "taskDetail.edit.save")) {
                    performSave()
                }
                .fontWeight(.semibold)
                .tint(theme.primary)
                .disabled(isSaveDisabled)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if seriesDTO != nil {
                saveChangesCTA
            }
        }
        .overlay {
            if isSubmitting {
                savingOverlay
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
        .task { await resolveSeriesDetail() }
        .task { await loadGroups() }
    }

    /// The real editing form, shown once the authoritative series has resolved.
    private var editForm: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            if isRecurring {
                scopeCard
            }
            detailsSection
            colorSection
            timeSection
            requiresCompletionSection
            repeatSection
            reminderSection
            groupSection
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xl)
    }

    /// Loading spinner (fetch in flight) or an error notice with Retry, shown
    /// while the series detail is still resolving. Keeps the form from rendering
    /// against a half-empty baseline that could clobber unseen fields on save.
    @ViewBuilder
    private var loadingOrErrorState: some View {
        if let seriesLoadError {
            VStack(spacing: Spacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundStyle(theme.warning)
                Text("taskDetail.detailLoad.failed")
                    .cueText(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text(seriesLoadError)
                    .cueText(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await loadSeriesDetail() }
                } label: {
                    Text("taskDetail.detailLoad.retry")
                }
                .buttonStyle(.cue(.secondary))
                .disabled(isLoadingSeries)
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: Spacing.md) {
                ProgressView().tint(theme.primary)
                Text(LocalizedStringResource("taskDetail.edit.loading", defaultValue: "Loading task…"))
                    .cueText(.code)
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Save is disabled while submitting, while the series hasn't resolved, or
    /// when the title is empty.
    private var isSaveDisabled: Bool {
        isSubmitting || seriesDTO == nil || title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Sections

    /// Recurring-only "Apply changes to" card: a two-segment scope switch plus a
    /// mono rule-summary footnote. The first card above Details.
    private var scopeCard: some View {
        CueCard(padding: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(String(localized: "taskEdit.scope.header", defaultValue: "Apply changes to"))
                    .cueText(.label)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.textSecondary)
                SegmentedControl(
                    selection: $scope,
                    options: TaskEditScope.allCases,
                    label: \.label
                )
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(scopeFootnote)
                            .cueText(.caption)
                            .foregroundStyle(theme.textSecondary)
                        if let rule = recurrenceInput {
                            Text(rule.humanSummary)
                                .cueText(.codeSmall)
                                .foregroundStyle(theme.textPrimary)
                        }
                    }
                }
            }
        }
    }

    /// The contextual footnote under the scope switch.
    private var scopeFootnote: String {
        switch scope {
        case .this:
            return String(localized: "taskEdit.scope.this.footnote", defaultValue: "Editing only this occurrence.")
        case .all:
            return String(localized: "taskEdit.scope.all.footnote", defaultValue: "Editing the whole repeating series.")
        }
    }

    /// Details — eyebrow label + filled gray title well, filled gray notes well,
    /// and an icon row inside one white card.
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("newEvent.details")
            CueCard(padding: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    TaskEditFilledField(
                        label: String(localized: "newEvent.details.title", defaultValue: "Title"),
                        placeholder: String(localized: "newEvent.titleField"),
                        text: $title
                    )
                    TaskEditFilledField(
                        label: String(localized: "newEvent.details.notes", defaultValue: "Notes"),
                        placeholder: String(localized: "newEvent.notesField"),
                        text: $notes,
                        axis: .vertical
                    )
                    HStack {
                        Text("newEvent.icon")
                            .cueText(.label)
                            .foregroundStyle(theme.textSecondary)
                        Spacer()
                        IconPickerButton(selection: $icon)
                    }
                }
            }
        }
    }

    /// Color — a swatch grid bound to the per-task color token. `nil` (the hollow
    /// "none" swatch) inherits the owning group's color; a preset overrides it.
    /// Persisted to `TaskDTO.color` via the `UpdateTaskRequest.color` tri-state.
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Inlined header (not `sectionHeader`, which needs a catalog key) so a
            // NEW string can use `String(localized:defaultValue:)` without a
            // hand-edited `Localizable.xcstrings`. Matches the sibling headers.
            Text(String(localized: "taskEdit.color.section", defaultValue: "Color"))
                .cueText(.label)
                .textCase(.uppercase)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Spacing.xs)
            CueCard(padding: Spacing.lg) {
                ColorTokenPicker(selection: $colorToken)
            }
        }
    }

    /// Time — one white card: all-day toggle → duration presets → single Starts
    /// anchor (or explicit start + end pickers).
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("newEvent.time")
            TaskEditTimeCard(
                startAt: $startAt,
                endAt: $endAt,
                isAllDay: $isAllDay,
                duration: $duration,
                useExplicitEnd: $useExplicitEnd
            )
        }
    }

    /// Requires-completion — toggle card + footnote caption.
    private var requiresCompletionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            CueCard(padding: 0) {
                HStack {
                    Text("newEvent.requiresCompletion")
                        .cueText(.body)
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    CueToggle(
                        isOn: $requiresCompletion,
                        accessibilityLabel: String(localized: "newEvent.requiresCompletion")
                    )
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.xs)
                .frame(minHeight: 44)
            }
            Text("newEvent.requiresCompletion.footer")
                .cueText(.caption)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Spacing.xs)
        }
    }

    /// Repeat — inline-expanding recurrence card (shared `InlineRecurrencePanel`).
    private var repeatSection: some View {
        InlineRecurrencePanel(recurrence: $recurrenceInput)
    }

    /// Reminder — "Remind me" toggle card (the `ReminderEditor` already supplies
    /// the card chrome + master toggle).
    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("reminder.section")
            ReminderEditor(reminders: $reminders)
        }
    }

    /// Group — a single white card row showing the owning group's color + name.
    @ViewBuilder
    private var groupSection: some View {
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                sectionHeader("newEvent.group.section")
                CueCard(padding: 0) {
                    Menu {
                        Picker("newEvent.group.label", selection: $selectedGroupId) {
                            Text("newEvent.group.none").tag(Optional<String>.none)
                            ForEach(groups) { group in
                                Text(group.name).tag(Optional(group.id))
                            }
                        }
                    } label: {
                        HStack {
                            Text("newEvent.group.label")
                                .cueText(.body)
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            groupTrailing
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// The selected group's color swatch + name (or "None").
    @ViewBuilder
    private var groupTrailing: some View {
        if let group = groups.first(where: { $0.id == selectedGroupId }) {
            HStack(spacing: Spacing.sm) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(hex: group.color ?? "") ?? theme.primary)
                    .frame(width: 14, height: 14)
                Text(group.name)
                    .cueText(.body)
                    .foregroundStyle(theme.textSecondary)
            }
        } else {
            Text("newEvent.group.none")
                .cueText(.body)
                .foregroundStyle(theme.textSecondary)
        }
    }

    /// Loads the account's task groups for the group picker. Non-fatal on
    /// failure — the picker simply stays hidden.
    private func loadGroups() async {
        guard groups.isEmpty else { return }
        do {
            let fetched: [TaskGroupDTO] = try await APIClient.shared.get("/task-groups")
            groups = fetched
        } catch {
            // Non-fatal — group picker just won't appear.
        }
    }

    /// Resolves the authoritative series once on appear: adopts the caller-provided
    /// DTO if there is one, otherwise lazy-loads it. Runs once (guards on the
    /// already-resolved `seriesDTO`) so a `.task` re-fire can't re-trigger it.
    private func resolveSeriesDetail() async {
        guard seriesDTO == nil else { return }
        if let providedSeriesDTO {
            seriesDTO = providedSeriesDTO
            populateFromDTO(providedSeriesDTO)
            return
        }
        await loadSeriesDetail()
    }

    /// Lazy-loads the series row via `GET /tasks/:id` and populates the form from
    /// it. Surfaces the real error (decode / HTTP) so a failure like the recurring
    /// decode mismatch is visible instead of silently blocking the form.
    private func loadSeriesDetail() async {
        isLoadingSeries = true
        seriesLoadError = nil
        defer { isLoadingSeries = false }

        do {
            let dto: TaskDTO = try await api.get("/tasks/\(event.seriesId)")
            seriesDTO = dto
            populateFromDTO(dto)
        } catch {
            seriesLoadError = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    /// Pinned bottom decisive CTA — mirrors `NewEventScreen`'s save anchor so the
    /// edit flow gets the same one-tap, thumb-zone commit affordance instead of
    /// relying only on the top-bar text button. Sits on the same OPAQUE footer
    /// (full-width `surfaceElevated` + 1px top hairline, ignoring the bottom safe
    /// area) so the disabled button and the content above never bleed through.
    private var saveChangesCTA: some View {
        Button {
            performSave()
        } label: {
            Label {
                Text(LocalizedStringResource("taskDetail.edit.saveChanges", defaultValue: "Save changes"))
            } icon: {
                Image(systemName: "checkmark")
            }
        }
        .buttonStyle(.cue(.decisive))
        .disabled(isSaveDisabled)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            theme.surfaceElevated
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(theme.separator)
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Carded saving overlay — a clay spinner + mono "Saving…" on a floating
    /// `surface` card over a soft scrim. (Deliberately NOT the WaxSeal used by
    /// `NewEventScreen`; CUE — Clean retires the seal as a progress affordance.)
    private var savingOverlay: some View {
        ZStack {
            theme.textPrimary.opacity(0.08).ignoresSafeArea()
            VStack(spacing: Spacing.sm) {
                ProgressView()
                    .tint(theme.primary)
                Text(LocalizedStringResource("taskDetail.edit.saving", defaultValue: "Saving…"))
                    .cueText(.code)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.lg)
            .background(
                theme.surface,
                in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            )
            .cueDepth(.valueCut, radius: Radius.card)
        }
    }

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .cueText(.label)
            .textCase(.uppercase)
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, Spacing.xs)
    }

    // MARK: - Population

    /// Populates the editable form state from the resolved series DTO. Takes the
    /// DTO explicitly (rather than reading a stored property) so it can be called
    /// the moment the series resolves — whether provided by the caller or
    /// lazy-loaded here.
    private func populateFromDTO(_ dto: TaskDTO) {
        title = dto.title
        notes = dto.notes ?? ""
        startAt = dto.startAt ?? event.startAt
        endAt = dto.endAt ?? event.endAt
        isAllDay = dto.isAllDay
        requiresCompletion = dto.requiresCompletion
        selectedGroupId = dto.groupId
        icon = dto.icon
        initialIcon = dto.icon
        colorToken = dto.color
        initialColorToken = dto.color
        // Reconcile the duration-preset from the loaded span; fall back to the
        // explicit-end pickers when the span doesn't match a known preset.
        let minutes = Int((endAt.timeIntervalSince(startAt) / 60).rounded())
        if let matched = EventDuration(rawValue: minutes) {
            duration = matched
            useExplicitEnd = false
        } else {
            duration = nil
            useExplicitEnd = true
        }
        let editable = dto.reminders.map(EditableReminder.init(from:))
        reminders = editable
        initialReminders = editable.map(\.input)
        let baseline = dto.recurrence.map(Self.input(from:))
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

    /// Whether this save should materialize a single-occurrence override rather
    /// than patch the whole series: a recurring task edited in the `.this` scope
    /// with a real occurrence key. (An already-overridden occurrence is a one-off
    /// child — `isRecurring == false` — so it never reaches here and patches its
    /// own row directly.)
    private var shouldOverrideThisOccurrence: Bool {
        isRecurring && scope == .this && event.originalStart != nil
    }

    private func performSave() {
        isSubmitting = true
        Task {
            do {
                let updated: TaskDTO
                if shouldOverrideThisOccurrence, let originalStart = event.originalStart {
                    updated = try await api.post(
                        "/tasks/\(event.seriesId)/occurrences/override",
                        body: overrideRequest(originalStart: originalStart)
                    )
                } else {
                    updated = try await api.patch(
                        "/tasks/\(event.seriesId)",
                        body: seriesUpdateRequest()
                    )
                }
                onSaved(updated)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
            isSubmitting = false
        }
    }

    /// The whole-series `PATCH /tasks/:id` body (the `.all` scope / a one-off /
    /// an override child editing its own row).
    private func seriesUpdateRequest() -> UpdateTaskRequest {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return UpdateTaskRequest(
            title: title.trimmingCharacters(in: .whitespaces),
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            startAt: startAt,
            endAt: isAllDay ? nil : endAt,
            isAllDay: isAllDay,
            requiresCompletion: requiresCompletion,
            groupId: selectedGroupId,
            color: colorFieldUpdate,
            icon: iconFieldUpdate,
            reminders: remindersUpdate,
            recurrence: recurrenceFieldUpdate
        )
    }

    /// The `POST /tasks/:id/occurrences/override` body for a `.this`-scope edit of
    /// a recurring occurrence. `originalStart` is serialized with fractional
    /// seconds to match the backend occurrence key; the patch carries the full
    /// edited state (the server builds the child from the parent snapshot, then
    /// applies these fields). Reminders are sent only when they differ from the
    /// baseline (else the child keeps the reminders copied from the parent).
    private func overrideRequest(originalStart: Date) -> CreateOccurrenceOverrideRequest {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return CreateOccurrenceOverrideRequest(
            originalStart: CalendarStore.isoFractional.string(from: originalStart),
            title: title.trimmingCharacters(in: .whitespaces),
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            startAt: startAt,
            endAt: isAllDay ? nil : endAt,
            isAllDay: isAllDay,
            requiresCompletion: requiresCompletion,
            groupId: selectedGroupId,
            color: colorFieldUpdate,
            icon: iconFieldUpdate,
            reminders: remindersUpdate
        )
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

    /// Tri-state for the color token: unchanged when identical to the baseline,
    /// `.clear` (explicit null → inherit the group color) when removed, `.set`
    /// when a preset/hex was chosen.
    private var colorFieldUpdate: FieldUpdate<String> {
        if colorToken == initialColorToken { return .unchanged }
        guard let colorToken else { return .clear }
        return .set(colorToken)
    }

    /// Reminders replacement set: `nil` (omit the key, leave untouched) when the
    /// edited rows match the baseline; otherwise the full replacement array (an
    /// empty array clears all reminders, a populated one replaces them).
    private var remindersUpdate: [ReminderInput]? {
        let current = reminders.map(\.input)
        return current == initialReminders ? nil : current
    }
}

// MARK: - Filled labelled field

/// A labelled, filled gray input well used by the Details card — an uppercase
/// eyebrow label above a recessed `surfaceSunken` `TextField` with a soft button
/// corner. Replaces the plain transparent `Form` text rows. React analogy: a
/// `<LabeledField label placeholder value onChange />`.
private struct TaskEditFilledField: View {
    @Environment(\.theme) private var theme

    let label: String
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label.uppercased())
                .cueText(.label)
                .foregroundStyle(theme.textSecondary)
            field
                .cueText(.body)
                .foregroundStyle(theme.textPrimary)
                .tint(theme.primary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(shape.fill(theme.surfaceSunken))
        }
    }

    @ViewBuilder
    private var field: some View {
        if axis == .vertical {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(2...6)
                .textInputAutocapitalization(.sentences)
        } else {
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.sentences)
        }
    }
}

// MARK: - Time card

/// The Time card body — an all-day toggle, a horizontally-scrolling row of
/// duration-preset chips, and a single "Starts" inline date-time anchor whose
/// duration drives `endAt`. An escape switches to explicit start + end pickers.
/// Page-local to `TaskEditScreen`.
private struct TaskEditTimeCard: View {
    @Environment(\.theme) private var theme

    @Binding var startAt: Date
    @Binding var endAt: Date
    @Binding var isAllDay: Bool
    @Binding var duration: EventDuration?
    @Binding var useExplicitEnd: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            CueCard(padding: 0) {
                VStack(spacing: 0) {
                    allDayRow
                    if !isAllDay {
                        Divider().overlay(theme.separator)
                        if useExplicitEnd {
                            explicitPickers
                        } else {
                            durationRow
                            Divider().overlay(theme.separator)
                            startsRow
                        }
                    } else {
                        Divider().overlay(theme.separator)
                        dateOnlyRow
                    }
                }
            }
            if !isAllDay {
                switchModeButton
            }
        }
    }

    private var allDayRow: some View {
        HStack {
            Text("newEvent.allDay")
                .cueText(.body)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            CueToggle(
                isOn: $isAllDay.animation(.easeOut(duration: 0.16)),
                accessibilityLabel: String(localized: "newEvent.allDay")
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: 44)
    }

    /// Horizontally-scrolling duration presets on the shared recessed track: a
    /// gray `surfaceSunken` container whose SELECTED preset is a white raised
    /// pill (the inverse of the old loose gray-selected chips). Wraps the
    /// optional `duration` in a non-optional binding (defaulting to `.oneHour`)
    /// so the never-`nil` preset mode satisfies `DurationPresetTrack`.
    private var durationRow: some View {
        DurationPresetTrack(
            selection: Binding(
                get: { duration ?? .oneHour },
                set: { option in
                    withAnimation(.snappy) {
                        duration = option
                        endAt = startAt.addingTimeInterval(option.seconds)
                    }
                }
            ),
            options: EventDuration.allCases,
            label: \.label
        )
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var startsRow: some View {
        // `.flush` so the row sits FLAT inside the white Time card (no inner
        // surfaceSunken well / card-in-card) with "Starts" as a body-size title,
        // matching the design's flush in-card row. The picker supplies its own
        // vertical rhythm; the card supplies the horizontal inset.
        InlineDateTimePicker(
            label: String(localized: "newEvent.starts"),
            date: Binding(
                get: { startAt },
                set: { newStart in
                    startAt = newStart
                    if let duration {
                        endAt = newStart.addingTimeInterval(duration.seconds)
                    }
                }
            ),
            mode: .dateAndTime,
            style: .flush
        )
        .padding(.horizontal, Spacing.lg)
    }

    private var explicitPickers: some View {
        VStack(spacing: Spacing.md) {
            InlineDateTimePicker(
                label: String(localized: "newEvent.start"),
                date: $startAt,
                mode: .dateAndTime
            )
            InlineDateTimePicker(
                label: String(localized: "newEvent.end"),
                date: $endAt,
                mode: .dateAndTime
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var dateOnlyRow: some View {
        InlineDateTimePicker(
            label: String(localized: "newEvent.date"),
            date: $startAt,
            mode: .date
        )
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var switchModeButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                useExplicitEnd.toggle()
                if !useExplicitEnd {
                    // Returning to preset mode — snap to the nearest known preset.
                    let minutes = Int((endAt.timeIntervalSince(startAt) / 60).rounded())
                    if let matched = EventDuration(rawValue: minutes) {
                        duration = matched
                    } else {
                        duration = .oneHour
                        endAt = startAt.addingTimeInterval(EventDuration.oneHour.seconds)
                    }
                }
            }
        } label: {
            Text(useExplicitEnd
                 ? String(localized: "taskEdit.time.usePresets", defaultValue: "Switch to duration presets")
                 : String(localized: "taskEdit.time.useExplicit", defaultValue: "Switch to start + end pickers"))
                .cueText(.label)
                .foregroundStyle(theme.accentText)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.xs)
    }
}

// MARK: - Inline recurrence panel (moved)

// The inline-expanding recurrence panel previously defined here
// (`TaskEditRecurrencePanel`) plus its `CueStepper` sub-control and the
// `RecurrenceFrequency`/`RecurrenceEndType` short-label extensions now live in
// `InlineRecurrencePanel.swift` as the reusable `InlineRecurrencePanel`, shared
// with the rebuilt Group Edit flow.

// MARK: - Recurrence Section

/// Inline section used by `NewEventScreen` and `GroupEditSheet`. (Kept here for
/// those callers — `TaskEditScreen` now uses the shared `InlineRecurrencePanel`
/// in `InlineRecurrencePanel.swift` instead.)
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
