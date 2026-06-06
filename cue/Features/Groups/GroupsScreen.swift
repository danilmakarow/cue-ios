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
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationStore.self) private var notifications
    @Query(sort: \EventTaskGroup.sortOrder) private var localGroups: [EventTaskGroup]

    @State private var remoteDTOs: [TaskGroupDTO] = []
    @State private var isLoading = false
    @State private var showCreateSheet = false
    @State private var editingGroup: TaskGroupDTO?

    var body: some View {
        List {
            if localGroups.isEmpty && !isLoading {
                ContentUnavailableView(
                    "groups.empty.title",
                    systemImage: "folder",
                    description: Text("groups.empty.description")
                )
            } else {
                ForEach(localGroups) { group in
                    GroupRow(group: group) {
                        editingGroup = remoteDTOs.first(where: { $0.id == group.id })
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteGroup(group)
                        } label: {
                            Label("common.delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("groups.title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
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
        }
        .overlay {
            if isLoading {
                ProgressView()
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
    let group: EventTaskGroup
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                groupIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.headline)
                    if group.defaultRecurrenceRuleId != nil {
                        Label("groups.row.hasRecurrence", systemImage: "repeat")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
        }
        .foregroundStyle(.primary)
    }

    private var groupIcon: some View {
        let color = group.colorHex.flatMap { Color(hex: $0) } ?? .accentColor
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15))
                .frame(width: 36, height: 36)
            Image(systemName: group.icon ?? "folder.fill")
                .foregroundStyle(color)
                .font(.system(size: 16))
        }
    }
}
