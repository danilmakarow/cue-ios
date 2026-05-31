//
//  NewEventScreen.swift
//  cue
//

import SwiftData
import SwiftUI

/// Push-navigated screen for creating a new calendar event.
struct NewEventScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = NewEventViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            Section("Details") {
                TextField("Title", text: $viewModel.title)
                    .textInputAutocapitalization(.sentences)
                TextField("Notes", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Time") {
                Toggle("All-day", isOn: $viewModel.isAllDay.animation(.default))

                if viewModel.isAllDay {
                    DatePicker(
                        "Date",
                        selection: $viewModel.startAt,
                        displayedComponents: .date
                    )
                } else if viewModel.useClassicPicker {
                    DatePicker(
                        "Start",
                        selection: $viewModel.startAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    DatePicker(
                        "End",
                        selection: $viewModel.endAt,
                        in: viewModel.startAt...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    Button("Use quick picker") {
                        withAnimation { viewModel.useClassicPicker = false }
                    }
                    .font(.footnote)
                    .foregroundStyle(.tint)
                } else {
                    durationChipStrip(viewModel: viewModel)
                    DatePicker(
                        "Starts",
                        selection: $viewModel.startAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    Button("Switch to classic picker") {
                        withAnimation { viewModel.useClassicPicker = true }
                    }
                    .font(.footnote)
//                    .foregroundStyle(.tint)
                }
            }

            Section {
                Toggle("Requires completion", isOn: $viewModel.requiresCompletion)
            } footer: {
                Text("If off, the event is informational — no done/not-done state.")
            }
        }
        .navigationTitle("New Event")
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
            "Couldn't save event",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.clearError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .disabled(viewModel.isSubmitting)
    }

    /// Horizontal chip selector for preset event durations.
    @ViewBuilder
    private func durationChipStrip(viewModel: NewEventViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EventDuration.allCases) { option in
                    durationChip(option: option, viewModel: viewModel)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    /// A single duration chip, accent-tinted when selected.
    @ViewBuilder
    private func durationChip(option: EventDuration, viewModel: NewEventViewModel) -> some View {
        let isSelected = viewModel.duration == option
        Button(option.label) {
            withAnimation(.snappy) { viewModel.duration = option }
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .accentColor : .secondary)
        .controlSize(.small)
        .fontWeight(isSelected ? .semibold : .regular)
        .overlay {
            if isSelected {
                Capsule()
                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
            }
        }
    }

    /// Floating liquid-glass Save button anchored to the bottom safe area.
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
            Text("Save")
                .font(.headline)
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .disabled(!viewModel.canSubmit)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("Saving…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
        }
    }
}

#Preview {
    NavigationStack {
        NewEventScreen()
    }
    .modelContainer(for: [EventCalendar.self, TaskItem.self], inMemory: true)
}
