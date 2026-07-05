//
//  NewEventScreen.swift
//  cue
//

import SwiftData
import SwiftUI

/// Push-navigated screen for creating a new calendar event. The Save action is
/// the app's decisive commit moment: committing the event fires the GREEN
/// roots-commit motion over the rationed clay `.decisive` CTA.
///
/// CUE — Clean composition: instead of a native SwiftUI `Form`, the screen is a
/// `ScrollView` of floating white `CueCard`s (radius 12, soft float shadow) with
/// tight uppercase eyebrow labels sitting *outside/above* each card — matching
/// the design's card-on-canvas layout rather than iOS inset-grouped chrome.
struct NewEventScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @Environment(CalendarStore.self) private var store
    @State private var viewModel = NewEventViewModel()
    @State private var groups: [TaskGroupDTO] = []
    /// Bumped once on a successful save to fire the GREEN roots-commit motion.
    @State private var commitTrigger = 0
    /// Presents the group-selection sheet.
    @State private var isPickingGroup = false
    /// Presents the recurrence editor sheet (the page-local "Repeat" row trigger).
    @State private var isEditingRecurrence = false

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            // Design rhythm sits at ~18–22pt between sections; the 20pt token
            // tracks that closer than the looser 24pt step.
            VStack(alignment: .leading, spacing: Spacing.xl) {
                QuickCreateWell { draft in
                    withAnimation(.snappy) { viewModel.applyDraft(draft) }
                }

                detailsSection(viewModel: viewModel)
                timeSection(viewModel: viewModel)
                requiresCompletionSection(viewModel: viewModel)
                repeatSection(viewModel: viewModel)
                reminderSection(viewModel: viewModel)
                groupSection(viewModel: viewModel)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("newEvent.title")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            saveButton(viewModel: viewModel)
        }
        .overlay {
            if viewModel.isSubmitting {
                savingOverlay
            }
        }
        .overlay {
            // Rendered only after the first successful save so it plays exactly
            // once (the GREEN commit motion), never on mount.
            if commitTrigger > 0 {
                RootsCommitView(tone: .save, trigger: commitTrigger)
                    .frame(width: 96, height: 96)
                    .allowsHitTesting(false)
            }
        }
        .alert(
            "newEvent.alert.saveFailed.title",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.clearError()
                    }
                }
            )
        ) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .disabled(viewModel.isSubmitting)
        .sheet(isPresented: $isPickingGroup) {
            GroupPickerSheet(groups: groups, selectedGroupId: $viewModel.selectedGroupId)
        }
        .sheet(isPresented: $isEditingRecurrence) {
            NavigationStack {
                RecurrenceEditor(recurrence: $viewModel.recurrenceInput)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(String(localized: "common.done")) { isEditingRecurrence = false }
                        }
                    }
            }
        }
        .task { await loadGroups() }
    }

    // MARK: - Sections

    /// DETAILS — bare gray-fill Title/Notes inputs + the round icon-picker trigger,
    /// each under its own tight uppercase eyebrow label (no enclosing list card).
    @ViewBuilder
    private func detailsSection(viewModel: NewEventViewModel) -> some View {
        @Bindable var viewModel = viewModel
        VStack(alignment: .leading, spacing: Spacing.lg) {
            sectionEyebrow("newEvent.details")

            VStack(alignment: .leading, spacing: Spacing.xs) {
                fieldEyebrow("newEvent.title.eyebrow")
                TextField("newEvent.titleField", text: $viewModel.title)
                    .textInputAutocapitalization(.sentences)
                    .cueText(.body)
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.md)
                    .fillField()
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                fieldEyebrow("newEvent.notes.eyebrow")
                TextField("newEvent.notesField", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(2...6)
                    .cueText(.body)
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.md)
                    .fillField()
            }

            HStack {
                fieldEyebrow("newEvent.icon")
                Spacer()
                IconPickerButton(selection: $viewModel.icon)
            }
        }
    }

    /// TIME — a single floating CueCard holding the All-day toggle, the duration
    /// segmented selector, and the inline "Starts" row, separated by hairlines.
    @ViewBuilder
    private func timeSection(viewModel: NewEventViewModel) -> some View {
        @Bindable var viewModel = viewModel
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionEyebrow("newEvent.time")

            CueCard(padding: 0, depth: .valueCut) {
                VStack(spacing: 0) {
                    toggleRow(
                        title: "newEvent.allDay",
                        isOn: $viewModel.isAllDay.animation(.default)
                    )

                    if viewModel.isAllDay {
                        cardDivider
                        NewEventStartsRow(
                            label: String(localized: "newEvent.date"),
                            date: $viewModel.startAt,
                            mode: .date
                        )
                    } else if viewModel.useClassicPicker {
                        cardDivider
                        NewEventStartsRow(
                            label: String(localized: "newEvent.start"),
                            date: $viewModel.startAt,
                            mode: .dateAndTime
                        )
                        cardDivider
                        NewEventStartsRow(
                            label: String(localized: "newEvent.end"),
                            date: $viewModel.endAt,
                            mode: .dateAndTime
                        )
                    } else {
                        cardDivider
                        DurationPresetTrack(
                            selection: durationBinding(viewModel: viewModel),
                            options: EventDuration.allCases,
                            label: { $0.label }
                        )
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        cardDivider
                        NewEventStartsRow(
                            label: String(localized: "newEvent.starts"),
                            date: $viewModel.startAt,
                            mode: .dateAndTime
                        )
                    }
                }
            }

            classicPickerToggle(viewModel: viewModel)
        }
    }

    /// Bridges the view model's optional `duration` to the non-optional binding
    /// the shared `DurationPresetTrack` expects. Reads fall back to `.oneHour`
    /// (the default preset); writes flow straight back to the view model, which
    /// keeps `endAt` in sync. The track is only shown in non-classic mode, where
    /// `duration` is always non-nil, so the fallback is just a safety default.
    private func durationBinding(viewModel: NewEventViewModel) -> Binding<EventDuration> {
        Binding(
            get: { viewModel.duration ?? .oneHour },
            set: { viewModel.duration = $0 }
        )
    }

    /// The clay text link that flips between the duration presets and the
    /// start + end classic pickers.
    @ViewBuilder
    private func classicPickerToggle(viewModel: NewEventViewModel) -> some View {
        if viewModel.isAllDay {
            EmptyView()
        } else if viewModel.useClassicPicker {
            Button("newEvent.useQuickPicker") {
                withAnimation { viewModel.useClassicPicker = false }
            }
            .cueText(.label)
            .foregroundStyle(theme.accentText)
            .padding(.leading, Spacing.xxs)
        } else {
            Button("newEvent.switchToClassicPicker") {
                withAnimation { viewModel.useClassicPicker = true }
            }
            .cueText(.label)
            .foregroundStyle(theme.accentText)
            .padding(.leading, Spacing.xxs)
        }
    }

    /// REQUIRES COMPLETION — a single toggle card with a caption hint below it.
    @ViewBuilder
    private func requiresCompletionSection(viewModel: NewEventViewModel) -> some View {
        @Bindable var viewModel = viewModel
        VStack(alignment: .leading, spacing: Spacing.sm) {
            CueCard(padding: 0, depth: .valueCut) {
                toggleRow(
                    title: "newEvent.requiresCompletion",
                    isOn: $viewModel.requiresCompletion
                )
            }
            Text("newEvent.requiresCompletion.footer")
                .cueText(.caption)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Spacing.xs)
        }
    }

    /// REPEAT — a tappable card row that opens the recurrence editor (page-local
    /// equivalent of the frozen `RecurrenceSection`, which only renders inside a
    /// `Form`/`List`).
    @ViewBuilder
    private func repeatSection(viewModel: NewEventViewModel) -> some View {
        CueCard(padding: 0, depth: .valueCut) {
            Button {
                isEditingRecurrence = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text("recurrence.label")
                        .cueText(.body)
                        .foregroundStyle(theme.textPrimary)
                    Spacer(minLength: Spacing.sm)
                    Text(recurrenceSummary(viewModel: viewModel))
                        .cueText(.body)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// The human-readable recurrence summary (or "Off" when none is set).
    private func recurrenceSummary(viewModel: NewEventViewModel) -> String {
        viewModel.recurrenceInput?.humanSummary ?? String(localized: "recurrence.off")
    }

    /// REMINDER — `ReminderEditor` already renders its own toggle CueCard, so it
    /// drops straight into the stack under its eyebrow.
    @ViewBuilder
    private func reminderSection(viewModel: NewEventViewModel) -> some View {
        @Bindable var viewModel = viewModel
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionEyebrow("reminder.section")
            ReminderEditor(reminders: $viewModel.reminders)
        }
    }

    /// GROUP — the always-shown tappable group row in its own floating card.
    @ViewBuilder
    private func groupSection(viewModel: NewEventViewModel) -> some View {
        CueCard(padding: 0, depth: .valueCut) {
            groupRow(viewModel: viewModel)
        }
    }

    // MARK: - Reusable row pieces

    /// A tight uppercase section eyebrow sitting above a card (`.label`, secondary).
    private func sectionEyebrow(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .cueText(.label)
            .textCase(.uppercase)
            .foregroundStyle(theme.textSecondary)
            .padding(.leading, Spacing.xxs)
    }

    /// A field-level uppercase eyebrow (Title / Notes / Icon), matching the design.
    private func fieldEyebrow(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .cueText(.label)
            .textCase(.uppercase)
            .foregroundStyle(theme.textSecondary)
    }

    /// A standard card toggle row: a body-weight title on the left, a `CueToggle`
    /// on the right, on a 44pt-min row.
    private func toggleRow(title: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .cueText(.body)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            CueToggle(isOn: isOn)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 44)
    }

    /// A hairline separator spanning a card row group.
    private var cardDivider: some View {
        Rectangle()
            .fill(theme.separator)
            .frame(height: 1)
    }

    private func loadGroups() async {
        guard groups.isEmpty else { return }
        do {
            let fetched: [TaskGroupDTO] = try await APIClient.shared.get("/task-groups")
            groups = fetched
        } catch {
            // Non-fatal — the group row stays on "None" with no groups to pick.
        }
    }

    /// The currently-selected group, resolved from the loaded list.
    private func selectedGroup(viewModel: NewEventViewModel) -> TaskGroupDTO? {
        guard let id = viewModel.selectedGroupId else { return nil }
        return groups.first { $0.id == id }
    }

    /// The always-shown Group row: a tappable card row with a leading "Group"
    /// label and a trailing color swatch + name + chevron. Shown even when no
    /// groups exist (reads "None"), mirroring the design's persistent row.
    @ViewBuilder
    private func groupRow(viewModel: NewEventViewModel) -> some View {
        let group = selectedGroup(viewModel: viewModel)
        Button {
            isPickingGroup = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Text("newEvent.group.label")
                    .cueText(.body)
                    .foregroundStyle(theme.textPrimary)
                Spacer(minLength: Spacing.sm)
                if let group {
                    RoundedRectangle(cornerRadius: Radius.tight, style: .continuous)
                        .fill(TaskColorResolver.color(from: group.color) ?? theme.accentText)
                        .frame(width: 14, height: 14)
                    Text(group.name)
                        .cueText(.body)
                        .foregroundStyle(theme.textSecondary)
                } else {
                    Text("newEvent.group.none")
                        .cueText(.body)
                        .foregroundStyle(theme.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The key CTA — the one rationed terracotta `.decisive` button anchored to
    /// the bottom safe area. Submitting presses the wax seal in the overlay and,
    /// on success, fires the GREEN roots-commit motion.
    ///
    /// Sits on an OPAQUE footer (full-width `surfaceElevated`, ignoring the bottom
    /// safe area) with a 1px top hairline, so the disabled (faded clay) button and
    /// the `requiresCompletion` caption above it don't bleed through the inset —
    /// matching the design's solid footer.
    @ViewBuilder
    private func saveButton(viewModel: NewEventViewModel) -> some View {
        Button {
            Task {
                // Resolve the calendar id through the single owner (the memoized,
                // SwiftData-upserting `CalendarStore`) instead of the view model
                // re-fetching /calendars — so concurrent create flows on a fresh
                // account can't each POST a duplicate "Default" calendar.
                guard let calendarId = try? await store.resolvedCalendarId(context: modelContext) else {
                    viewModel.reportCalendarResolutionFailure()
                    return
                }
                guard let created = await viewModel.submit(calendarId: calendarId) else { return }
                commitTrigger += 1
                // Route the new event through the shared store (not a direct
                // `modelContext` upsert) so it bumps `CalendarStore.revision` and the
                // UIKit calendar scopes refresh — mirroring how `TaskEditScreen`'s
                // save resyncs via `invalidateAndResync`. The ±1-month fan-out also
                // covers a start that lands near a month boundary. Detached so it
                // outlives this view's dismissal, like `TaskDetailScreen.onSaved`.
                let anchor = created.startAt ?? viewModel.startAt
                Task { await store.invalidateAndResync(around: anchor, context: modelContext) }
                // Let the commit motion read before dismissing.
                try? await Task.sleep(for: .milliseconds(420))
                dismiss()
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.primary)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(theme.onAccent))
                Text(String(localized: "newEvent.saveTask", defaultValue: "Save task"))
            }
        }
        .buttonStyle(.cue(.decisive))
        .disabled(!viewModel.canSubmit)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            // Opaque footer + 1px top hairline so the translucent disabled button
            // and the caption above no longer bleed through the safe-area inset.
            theme.surfaceElevated
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(theme.separator)
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Saving state — a warm scrim and a clay spinner + mono "Saving…" on a
    /// surface card. (Clean retires the wax-seal saving overlay; the commit
    /// signature is the GREEN roots-commit motion, fired on success.)
    private var savingOverlay: some View {
        ZStack {
            theme.textPrimary.opacity(0.08)
                .ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                ProgressView()
                    .controlSize(.large)
                    .tint(theme.primary)
                Text("newEvent.saving")
                    .cueText(.code)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xxl)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .cueDepth(.valueCut, radius: Radius.large)
        }
    }
}

// MARK: - Field fill modifier

private extension View {
    /// The design's bare gray-fill input treatment: a `surfaceSunken` fill at the
    /// 10pt button radius (no border), used for the Title / Notes fields.
    func fillField() -> some View {
        modifier(FillFieldModifier())
    }
}

private struct FillFieldModifier: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                theme.surfaceSunken,
                in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
            )
    }
}

// MARK: - Starts row

/// The TIME card's inline date/time row: a plain `.body` label on the left and
/// the value as bare mono receipt text + a chevron on the right (NO enclosing
/// gray pill). Tapping expands a graphical (date) / wheel (time) `DatePicker` in
/// place, inside the card — matching the design's flat "Starts  Wed Jun 24,
/// 2026  13:00 ⌄" row that opens the picker below it.
private struct NewEventStartsRow: View {
    @Environment(\.theme) private var theme
    @State private var isExpanded = false

    let label: String
    @Binding var date: Date
    let mode: DateTimePickerMode

    /// The `DatePicker` components implied by the row's mode.
    private var components: DatePickerComponents {
        switch mode {
        case .date: return [.date]
        case .time: return [.hourAndMinute]
        case .dateAndTime: return [.date, .hourAndMinute]
        }
    }

    /// The receipt-text rendering of the value, matched to the editable components.
    private var receipt: String {
        switch mode {
        case .date:
            return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
        case .time:
            return date.formatted(.dateTime.hour().minute())
        case .dateAndTime:
            return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year().hour().minute())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            collapsedRow
            if isExpanded {
                Rectangle()
                    .fill(theme.separator)
                    .frame(height: 1)
                picker
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
            }
        }
        .animation(.easeOut(duration: 0.16), value: isExpanded)
    }

    private var collapsedRow: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: Spacing.sm) {
                Text(label)
                    .cueText(.body)
                    .foregroundStyle(theme.textPrimary)
                Spacer(minLength: Spacing.sm)
                Text(receipt)
                    .cueText(.code)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var picker: some View {
        let base = DatePicker(
            label,
            selection: $date,
            displayedComponents: components
        )
        .labelsHidden()
        .tint(theme.primary)

        if mode == .time {
            base
                .datePickerStyle(.wheel)
                .frame(maxWidth: .infinity)
        } else {
            base
                .datePickerStyle(.graphical)
                .frame(maxWidth: .infinity)
        }
    }
}

/// Modal list for picking the new task's group (or "None"). Each row shows the
/// group's color swatch + name; the current selection carries a trailing check.
private struct GroupPickerSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    let groups: [TaskGroupDTO]
    @Binding var selectedGroupId: String?

    var body: some View {
        NavigationStack {
            List {
                row(id: nil, label: String(localized: "newEvent.group.none"), color: nil)
                ForEach(groups) { group in
                    row(id: group.id, label: group.name, color: TaskColorResolver.color(from: group.color))
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("newEvent.group.section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                        .tint(theme.accentText)
                }
            }
        }
    }

    /// A single selectable group row (swatch + name + trailing check when chosen).
    @ViewBuilder
    private func row(id: String?, label: String, color: Color?) -> some View {
        Button {
            selectedGroupId = id
            dismiss()
        } label: {
            HStack(spacing: Spacing.sm) {
                if let color {
                    RoundedRectangle(cornerRadius: Radius.tight, style: .continuous)
                        .fill(color)
                        .frame(width: 14, height: 14)
                }
                Text(label)
                    .foregroundStyle(theme.textPrimary)
                Spacer(minLength: Spacing.sm)
                if id == selectedGroupId {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.accentText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let sampleUser = UserDTO(
        id: "usr_preview",
        appleUserId: "apple_001",
        email: "jane.appleseed@icloud.com",
        displayName: "Jane Appleseed",
        avatarBase64: nil,
        timezone: "Europe/Berlin",
        createdAt: .now,
        updatedAt: .now
    )
    return NavigationStack {
        NewEventScreen()
    }
    .environment(CalendarStore(user: sampleUser))
    .modelContainer(for: [EventCalendar.self, TaskItem.self, EventTaskGroup.self], inMemory: true)
}
