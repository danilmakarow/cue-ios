//
//  ReminderEditor.swift
//  cue
//

import SwiftUI

/// The per-task reminders editor. A `Remind me` toggle reveals a list of
/// reminder rows; each row cycles a ``ReminderOffset`` and picks a delivery
/// channel (Push / Telegram) via a ``SegmentedControl``. Used by both
/// `NewEventScreen` (create) and `TaskEditScreen` (edit).
///
/// Binds the live `[EditableReminder]`; the host turns these into
/// `[ReminderInput]` on save. Toggling the switch off clears the list, on
/// seeds a single default row when empty — so an "on but empty" state never
/// persists a misleading reminder-less task.
struct ReminderEditor: View {
    @Environment(\.theme) private var theme

    @Binding var reminders: [EditableReminder]

    var body: some View {
        CueCard(padding: 0) {
            VStack(spacing: 0) {
                toggleRow
                if !reminders.isEmpty {
                    Divider().overlay(theme.separator)
                    rowsBody
                }
            }
        }
    }

    // MARK: - Toggle row

    private var toggleRow: some View {
        HStack {
            Text("reminder.remindMe")
                .cueText(.body)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            CueToggle(
                isOn: Binding(
                    get: { !reminders.isEmpty },
                    set: { isOn in
                        withAnimation(.snappy) {
                            if isOn {
                                if reminders.isEmpty { reminders = [EditableReminder()] }
                            } else {
                                reminders = []
                            }
                        }
                    }
                ),
                accessibilityLabel: String(localized: "reminder.remindMe")
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 44)
    }

    // MARK: - Rows

    private var rowsBody: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach($reminders) { $reminder in
                reminderRow(reminder: $reminder)
            }
            addButton
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
    }

    private func reminderRow(reminder: Binding<EditableReminder>) -> some View {
        HStack(spacing: Spacing.sm) {
            offsetChip(reminder: reminder)
            channelPicker(reminder: reminder)
            removeButton(reminder: reminder)
        }
    }

    /// Tap-to-advance offset chip — cycles through the ``ReminderOffset`` presets.
    private func offsetChip(reminder: Binding<EditableReminder>) -> some View {
        Button {
            withAnimation(.snappy) {
                reminder.wrappedValue.offset = reminder.wrappedValue.offset.next
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(reminder.wrappedValue.offset.label)
                    .cueText(.code)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .fill(theme.surfaceSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func channelPicker(reminder: Binding<EditableReminder>) -> some View {
        SegmentedControl(
            selection: reminder.channel,
            options: NotificationChannel.allCases,
            label: \.reminderLabel
        )
        .frame(width: 168)
    }

    private func removeButton(reminder: Binding<EditableReminder>) -> some View {
        Button {
            withAnimation(.snappy) {
                reminders.removeAll { $0.id == reminder.wrappedValue.id }
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "reminder.remove"))
    }

    private var addButton: some View {
        Button {
            withAnimation(.snappy) {
                reminders.append(EditableReminder())
            }
        } label: {
            Label("reminder.add", systemImage: "plus")
                .cueText(.label)
                .foregroundStyle(theme.accentText)
        }
        .buttonStyle(.plain)
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - NotificationChannel label

extension NotificationChannel {
    /// Short label for the reminder channel segmented control.
    var reminderLabel: String {
        switch self {
        case .push: return String(localized: "reminder.channel.push")
        case .telegram: return String(localized: "reminder.channel.telegram")
        }
    }
}

// MARK: - Preview

#Preview("ReminderEditor") {
    struct Demo: View {
        @State private var reminders: [EditableReminder] = [
            EditableReminder(offset: .fifteenMinBefore, channel: .push),
            EditableReminder(offset: .oneDayBefore, channel: .telegram),
        ]
        @Environment(\.theme) private var theme
        var body: some View {
            VStack {
                ReminderEditor(reminders: $reminders)
                Spacer()
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background)
        }
    }
    return Demo()
        .environment(\.theme, AppPalette.kraftInk.colors)
}
