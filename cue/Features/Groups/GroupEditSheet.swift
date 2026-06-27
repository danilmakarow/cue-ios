//
//  GroupEditSheet.swift
//  cue
//

import SwiftData
import SwiftUI

/// Modal sheet for creating or editing a task group. Handles
/// `POST /task-groups` (create) and `PATCH /task-groups/:id` (update).
struct GroupEditSheet: View {
    /// Nil → create; non-nil → edit.
    let existingDTO: TaskGroupDTO?
    let onSaved: (TaskGroupDTO) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(CalendarStore.self) private var calendarStore

    @State private var name: String = ""
    @State private var colorHex: String? = nil
    @State private var icon: String? = nil
    /// Group default completion requirement inherited by tasks (a task's own value
    /// still wins). Edited as a plain `Bool`; an unset baseline reads as `false`.
    @State private var requiresCompletion: Bool = false
    /// Baseline `requiresCompletion` the sheet opened with, used to compute the
    /// tri-state `FieldUpdate` on save (clear when toggled back to the unset default).
    @State private var initialRequiresCompletion: Bool? = nil
    /// Current edited recurrence (`nil` == off). Compared against
    /// `initialRecurrence` on save to decide unchanged / clear / set.
    @State private var recurrenceInput: RecurrenceRuleInput?
    /// Baseline rule the sheet opened with (nil when creating or when the group
    /// had no default rule).
    @State private var initialRecurrence: RecurrenceRuleInput?
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isEditing: Bool { existingDTO != nil }
    private let api: APIClient = .shared

    /// Preset color swatches — the six Clean semantic inks (persisted as hex
    /// strings the backend round-trips). Resolved to a `Color` at render time via
    /// `TaskColorResolver` so what's stored is exactly what ships to the API.
    private let colorOptions: [String] = [
        "#5A3A24", // espresso
        "#BE4A28", // clay
        "#466234", // olive
        "#A8331F", // brick
        "#C9A24B", // brass
        "#6E5C4C", // muted
    ]

    // SF Symbol presets
    private let iconOptions = [
        "folder.fill", "star.fill", "heart.fill", "bolt.fill",
        "flame.fill", "book.fill", "briefcase.fill", "cart.fill",
        "figure.run", "dumbbell.fill", "music.note", "graduationcap.fill",
    ]

    var body: some View {
        Form {
            Section {
                TextField("groups.edit.name", text: $name)
                    .textInputAutocapitalization(.words)
            } header: {
                Text("groups.edit.details")
                    .cueText(.label)
                    .textCase(nil)
                    .foregroundStyle(theme.textSecondary)
            }

            Section {
                colorPicker
            } header: {
                Text("groups.edit.color")
                    .cueText(.label)
                    .textCase(nil)
                    .foregroundStyle(theme.textSecondary)
            }

            Section {
                iconPicker
            } header: {
                Text("groups.edit.icon")
                    .cueText(.label)
                    .textCase(nil)
                    .foregroundStyle(theme.textSecondary)
            }

            Section {
                HStack(spacing: Spacing.md) {
                    Text("groups.edit.requiresCompletion")
                        .cueText(.body)
                        .foregroundStyle(theme.textPrimary)
                    Spacer(minLength: 0)
                    CueToggle(
                        isOn: $requiresCompletion,
                        accessibilityLabel: String(localized: "groups.edit.requiresCompletion")
                    )
                }
                .listRowBackground(theme.surface)
            } footer: {
                Text("groups.edit.requiresCompletion.footnote")
                    .cueText(.caption)
                    .foregroundStyle(theme.textSecondary)
            }

            RecurrenceSection(recurrence: $recurrenceInput)

            if recurrenceInput != nil {
                Section {
                    Label("groups.edit.recurrence.inheritNote", systemImage: "info.circle")
                        .cueText(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(isEditing
            ? String(localized: "groups.edit.title.edit")
            : String(localized: "groups.edit.title.create")
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "common.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "common.save")) { performSave() }
                    .disabled(isSubmitting || name.trimmingCharacters(in: .whitespaces).isEmpty)
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

    // MARK: - Color picker

    private var colorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                // Clear / no color
                colorSwatch(hex: nil)
                ForEach(colorOptions, id: \.self) { hex in
                    colorSwatch(hex: hex)
                }
            }
            .padding(.vertical, Spacing.xs)
        }
        .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.lg, bottom: Spacing.sm, trailing: Spacing.lg))
        .listRowBackground(theme.surface)
    }

    /// One color swatch. `hex == nil` is the "no color" option, drawn as a
    /// hollow paper chip; otherwise the persisted token resolves to its ink via
    /// `TaskColorResolver` (handles preset names and `#RRGGBB` hex). Selection is
    /// marked with an espresso ring (primary).
    private func colorSwatch(hex: String?) -> some View {
        let isSelected = colorHex == hex
        let fill = TaskColorResolver.color(from: hex)
        return Button {
            colorHex = hex
        } label: {
            Circle()
                .fill(fill ?? theme.surfaceSunken)
                .frame(width: 32, height: 32)
                .overlay {
                    if fill == nil {
                        Image(systemName: "slash.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(theme.border, lineWidth: 1)
                }
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(theme.primary, lineWidth: 2)
                            .padding(-4)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Icon picker

    private var iconPicker: some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 6), spacing: Spacing.md) {
            ForEach(iconOptions, id: \.self) { symbolName in
                iconSwatch(symbolName: symbolName)
            }
        }
        .padding(.vertical, Spacing.xs)
        .listRowBackground(theme.surface)
    }

    /// One icon tile. Selected → espresso fill with cream glyph; unselected →
    /// a paper sheet tile with a functional border and ink glyph.
    private func iconSwatch(symbolName: String) -> some View {
        let isSelected = icon == symbolName
        return Button {
            icon = symbolName
        } label: {
            Image(systemName: symbolName)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(
                    isSelected ? theme.primary : theme.surface,
                    in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : theme.border, lineWidth: 1)
                )
                .foregroundStyle(isSelected ? theme.onAccent : theme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Populate

    private func populateFromDTO() {
        guard let dto = existingDTO else { return }
        name = dto.name
        colorHex = dto.color
        icon = dto.icon
        initialRequiresCompletion = dto.requiresCompletion
        requiresCompletion = dto.requiresCompletion ?? false
        let baseline = dto.recurrence.map { rule in
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
        initialRecurrence = baseline
        recurrenceInput = baseline
    }

    // MARK: - Save

    private func performSave() {
        isSubmitting = true
        Task {
            do {
                let dto: TaskGroupDTO
                if let existing = existingDTO {
                    let body = UpdateTaskGroupRequest(
                        name: name.trimmingCharacters(in: .whitespaces),
                        color: colorHex,
                        icon: icon,
                        sortOrder: nil,
                        requiresCompletion: requiresCompletionFieldUpdate,
                        recurrence: recurrenceFieldUpdate
                    )
                    dto = try await api.patch("/task-groups/\(existing.id)", body: body)
                } else {
                    // Need a calendarId. Resolve it through the single owner (the
                    // memoized, SwiftData-upserting `CalendarStore`) instead of
                    // re-fetching/POSTing `/calendars` here — so a fresh account
                    // can't race a SECOND "Default" calendar into existence.
                    let calendarId = try await calendarStore.resolvedCalendarId(context: modelContext)
                    let body = CreateTaskGroupRequest(
                        calendarId: calendarId,
                        name: name.trimmingCharacters(in: .whitespaces),
                        color: colorHex,
                        icon: icon,
                        sortOrder: nil,
                        requiresCompletion: requiresCompletion ? true : nil,
                        recurrence: recurrenceInput
                    )
                    dto = try await api.post("/task-groups", body: body)
                }
                onSaved(dto)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
            isSubmitting = false
        }
    }

    /// Tri-state for the group's `requiresCompletion` field on update: unchanged
    /// when it still equals the baseline; otherwise `.clear` when the user toggled
    /// back to the unset default (`false` with no prior value) so the group
    /// re-inherits, else `.set(true/false)` for an explicit value.
    private var requiresCompletionFieldUpdate: FieldUpdate<Bool> {
        if requiresCompletion == (initialRequiresCompletion ?? false) {
            // No effective change: leave the stored value (and its set/unset-ness) be.
            return .unchanged
        }
        if requiresCompletion == false && initialRequiresCompletion == nil {
            return .clear
        }
        return .set(requiresCompletion)
    }

    /// Tri-state for the group's default-recurrence field on update: unchanged
    /// when it matches the baseline, `.clear` (explicit null) when the user turned
    /// it off, `.set` for a new or changed rule.
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
