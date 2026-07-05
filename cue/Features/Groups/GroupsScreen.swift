//
//  GroupsScreen.swift
//  cue
//

import SwiftData
import SwiftUI

/// Groups management screen — list, create, edit, and delete task groups.
/// Reachable from `SettingsView`. Shows that a group's recurrence applies to all
/// its tasks by inheritance (unless a task has its own rule).
struct GroupsScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationStore.self) private var notifications
    @Environment(CalendarStore.self) private var calendarStore
    @Query(sort: \EventTaskGroup.sortOrder) private var localGroups: [EventTaskGroup]

    @State private var remoteDTOs: [TaskGroupDTO] = []
    @State private var isLoading = false
    @State private var showCreateSheet = false
    @State private var editingGroup: TaskGroupDTO?

    var body: some View {
        ScrollView {
            if localGroups.isEmpty {
                EmptyStateView(
                    title: String(localized: "groups.empty.title"),
                    message: String(localized: "groups.empty.description"),
                    systemImage: "folder",
                    actionTitle: "groups.edit.title.create",
                    ctaStyle: .primary,
                    action: { showCreateSheet = true }
                )
                .frame(maxWidth: .infinity, minHeight: 420)
            } else {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(localGroups) { group in
                        GroupRow(group: group) {
                            editingGroup = remoteDTOs.first(where: { $0.id == group.id })
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteGroup(group)
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.surfaceGrouped.ignoresSafeArea())
        .navigationTitle("groups.title")
        .refreshable { await loadGroups() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    // The ONE clay moment: the create affordance is a hand-pressed
                    // clay wax-seal (not a flat circle) with a white plus glyph and
                    // a soft float shadow lifting it off the chrome.
                    WaxSeal(isStamped: true, size: 36, systemImage: "plus")
                        .shadow(color: theme.textPrimary.opacity(0.18), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "groups.create", defaultValue: "New group"))
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                GroupEditSheet(existingDTO: nil) { newDTO in
                    EventTaskGroup.upsert(from: newDTO, in: modelContext)
                    try? modelContext.save()
                    remoteDTOs.append(newDTO)
                    showCreateSheet = false
                }
            }
            // A `.sheet` presents in a detached environment branch and does NOT
            // inherit the `CalendarStore` this screen received from its presenter;
            // `GroupEditSheet` reads `@Environment(CalendarStore.self)` and traps
            // without it. Re-inject explicitly.
            .environment(calendarStore)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingGroup) { dto in
            NavigationStack {
                GroupEditSheet(existingDTO: dto) { updatedDTO in
                    EventTaskGroup.upsert(from: updatedDTO, in: modelContext)
                    try? modelContext.save()
                    if let index = remoteDTOs.firstIndex(where: { $0.id == updatedDTO.id }) {
                        remoteDTOs[index] = updatedDTO
                    }
                    editingGroup = nil
                }
            }
            .environment(calendarStore)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .overlay {
            // Only show the blocking spinner when we already have cached rows to
            // sit behind it. On a cold load with no cached groups, suppress it so
            // the empty state owns the screen instead of flashing a spinner over
            // nothing (the empty branch is gated on `!isLoading`).
            if isLoading && !localGroups.isEmpty {
                ProgressView()
                    .tint(theme.primary)
            }
        }
        .task { await loadGroups() }
    }

    private func loadGroups() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let dtos: [TaskGroupDTO] = try await APIClient.shared.get("/task-groups")
            remoteDTOs = dtos
            for dto in dtos {
                EventTaskGroup.upsert(from: dto, in: modelContext)
            }
            try? modelContext.save()
        } catch {
            notifications.postError(error, title: String(localized: "groups.error.load"))
        }
    }

    /// Reorders groups in response to a drag. Optimistically renumbers every
    /// row's local `sortOrder` to its new index so the `@Query` reflects the move
    /// immediately, then persists the full ordered id list via
    /// `APIClient.reorderGroups(orderedIds:)`. On failure the prior order is
    /// restored from the returned (or cached) DTOs and the error is surfaced.
    private func moveGroups(from source: IndexSet, to destination: Int) {
        var ordered = localGroups
        ordered.move(fromOffsets: source, toOffset: destination)

        // Optimistic local renumber so the list animates into place at once.
        let previousOrder: [(id: String, sortOrder: Int)] = ordered.map { ($0.id, $0.sortOrder) }
        for (index, group) in ordered.enumerated() {
            group.sortOrder = index
        }
        try? modelContext.save()

        let orderedIds = ordered.map(\.id)
        Task {
            do {
                let updated = try await APIClient.shared.reorderGroups(orderedIds: orderedIds)
                for dto in updated {
                    EventTaskGroup.upsert(from: dto, in: modelContext)
                }
                remoteDTOs = updated
                try? modelContext.save()
            } catch {
                // Roll back to the pre-drag ordering.
                let byId = Dictionary(uniqueKeysWithValues: localGroups.map { ($0.id, $0) })
                for entry in previousOrder {
                    byId[entry.id]?.sortOrder = entry.sortOrder
                }
                try? modelContext.save()
                notifications.postError(error, title: String(localized: "groups.error.reorder"))
            }
        }
    }

    private func deleteGroup(_ group: EventTaskGroup) {
        Task {
            do {
                let _: DeletedIDResponse = try await APIClient.shared.delete(
                    "/task-groups/\(group.id)"
                )
                remoteDTOs.removeAll { $0.id == group.id }
                modelContext.delete(group)
                try? modelContext.save()
            } catch {
                notifications.postError(error, title: String(localized: "groups.error.delete"))
            }
        }
    }
}

// MARK: - GroupRow

private struct GroupRow: View {
    @Environment(\.theme) private var theme

    let group: EventTaskGroup
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            // Design rows: 13/14 inner padding on a floating tile (shadow-float)
            // with a 62pt min-height — tighter than the 16pt card default. We zero
            // CueCard's own padding and apply the asymmetric 13/14 ourselves.
            CueCard(padding: 0, depth: .valueCut) {
                HStack(spacing: Spacing.md) {
                    groupIcon
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(group.name)
                            .cueText(.titleM)
                            .foregroundStyle(theme.textPrimary)
                        if group.defaultRecurrenceRuleId != nil {
                            Label("groups.row.hasRecurrence", systemImage: "repeat")
                                .cueText(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .cueText(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .frame(minHeight: 62)
            }
        }
        .buttonStyle(.plain)
    }

    /// Tokenized icon tile: a sheet-fill paper square with a functional border.
    /// The persisted group color (resolved via `TaskColorResolver`, which handles
    /// both `TaskColor` preset names and `#RRGGBB` hex) tints the glyph; absent a
    /// color it falls back to the clay accent.
    private var groupIcon: some View {
        let color = TaskColorResolver.color(from: group.colorHex) ?? theme.primary
        return ZStack {
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1)
                )
                .frame(width: 36, height: 36)
            Image(systemName: group.icon ?? "folder")
                .foregroundStyle(color)
                .font(.system(size: 18))
        }
    }
}
