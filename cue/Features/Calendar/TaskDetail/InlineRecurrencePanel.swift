//
//  InlineRecurrencePanel.swift
//  cue
//

import SwiftUI

// MARK: - Inline recurrence panel

/// Reusable inline-expanding recurrence card shared by the rebuilt Event Edit and
/// Group Edit flows. A "Repeat" toggle row; turning it on expands an in-card
/// editor — Frequency segments, an Every-N stepper, weekly weekday chips, and an
/// Ends selector — within the same white card (the design's inline panel, not a
/// pushed sheet). Advanced monthly / yearly detail routes to the shared
/// `RecurrenceEditor` via a "More options" row, so this panel never duplicates the
/// monthly matrix nor edits the shared component. Binds the same
/// `RecurrenceRuleInput?` the save path reads.
struct InlineRecurrencePanel: View {
    @Environment(\.theme) private var theme

    @Binding var recurrence: RecurrenceRuleInput?

    @State private var showAdvanced = false

    private static let weekdays: [(index: Int, label: String)] = [
        (0, String(localized: "recurrence.weekday.mon")),
        (1, String(localized: "recurrence.weekday.tue")),
        (2, String(localized: "recurrence.weekday.wed")),
        (3, String(localized: "recurrence.weekday.thu")),
        (4, String(localized: "recurrence.weekday.fri")),
        (5, String(localized: "recurrence.weekday.sat")),
        (6, String(localized: "recurrence.weekday.sun")),
    ]

    var body: some View {
        CueCard(padding: 0) {
            VStack(spacing: 0) {
                toggleRow
                if let rule = recurrence {
                    Divider().overlay(theme.separator)
                    expanded(rule: rule)
                }
            }
        }
        .sheet(isPresented: $showAdvanced) {
            NavigationStack {
                RecurrenceEditor(recurrence: $recurrence)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(String(localized: "common.done")) { showAdvanced = false }
                        }
                    }
            }
        }
    }

    private var toggleRow: some View {
        HStack {
            Text("recurrence.label")
                .cueText(.body)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            CueToggle(
                isOn: Binding(
                    get: { recurrence != nil },
                    set: { isOn in
                        withAnimation(.snappy) {
                            recurrence = isOn ? Self.defaultRule() : nil
                        }
                    }
                ),
                accessibilityLabel: String(localized: "recurrence.label")
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private func expanded(rule: RecurrenceRuleInput) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text(String(localized: "recurrence.section.title"))
                .cueText(.label)
                .foregroundStyle(theme.textSecondary)

            frequencyRow(rule: rule)
            intervalRow(rule: rule)

            if rule.frequency == .weekly {
                weekdayRow(rule: rule)
            }

            if rule.frequency == .monthly || rule.frequency == .yearly {
                advancedRow
            }

            Divider().overlay(theme.separator)
            endsRow(rule: rule)

            Text(rule.humanSummary)
                .cueText(.codeSmall)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(Spacing.lg)
    }

    private func frequencyRow(rule: RecurrenceRuleInput) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("recurrence.frequency.label")
                .cueText(.body)
                .foregroundStyle(theme.textPrimary)
            SegmentedControl(
                selection: Binding(
                    get: { rule.frequency },
                    set: { setFrequency($0, from: rule) }
                ),
                options: RecurrenceFrequency.allCases,
                label: { $0.shortLabel }
            )
        }
    }

    private func intervalRow(rule: RecurrenceRuleInput) -> some View {
        HStack {
            Text("recurrence.interval.section")
                .cueText(.body)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            CueStepper(
                label: intervalLabel(rule: rule),
                onDecrement: { setInterval(max(1, rule.interval - 1), from: rule) },
                onIncrement: { setInterval(min(99, rule.interval + 1), from: rule) }
            )
        }
    }

    private func weekdayRow(rule: RecurrenceRuleInput) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("recurrence.weekdays.section")
                .cueText(.body)
                .foregroundStyle(theme.textPrimary)
            HStack(spacing: Spacing.xs) {
                ForEach(Self.weekdays, id: \.index) { day in
                    let selected = Set(rule.byWeekday ?? []).contains(day.index)
                    CueChip(
                        day.label,
                        isSelected: selected,
                        selection: .accent
                    ) {
                        toggleWeekday(day.index, in: rule)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var advancedRow: some View {
        Button {
            showAdvanced = true
        } label: {
            HStack {
                Text(String(localized: "taskEdit.recurrence.moreOptions", defaultValue: "More options"))
                    .cueText(.body)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .cueText(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func endsRow(rule: RecurrenceRuleInput) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("recurrence.end.section")
                .cueText(.body)
                .foregroundStyle(theme.textPrimary)
            SegmentedControl(
                selection: Binding(
                    get: { rule.endType },
                    set: { setEndType($0, from: rule) }
                ),
                options: RecurrenceEndType.allCases,
                label: \.shortLabel
            )
            if rule.endType != .never {
                advancedRow
            }
        }
    }

    // MARK: - Mutation helpers

    /// The default rule when Repeat is first switched on: weekly, interval 1.
    private static func defaultRule() -> RecurrenceRuleInput {
        RecurrenceRuleInput(
            frequency: .weekly,
            interval: 1,
            byWeekday: nil,
            byMonthDay: nil,
            byMonth: nil,
            bySetPos: nil,
            monthlyAnchor: nil,
            endType: .never,
            endDate: nil,
            count: nil
        )
    }

    /// Sets the interval, rebuilding the (mostly `let`) rule struct.
    private func setInterval(_ interval: Int, from rule: RecurrenceRuleInput) {
        recurrence = RecurrenceRuleInput(
            frequency: rule.frequency,
            interval: interval,
            byWeekday: rule.byWeekday,
            byMonthDay: rule.byMonthDay,
            byMonth: rule.byMonth,
            bySetPos: rule.bySetPos,
            monthlyAnchor: rule.monthlyAnchor,
            endType: rule.endType,
            endDate: rule.endDate,
            count: rule.count
        )
    }

    /// Changes frequency, clearing the now-irrelevant by-fields so the rule stays
    /// internally consistent (the shared editor handles the advanced monthly/yearly
    /// fields when the user opens "More options").
    private func setFrequency(_ frequency: RecurrenceFrequency, from rule: RecurrenceRuleInput) {
        recurrence = RecurrenceRuleInput(
            frequency: frequency,
            interval: rule.interval,
            byWeekday: frequency == .weekly ? rule.byWeekday : nil,
            byMonthDay: nil,
            byMonth: nil,
            bySetPos: nil,
            monthlyAnchor: nil,
            endType: rule.endType,
            endDate: rule.endDate,
            count: rule.count
        )
    }

    private func setEndType(_ endType: RecurrenceEndType, from rule: RecurrenceRuleInput) {
        let date = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
        recurrence = RecurrenceRuleInput(
            frequency: rule.frequency,
            interval: rule.interval,
            byWeekday: rule.byWeekday,
            byMonthDay: rule.byMonthDay,
            byMonth: rule.byMonth,
            bySetPos: rule.bySetPos,
            monthlyAnchor: rule.monthlyAnchor,
            endType: endType,
            endDate: endType == .untilDate ? (rule.endDate ?? Self.dateString(date)) : rule.endDate,
            count: endType == .count ? (rule.count ?? 10) : rule.count
        )
    }

    private func toggleWeekday(_ index: Int, in rule: RecurrenceRuleInput) {
        var days = Set(rule.byWeekday ?? [])
        if days.contains(index) { days.remove(index) } else { days.insert(index) }
        recurrence = RecurrenceRuleInput(
            frequency: rule.frequency,
            interval: rule.interval,
            byWeekday: days.isEmpty ? nil : days.sorted(),
            byMonthDay: rule.byMonthDay,
            byMonth: rule.byMonth,
            bySetPos: rule.bySetPos,
            monthlyAnchor: rule.monthlyAnchor,
            endType: rule.endType,
            endDate: rule.endDate,
            count: rule.count
        )
    }

    private func intervalLabel(rule: RecurrenceRuleInput) -> String {
        let unit: String
        switch rule.frequency {
        case .daily: unit = String(localized: "recurrence.interval.day")
        case .weekly: unit = String(localized: "recurrence.interval.week")
        case .monthly: unit = String(localized: "recurrence.interval.month")
        case .yearly: unit = String(localized: "recurrence.interval.year")
        }
        return String(format: String(localized: "recurrence.interval.format"), rule.interval, unit)
    }

    private static func dateString(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 2026, comps.month ?? 1, comps.day ?? 1)
    }
}

// MARK: - Stepper control

/// A compact −/value/+ stepper styled to Clean (recessed gray pill, mono value).
/// Used by `InlineRecurrencePanel`'s interval row.
private struct CueStepper: View {
    @Environment(\.theme) private var theme

    let label: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            button("minus", action: onDecrement)
            Text(label)
                .cueText(.codeSmall)
                .foregroundStyle(theme.textPrimary)
                .frame(minWidth: 64)
            button("plus", action: onIncrement)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                .fill(theme.surfaceSunken)
        )
    }

    private func button(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Short labels for inline controls

private extension RecurrenceFrequency {
    /// Short segment label for the inline frequency switch.
    var shortLabel: String {
        switch self {
        case .daily: return String(localized: "recurrence.frequency.daily")
        case .weekly: return String(localized: "recurrence.frequency.weekly")
        case .monthly: return String(localized: "recurrence.frequency.monthly")
        case .yearly: return String(localized: "recurrence.frequency.yearly")
        }
    }
}

private extension RecurrenceEndType {
    /// Short segment label for the inline Ends switch.
    var shortLabel: String {
        switch self {
        case .never: return String(localized: "recurrence.end.never")
        case .untilDate: return String(localized: "recurrence.end.onDate")
        case .count: return String(localized: "recurrence.end.afterCount")
        }
    }
}
