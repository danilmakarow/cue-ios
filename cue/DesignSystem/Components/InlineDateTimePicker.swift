//
//  InlineDateTimePicker.swift
//  cue
//
//  An inline, expandable date/time well. The collapsed row reads as a receipt:
//  an eyebrow label on the left, the value in the mono "recorded by the system"
//  voice on the right, with a chevron that rotates when the well is open. Tapping
//  expands the row to reveal a graphical/wheel `DatePicker` in place — no sheet,
//  no navigation. React analogy: a `<DateField label mode value onChange>` that
//  expands inline.
//

import SwiftUI

/// What a `InlineDateTimePicker` lets the user edit.
enum DateTimePickerMode {
    /// Calendar date only.
    case date
    /// Wall-clock time only.
    case time
    /// Both date and time.
    case dateAndTime
}

/// An inline expandable date/time well styled to Clean. The collapsed row shows
/// an `.label` eyebrow and the value as mono receipt text (`.code`); tapping it
/// expands the well to reveal a graphical (date) or wheel (time) `DatePicker`.
/// The whole well is a recessed `surfaceSunken` card with a hairline edge that
/// deepens to clay while open.
struct InlineDateTimePicker: View {
    @Environment(\.theme) private var theme
    @State private var isExpanded = false

    private let label: String
    @Binding private var date: Date
    private let mode: DateTimePickerMode

    /// - Parameters:
    ///   - label: the eyebrow label on the collapsed row.
    ///   - date: the bound date/time value.
    ///   - mode: which components are editable (default `.dateAndTime`).
    init(
        label: String,
        date: Binding<Date>,
        mode: DateTimePickerMode = .dateAndTime
    ) {
        self.label = label
        self._date = date
        self.mode = mode
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
    }

    /// The `DatePicker` components implied by the well's mode.
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
            return date.formatted(.dateTime.day().month(.abbreviated).year())
        case .time:
            return date.formatted(.dateTime.hour().minute())
        case .dateAndTime:
            return date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            collapsedRow

            if isExpanded {
                Divider()
                    .overlay(theme.separator)
                picker
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
            }
        }
        .background(shape.fill(theme.surfaceSunken))
        .overlay(shape.strokeBorder(isExpanded ? theme.primary : theme.border, lineWidth: 1))
        .clipShape(shape)
        .animation(.easeOut(duration: 0.16), value: isExpanded)
    }

    private var collapsedRow: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: Spacing.sm) {
                Text(label.uppercased())
                    .cueText(.label)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text(receipt)
                    .cueText(.code)
                    .foregroundStyle(theme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.md)
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

// MARK: - Preview

#Preview("InlineDateTimePicker") {
    struct Demo: View {
        @State private var starts = Date()
        @State private var dueDate = Date()
        @State private var alarm = Date()
        var body: some View {
            VStack(spacing: Spacing.xl) {
                InlineDateTimePicker(label: "Starts", date: $starts, mode: .dateAndTime)
                InlineDateTimePicker(label: "Due", date: $dueDate, mode: .date)
                InlineDateTimePicker(label: "Reminder", date: $alarm, mode: .time)
            }
            .padding(Spacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: 0xFFFFFF))
        }
    }
    return Demo()
        .environment(\.theme, AppPalette.kraftInk.colors)
}
