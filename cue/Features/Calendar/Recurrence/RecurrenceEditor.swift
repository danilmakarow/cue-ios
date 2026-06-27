//
//  RecurrenceEditor.swift
//  cue
//

import SwiftUI

/// MONTHLY sub-mode the editor offers when the frequency is `.monthly`.
/// Drives which fields the rule carries and enforces the cross-field rules on
/// ``RecurrenceRuleInput`` (only one of day-of-month / nth-weekday / workday-anchor
/// is ever populated at a time).
enum MonthlyMode: String, CaseIterable, Identifiable, Sendable {
    /// Fixed day(s) of the month — `byMonthDay`.
    case onDay
    /// nth weekday — `bySetPos` + a single `byWeekday`.
    case onThe
    /// Working-day anchor — `monthlyAnchor`.
    case workday

    var id: String { rawValue }

    var label: String {
        switch self {
        case .onDay: return String(localized: "recurrence.monthly.onDay")
        case .onThe: return String(localized: "recurrence.monthly.onThe")
        case .workday: return String(localized: "recurrence.monthly.workday")
        }
    }
}

/// nth-weekday ordinal for the "On the …" monthly mode. Maps to RFC-5545
/// `BYSETPOS` values (1…4 = first…fourth, -1 = last).
enum NthPosition: Int, CaseIterable, Identifiable, Sendable {
    case first = 1
    case second = 2
    case third = 3
    case fourth = 4
    case last = -1

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .first: return String(localized: "recurrence.nth.first")
        case .second: return String(localized: "recurrence.nth.second")
        case .third: return String(localized: "recurrence.nth.third")
        case .fourth: return String(localized: "recurrence.nth.fourth")
        case .last: return String(localized: "recurrence.nth.last")
        }
    }
}

/// Full recurrence editor. Binds a `RecurrenceRuleInput?`; nil means "no
/// recurrence" (Repeat: Off). Used by `NewEventScreen`, `TaskEditScreen`, and
/// the Groups editor.
///
/// Layout: Repeat picker → if not Off: interval stepper, weekday picker (weekly),
/// monthly mode (day / nth-weekday / workday-anchor) when monthly, month picker
/// (yearly), End picker (never / on date / after N occurrences).
struct RecurrenceEditor: View {
    @Environment(\.theme) private var theme

    @Binding var recurrence: RecurrenceRuleInput?

    // Internal form state — kept in sync with the binding via `updateBinding`.
    @State private var frequency: RecurrenceFrequency = .weekly
    @State private var interval: Int = 1
    @State private var selectedWeekdays: Set<Int> = []
    // Monthly sub-state.
    @State private var monthlyMode: MonthlyMode = .onDay
    @State private var selectedMonthDays: Set<Int> = [1]
    @State private var nthPosition: NthPosition = .first
    @State private var nthWeekday: Int = 0
    @State private var monthlyAnchor: MonthlyAnchorMode = .firstWorkday
    // Yearly sub-state — 1…12.
    @State private var selectedMonths: Set<Int> = [Calendar.current.component(.month, from: .now)]
    // End sub-state.
    @State private var endType: RecurrenceEndType = .never
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var occurrenceCount: Int = 10

    var body: some View {
        Form {
            frequencySection

            if recurrence != nil {
                intervalSection

                if frequency == .weekly {
                    weeklySection
                }

                if frequency == .monthly {
                    monthlyModeSection
                    monthlyDetailSection
                }

                if frequency == .yearly {
                    yearlySection
                }

                endSection
                summarySection
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(String(localized: "recurrence.editor.title"))
        .onAppear { loadFromBinding() }
    }

    // MARK: - Frequency

    private var frequencySection: some View {
        Section {
            Picker("recurrence.frequency.label", selection: frequencyBinding) {
                Text("recurrence.off").tag(Optional<RecurrenceFrequency>.none)
                ForEach(RecurrenceFrequency.allCases, id: \.self) { freq in
                    Text(freq.localizedLabel).tag(Optional(freq))
                }
            }
        }
    }

    private var frequencyBinding: Binding<RecurrenceFrequency?> {
        Binding(
            get: { recurrence == nil ? nil : frequency },
            set: { newValue in
                guard let newValue else {
                    recurrence = nil
                    return
                }
                let turningOn = recurrence == nil
                frequency = newValue
                if turningOn {
                    interval = 1
                    selectedWeekdays = []
                    endType = .never
                }
                updateBinding()
            }
        )
    }

    // MARK: - Interval

    private var intervalSection: some View {
        Section {
            Stepper(intervalLabel, value: $interval, in: 1...99)
                .onChange(of: interval) { _, _ in updateBinding() }
        } header: {
            sectionHeader("recurrence.interval.section")
        }
    }

    // MARK: - Weekly

    private var weeklySection: some View {
        Section {
            weekdayGrid
        } header: {
            sectionHeader("recurrence.weekdays.section")
        }
    }

    private var weekdayGrid: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Self.weekdays, id: \.index) { day in
                weekdayChip(index: day.index, label: day.label)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func weekdayChip(index: Int, label: String) -> some View {
        CueChip(
            label,
            isSelected: selectedWeekdays.contains(index),
            action: {
                toggle(&selectedWeekdays, index)
                updateBinding()
            }
        )
        .frame(maxWidth: .infinity)
    }

    // MARK: - Monthly

    private var monthlyModeSection: some View {
        Section {
            SegmentedControl(
                selection: Binding(
                    get: { monthlyMode },
                    set: { monthlyMode = $0; updateBinding() }
                ),
                options: MonthlyMode.allCases,
                label: \.label
            )
            .padding(.vertical, Spacing.xs)
        } header: {
            sectionHeader("recurrence.monthly.section")
        }
    }

    @ViewBuilder
    private var monthlyDetailSection: some View {
        switch monthlyMode {
        case .onDay:
            Section {
                monthDayGrid
            } header: {
                sectionHeader("recurrence.monthly.onDay.header")
            }
        case .onThe:
            Section {
                nthPositionGrid
                nthWeekdayGrid
            } header: {
                sectionHeader("recurrence.monthly.onThe.header")
            }
        case .workday:
            Section {
                workdayPicker
            } header: {
                sectionHeader("recurrence.monthly.workday.header")
            }
        }
    }

    /// 1…31 day-of-month tiles — `byMonthDay`.
    private var monthDayGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 7), spacing: Spacing.xs) {
            ForEach(1...31, id: \.self) { day in
                monthDayTile(day)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func monthDayTile(_ day: Int) -> some View {
        let isSelected = selectedMonthDays.contains(day)
        return Button {
            toggle(&selectedMonthDays, day)
            updateBinding()
        } label: {
            Text("\(day)")
                .cueText(.codeSmall)
                .foregroundStyle(isSelected ? theme.onAccent : theme.textSecondary)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: Radius.tight, style: .continuous)
                        .fill(isSelected ? theme.success : theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tight, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    /// first / second / … / last ordinal picker — `bySetPos`.
    private var nthPositionGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 5), spacing: Spacing.xs) {
            ForEach(NthPosition.allCases) { position in
                pill(
                    label: position.label,
                    isSelected: nthPosition == position,
                    mono: false
                ) {
                    nthPosition = position
                    updateBinding()
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    /// Single weekday for the nth-weekday rule — the one `byWeekday` entry.
    private var nthWeekdayGrid: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Self.weekdays, id: \.index) { day in
                pill(label: day.label, isSelected: nthWeekday == day.index, mono: true) {
                    nthWeekday = day.index
                    updateBinding()
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    /// Working-day anchor radio list — `monthlyAnchor`.
    private var workdayPicker: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(MonthlyAnchorMode.allCases, id: \.self) { anchor in
                workdayRow(anchor)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func workdayRow(_ anchor: MonthlyAnchorMode) -> some View {
        let isSelected = monthlyAnchor == anchor
        return Button {
            monthlyAnchor = anchor
            updateBinding()
        } label: {
            HStack {
                Text(anchor.label)
                    .cueText(.callout)
                    .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.accentText)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .fill(isSelected ? theme.fillSelected : theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Yearly

    private var yearlySection: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 6), spacing: Spacing.xs) {
                ForEach(1...12, id: \.self) { month in
                    monthTile(month)
                }
            }
            .padding(.vertical, Spacing.xs)
        } header: {
            sectionHeader("recurrence.yearly.section")
        }
    }

    private func monthTile(_ month: Int) -> some View {
        let isSelected = selectedMonths.contains(month)
        return Button {
            toggle(&selectedMonths, month)
            updateBinding()
        } label: {
            Text(Self.monthAbbreviations[month - 1])
                .cueText(.codeSmall)
                .foregroundStyle(isSelected ? theme.onAccent : theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.tight, style: .continuous)
                        .fill(isSelected ? theme.success : theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tight, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - End

    private var endSection: some View {
        Section {
            Picker("recurrence.end.label", selection: $endType) {
                Text("recurrence.end.never").tag(RecurrenceEndType.never)
                Text("recurrence.end.onDate").tag(RecurrenceEndType.untilDate)
                Text("recurrence.end.afterCount").tag(RecurrenceEndType.count)
            }
            .onChange(of: endType) { _, _ in updateBinding() }

            switch endType {
            case .never:
                EmptyView()
            case .untilDate:
                DatePicker(
                    "recurrence.end.date",
                    selection: $endDate,
                    in: Date.now...,
                    displayedComponents: .date
                )
                .onChange(of: endDate) { _, _ in updateBinding() }
            case .count:
                Stepper(
                    String(format: String(localized: "recurrence.end.count.format"), occurrenceCount),
                    value: $occurrenceCount,
                    in: 1...999
                )
                .onChange(of: occurrenceCount) { _, _ in updateBinding() }
            }
        } header: {
            sectionHeader("recurrence.end.section")
        }
    }

    private var summarySection: some View {
        Section {
            Text(summaryLine)
                .cueText(.callout)
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .cueText(.label)
            .textCase(nil)
            .foregroundStyle(theme.textSecondary)
    }

    /// A small selectable pill used by the nth-position and nth-weekday rows.
    private func pill(label: String, isSelected: Bool, mono: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .cueText(mono ? .codeSmall : .caption)
                .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        .fill(isSelected ? theme.fillSelected : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var intervalLabel: String {
        let unit: String
        switch frequency {
        case .daily: unit = String(localized: "recurrence.interval.day")
        case .weekly: unit = String(localized: "recurrence.interval.week")
        case .monthly: unit = String(localized: "recurrence.interval.month")
        case .yearly: unit = String(localized: "recurrence.interval.year")
        }
        return String(format: String(localized: "recurrence.interval.format"), interval, unit)
    }

    /// Human-readable summary for display in the form.
    var summaryLine: String {
        recurrence?.humanSummary ?? String(localized: "recurrence.off")
    }

    /// Toggles membership of `value` in `set`.
    private func toggle(_ set: inout Set<Int>, _ value: Int) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private static let weekdays: [(index: Int, label: String)] = [
        (0, String(localized: "recurrence.weekday.mon")),
        (1, String(localized: "recurrence.weekday.tue")),
        (2, String(localized: "recurrence.weekday.wed")),
        (3, String(localized: "recurrence.weekday.thu")),
        (4, String(localized: "recurrence.weekday.fri")),
        (5, String(localized: "recurrence.weekday.sat")),
        (6, String(localized: "recurrence.weekday.sun")),
    ]

    private static let monthAbbreviations: [String] = [
        String(localized: "month.abbr.jan"), String(localized: "month.abbr.feb"),
        String(localized: "month.abbr.mar"), String(localized: "month.abbr.apr"),
        String(localized: "month.abbr.may"), String(localized: "month.abbr.jun"),
        String(localized: "month.abbr.jul"), String(localized: "month.abbr.aug"),
        String(localized: "month.abbr.sep"), String(localized: "month.abbr.oct"),
        String(localized: "month.abbr.nov"), String(localized: "month.abbr.dec"),
    ]

    // MARK: - Binding sync

    private func loadFromBinding() {
        guard let rule = recurrence else { return }
        frequency = rule.frequency
        interval = rule.interval
        selectedWeekdays = Set(rule.byWeekday ?? [])

        // Reconstruct the monthly sub-mode from the populated fields.
        if rule.frequency == .monthly {
            if let anchor = rule.monthlyAnchor {
                monthlyMode = .workday
                monthlyAnchor = anchor
            } else if let positions = rule.bySetPos, let first = positions.first,
                      let weekday = rule.byWeekday?.first {
                monthlyMode = .onThe
                nthPosition = NthPosition(rawValue: first) ?? .first
                nthWeekday = weekday
            } else {
                monthlyMode = .onDay
                if let days = rule.byMonthDay, !days.isEmpty {
                    selectedMonthDays = Set(days)
                }
            }
        }

        if rule.frequency == .yearly, let months = rule.byMonth, !months.isEmpty {
            selectedMonths = Set(months)
        }

        endType = rule.endType
        if let countVal = rule.count { occurrenceCount = countVal }
        if let dateStr = rule.endDate, let parsed = Self.dateFromString(dateStr) {
            endDate = parsed
        }
    }

    /// Rebuilds the bound `RecurrenceRuleInput` from the current form state,
    /// applying the cross-field rules: only one monthly selector is ever
    /// populated, `bySetPos` always rides with a single `byWeekday`, and the
    /// `monthlyAnchor` path clears every other monthly field.
    private func updateBinding() {
        var byWeekday: [Int]?
        var byMonthDay: [Int]?
        var byMonth: [Int]?
        var bySetPos: [Int]?
        var anchor: MonthlyAnchorMode?

        switch frequency {
        case .daily:
            break
        case .weekly:
            byWeekday = selectedWeekdays.isEmpty ? nil : selectedWeekdays.sorted()
        case .monthly:
            switch monthlyMode {
            case .onDay:
                byMonthDay = selectedMonthDays.isEmpty ? nil : selectedMonthDays.sorted()
            case .onThe:
                // bySetPos REQUIRES a non-empty byWeekday — always pair them.
                bySetPos = [nthPosition.rawValue]
                byWeekday = [nthWeekday]
            case .workday:
                // monthlyAnchor is mutually exclusive with every other selector.
                anchor = monthlyAnchor
            }
        case .yearly:
            byMonth = selectedMonths.isEmpty ? nil : selectedMonths.sorted()
        }

        let endDateStr: String? = endType == .untilDate ? Self.stringFromDate(endDate) : nil
        let countVal: Int? = endType == .count ? occurrenceCount : nil

        recurrence = RecurrenceRuleInput(
            frequency: frequency,
            interval: interval,
            byWeekday: byWeekday,
            byMonthDay: byMonthDay,
            byMonth: byMonth,
            bySetPos: bySetPos,
            monthlyAnchor: anchor,
            endType: endType,
            endDate: endDateStr,
            count: countVal
        )
    }

    private static func stringFromDate(_ date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 2026, comps.month ?? 1, comps.day ?? 1)
    }

    private static func dateFromString(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: str)
    }
}

// MARK: - MonthlyAnchorMode display

extension MonthlyAnchorMode {
    /// Long localized label for the working-day anchor radio rows.
    var label: String {
        switch self {
        case .firstWorkday: return String(localized: "recurrence.workday.first")
        case .lastWorkday: return String(localized: "recurrence.workday.last")
        case .dayBeforeLastWorkday: return String(localized: "recurrence.workday.beforeLast")
        }
    }
}

// MARK: - RecurrenceFrequency display

extension RecurrenceFrequency {
    /// Short localized label for pickers.
    var localizedLabel: LocalizedStringKey {
        switch self {
        case .daily: return "recurrence.frequency.daily"
        case .weekly: return "recurrence.frequency.weekly"
        case .monthly: return "recurrence.frequency.monthly"
        case .yearly: return "recurrence.frequency.yearly"
        }
    }
}

// MARK: - RecurrenceRuleInput summary

extension RecurrenceRuleInput {
    /// Human-readable summary, e.g. "Every 2 weeks on Mon, Wed — until Jan 1, 2027".
    var humanSummary: String {
        var parts: [String] = []

        let unit: String
        switch frequency {
        case .daily: unit = interval == 1
            ? String(localized: "recurrence.summary.day")
            : String(localized: "recurrence.summary.days")
        case .weekly: unit = interval == 1
            ? String(localized: "recurrence.summary.week")
            : String(localized: "recurrence.summary.weeks")
        case .monthly: unit = interval == 1
            ? String(localized: "recurrence.summary.month")
            : String(localized: "recurrence.summary.months")
        case .yearly: unit = interval == 1
            ? String(localized: "recurrence.summary.year")
            : String(localized: "recurrence.summary.years")
        }
        if interval == 1 {
            parts.append(String(format: String(localized: "recurrence.summary.every"), unit))
        } else {
            parts.append(String(format: String(localized: "recurrence.summary.everyN"), interval, unit))
        }

        // Weekly: weekday suffix.
        if frequency == .weekly, let weekdays = byWeekday, !weekdays.isEmpty {
            let names = weekdays.sorted().compactMap { Self.weekdayName($0) }
            if !names.isEmpty {
                parts.append(String(format: String(localized: "recurrence.summary.on"), names.joined(separator: ", ")))
            }
        }

        // Monthly: nth-weekday / workday-anchor / day-of-month suffix.
        if frequency == .monthly {
            if let anchor = monthlyAnchor {
                parts.append(anchor.summaryFragment)
            } else if let positions = bySetPos, let position = positions.first,
                      let weekday = byWeekday?.first,
                      let name = Self.weekdayName(weekday),
                      let nth = NthPosition(rawValue: position) {
                parts.append(String(format: String(localized: "recurrence.summary.onThe"), nth.label, name))
            } else if let days = byMonthDay, !days.isEmpty {
                let joined = days.sorted().map(String.init).joined(separator: ", ")
                parts.append(String(format: String(localized: "recurrence.summary.onDay"), joined))
            }
        }

        var result = parts.joined(separator: " ")

        switch endType {
        case .never:
            break
        case .untilDate:
            if let dateStr = endDate { result += " · \(dateStr)" }
        case .count:
            if let countVal = count {
                result += " · \(String(format: String(localized: "recurrence.summary.forCount"), countVal))"
            }
        }
        return result
    }

    private static func weekdayName(_ index: Int) -> String? {
        let names = [
            String(localized: "recurrence.weekday.mon"),
            String(localized: "recurrence.weekday.tue"),
            String(localized: "recurrence.weekday.wed"),
            String(localized: "recurrence.weekday.thu"),
            String(localized: "recurrence.weekday.fri"),
            String(localized: "recurrence.weekday.sat"),
            String(localized: "recurrence.weekday.sun"),
        ]
        guard (0..<names.count).contains(index) else { return nil }
        return names[index]
    }
}

private extension MonthlyAnchorMode {
    /// Inline fragment for the recurrence summary line.
    var summaryFragment: String {
        switch self {
        case .firstWorkday: return String(localized: "recurrence.summary.workday.first")
        case .lastWorkday: return String(localized: "recurrence.summary.workday.last")
        case .dayBeforeLastWorkday: return String(localized: "recurrence.summary.workday.beforeLast")
        }
    }
}

// MARK: - Preview

#Preview("RecurrenceEditor — monthly") {
    struct Demo: View {
        @State private var rule: RecurrenceRuleInput? = RecurrenceRuleInput(
            frequency: .monthly,
            interval: 1,
            byWeekday: [0],
            byMonthDay: nil,
            byMonth: nil,
            bySetPos: [1],
            monthlyAnchor: nil,
            endType: .never,
            endDate: nil,
            count: nil
        )
        var body: some View {
            NavigationStack {
                RecurrenceEditor(recurrence: $rule)
            }
        }
    }
    return Demo()
        .environment(\.theme, AppPalette.kraftInk.colors)
}
