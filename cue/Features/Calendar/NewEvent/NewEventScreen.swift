//
//  NewEventScreen.swift
//  cue
//

import SwiftData
import SwiftUI

/// Push-navigated screen for creating a new calendar event. The Save action is
/// the app's second wax-seal moment: committing the event presses the seal.
struct NewEventScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @State private var viewModel = NewEventViewModel()
    @State private var showRecurrenceEditor = false
    @State private var groups: [TaskGroupDTO] = []
    /// Drives the seal-press animation in the saving overlay (false → true on
    /// appear so the seal stamps down once per submit).
    @State private var sealStamped = false

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            Section("newEvent.details") {
                TextField("newEvent.titleField", text: $viewModel.title)
                    .textInputAutocapitalization(.sentences)
                TextField("newEvent.notesField", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("newEvent.time") {
                Toggle("newEvent.allDay", isOn: $viewModel.isAllDay.animation(.default))

                if viewModel.isAllDay {
                    DatePicker(
                        "newEvent.date",
                        selection: $viewModel.startAt,
                        displayedComponents: .date
                    )
                } else if viewModel.useClassicPicker {
                    DatePicker(
                        "newEvent.start",
                        selection: $viewModel.startAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    DatePicker(
                        "newEvent.end",
                        selection: $viewModel.endAt,
                        in: viewModel.startAt...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    Button("newEvent.useQuickPicker") {
                        withAnimation { viewModel.useClassicPicker = false }
                    }
                    .cueText(.caption)
                    .foregroundStyle(theme.accentText)
                } else {
                    durationChipStrip(viewModel: viewModel)
                    DatePicker(
                        "newEvent.starts",
                        selection: $viewModel.startAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
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

    private func loadGroups() async {
        // Only fetch once; the `.task` can re-fire on re-appear.
        guard groups.isEmpty else { return }
        do {
            let fetched: [TaskGroupDTO] = try await APIClient.shared.get("/task-groups")
            groups = fetched
        } catch {
            // Non-fatal — group picker just won't appear.
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

    /// The key CTA — the one rationed terracotta `.decisive` button (a 6pt cut
    /// sheet, not a pill), anchored to the bottom safe area. Submitting presses the
    /// wax seal in the overlay.
    @ViewBuilder
    private func saveButton(viewModel: NewEventViewModel) -> some View {
        Button {
            Task {
                guard let created = await viewModel.submit() else { return }
                // Upsert locally so the new event appears immediately — the
                // month it lands in may already be marked synced.
                TaskItem.upsert(from: created, in: modelContext)
                try? modelContext.save()
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
