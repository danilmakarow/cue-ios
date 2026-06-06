//
//  GroupEditSheet.swift
//  cue
//

import SwiftUI

/// Modal sheet for creating or editing a task group. Handles
/// `POST /task-groups` (create) and `PATCH /task-groups/:id` (update).
struct GroupEditSheet: View {
    /// Nil → create; non-nil → edit.
    let existingDTO: TaskGroupDTO?
    let onSaved: (TaskGroupDTO) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var colorHex: String? = nil
    @State private var icon: String? = nil
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

    // Preset color swatches (hex strings)
    private let colorOptions: [(String, Color)] = [
        ("#FF6B6B", .red),
        ("#FF9F43", .orange),
        ("#FECA57", .yellow),
        ("#48DBFB", .cyan),
        ("#1DD1A1", .green),
        ("#5F27CD", .purple),
        ("#C8D6E5", .gray),
    ]

    // SF Symbol presets
    private let iconOptions = [
        "folder.fill", "star.fill", "heart.fill", "bolt.fill",
        "flame.fill", "book.fill", "briefcase.fill", "cart.fill",
        "figure.run", "dumbbell.fill", "music.note", "graduationcap.fill",
    ]

    var body: some View {
        Form {
            Section(String(localized: "groups.edit.details")) {
                TextField("groups.edit.name", text: $name)
                    .textInputAutocapitalization(.words)
            }

            Section(String(localized: "groups.edit.color")) {
                colorPicker
            }

            Section(String(localized: "groups.edit.icon")) {
                iconPicker
            }

            RecurrenceSection(recurrence: $recurrenceInput)

            if recurrenceInput != nil {
                Section {
                    Label("groups.edit.recurrence.inheritNote", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
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
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView()
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
            HStack(spacing: 10) {
                // Clear / no color
                colorSwatch(hex: nil, color: .secondary)
                ForEach(colorOptions, id: \.0) { hex, color in
                    colorSwatch(hex: hex, color: color)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private func colorSwatch(hex: String?, color: Color) -> some View {
        let isSelected = colorHex == hex
        return Button {
            colorHex = hex
        } label: {
            Circle()
                .fill(color.opacity(0.7))
                .frame(width: 32, height: 32)
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(.primary, lineWidth: 2)
                            .padding(-4)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Icon picker

    private var iconPicker: some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 6), spacing: 12) {
            ForEach(iconOptions, id: \.self) { symbolName in
                iconSwatch(symbolName: symbolName)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconSwatch(symbolName: String) -> some View {
        let isSelected = icon == symbolName
        return Button {
            icon = symbolName
        } label: {
            Image(systemName: symbolName)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(
                    isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
                )
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Populate

    private func populateFromDTO() {
        guard let dto = existingDTO else { return }
        name = dto.name
        colorHex = dto.color
        icon = dto.icon
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
                        recurrence: recurrenceFieldUpdate
                    )
                    dto = try await api.patch("/task-groups/\(existing.id)", body: body)
                } else {
                    // Need a calendarId. Fetch from /calendars.
                    let calendarId = try await fetchDefaultCalendarId()
                    let body = CreateTaskGroupRequest(
                        calendarId: calendarId,
                        name: name.trimmingCharacters(in: .whitespaces),
                        color: colorHex,
                        icon: icon,
                        sortOrder: nil,
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

    private func fetchDefaultCalendarId() async throws -> String {
        let calendars: [CalendarDTO] = try await api.get("/calendars")
        if let first = calendars.first { return first.id }
        let created: CalendarDTO = try await api.post(
            "/calendars",
            body: CreateCalendarRequest(name: "Default", color: nil, icon: nil)
        )
        return created.id
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
