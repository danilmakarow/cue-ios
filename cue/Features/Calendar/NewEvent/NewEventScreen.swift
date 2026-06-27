//
//  NewEventScreen.swift
//  cue
//

import SwiftData
import SwiftUI

/// Push-navigated screen for creating a new calendar event. The Save action is
/// the app's second wax-seal moment: committing the event presses the seal and
/// fires the GREEN roots-commit motion.
struct NewEventScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @State private var viewModel = NewEventViewModel()
    @State private var groups: [TaskGroupDTO] = []
    /// Drives the seal-press animation in the saving overlay (false → true on
    /// appear so the seal stamps down once per submit).
    @State private var sealStamped = false
    /// Bumped once on a successful save to fire the GREEN roots-commit motion.
    @State private var commitTrigger = 0

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            Section {
                QuickCreateWell { draft in
                    withAnimation(.snappy) { viewModel.applyDraft(draft) }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("newEvent.details") {
                TextField("newEvent.titleField", text: $viewModel.title)
                    .textInputAutocapitalization(.sentences)
                TextField("newEvent.notesField", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
                iconRow(viewModel: viewModel)
            }

            Section("newEvent.time") {
                Toggle("newEvent.allDay", isOn: $viewModel.isAllDay.animation(.default))

                if viewModel.isAllDay {
                    InlineDateTimePicker(
                        label: String(localized: "newEvent.date"),
                        date: $viewModel.startAt,
                        mode: .date
                    )
                    .listRowInsets(timeRowInsets)
                } else if viewModel.useClassicPicker {
                    InlineDateTimePicker(
                        label: String(localized: "newEvent.start"),
                        date: $viewModel.startAt,
                        mode: .dateAndTime
                    )
                    .listRowInsets(timeRowInsets)
                    InlineDateTimePicker(
                        label: String(localized: "newEvent.end"),
                        date: $viewModel.endAt,
                        mode: .dateAndTime
                    )
                    .listRowInsets(timeRowInsets)
                    Button("newEvent.useQuickPicker") {
                        withAnimation { viewModel.useClassicPicker = false }
                    }
                    .cueText(.caption)
                    .foregroundStyle(theme.accentText)
                } else {
                    durationChipStrip(viewModel: viewModel)
                    InlineDateTimePicker(
                        label: String(localized: "newEvent.starts"),
                        date: $viewModel.startAt,
                        mode: .dateAndTime
                    )
                    .listRowInsets(timeRowInsets)
                    Button("newEvent.switchToClassicPicker") {
                        withAnimation { viewModel.useClassicPicker = true }
                    }
                    .cueText(.caption)
                    .foregroundStyle(theme.accentText)
                }
            }

            Section {
                Toggle("newEvent.requiresCompletion", isOn: $viewModel.requiresCompletion)
            } footer: {
                Text("newEvent.requiresCompletion.footer")
            }

            RecurrenceSection(recurrence: $viewModel.recurrenceInput)

            Section("reminder.section") {
                ReminderEditor(reminders: $viewModel.reminders)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if !groups.isEmpty {
                Section(String(localized: "newEvent.group.section")) {
                    Picker("newEvent.group.label", selection: $viewModel.selectedGroupId) {
                        Text("newEvent.group.none").tag(Optional<String>.none)
                        ForEach(groups) { group in
                            Text(group.name).tag(Optional(group.id))
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
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
        .task { await loadGroups() }
    }

    /// Standard insets for the inline date-time picker rows so the well fills the
    /// row width without the default form leading inset.
    private var timeRowInsets: EdgeInsets {
        EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg)
    }

    private func loadGroups() async {
        guard groups.isEmpty else { return }
        do {
            let fetched: [TaskGroupDTO] = try await APIClient.shared.get("/task-groups")
            groups = fetched
        } catch {
            // Non-fatal — group picker just won't appear.
        }
    }

    /// The per-task icon row: an eyebrow label + the round icon-picker trigger.
    @ViewBuilder
    private func iconRow(viewModel: NewEventViewModel) -> some View {
        @Bindable var viewModel = viewModel
        HStack {
            Text("newEvent.icon")
                .foregroundStyle(theme.textPrimary)
            Spacer()
            IconPickerButton(selection: $viewModel.icon)
        }
    }

    /// Horizontal chip selector for preset event durations.
    @ViewBuilder
    private func durationChipStrip(viewModel: NewEventViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(EventDuration.allCases) { option in
                    CueChip(
                        option.label,
                        isSelected: viewModel.duration == option
                    ) {
                        withAnimation(.snappy) { viewModel.duration = option }
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
        }
        .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.lg, bottom: Spacing.sm, trailing: Spacing.lg))
    }

    /// The key CTA — the one rationed terracotta `.decisive` button anchored to
    /// the bottom safe area. Submitting presses the wax seal in the overlay and,
    /// on success, fires the GREEN roots-commit motion.
    @ViewBuilder
    private func saveButton(viewModel: NewEventViewModel) -> some View {
        Button {
            Task {
                guard let created = await viewModel.submit() else { return }
                commitTrigger += 1
                TaskItem.upsert(from: created, in: modelContext)
                try? modelContext.save()
                // Let the commit motion read before dismissing.
                try? await Task.sleep(for: .milliseconds(420))
                dismiss()
            }
        } label: {
            Text("newEvent.save")
        }
        .buttonStyle(.cue(.decisive))
        .disabled(!viewModel.canSubmit)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.sm)
    }

    /// Saving state — a warm scrim and the wax seal pressing down (the commit
    /// signature), on a letterpress surface card.
    private var savingOverlay: some View {
        ZStack {
            theme.textPrimary.opacity(0.08)
                .ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                WaxSeal(isStamped: sealStamped, size: 64)
                Text("newEvent.saving")
                    .cueText(.callout)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xxl)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .cueDepth(.valueCut, radius: Radius.large)
            .onAppear { sealStamped = true }
            .onDisappear { sealStamped = false }
        }
    }
}

#Preview {
    NavigationStack {
        NewEventScreen()
    }
    .modelContainer(for: [EventCalendar.self, TaskItem.self, EventTaskGroup.self], inMemory: true)
}
