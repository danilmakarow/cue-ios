//
//  RecurrenceEditor.swift
//  cue
//

import SwiftUI

/// Full recurrence editor. Binds a `RecurrenceRuleInput?`; nil means "no
/// recurrence" (Repeat: Off). Used by `NewEventScreen`, `TaskEditScreen`, and
/// the Groups editor.
///
/// Layout: Repeat picker → if not Off: interval stepper, weekday picker (weekly
/// only), End picker (never / on date / after N occurrences).
struct RecurrenceEditor: View {
    @Binding var recurrence: RecurrenceRuleInput?

    // Internal form state — kept in sync with the binding via `onChange`.
    @State private var frequency: RecurrenceFrequency = .weekly
    @State private var interval: Int = 1
    @State private var selectedWeekdays: Set<Int> = []
    @State private var endType: RecurrenceEndType = .never
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var occurrenceCount: Int = 10

    var body: some View {
        Form {
            Section {
                Picker("recurrence.frequency.label", selection: frequencyBinding) {
                    Text("recurrence.off").tag(Optional<RecurrenceFrequency>.none)
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { freq in
                        Text(freq.localizedLabel).tag(Optional(freq))
                    }
                }
            }

            if recurrence != nil {
                Section(String(localized: "recurrence.interval.section")) {
                    Stepper(
                        intervalLabel,
                        value: $interval,
                        in: 1...99
                    )
                    .onChange(of: interval) { _, _ in updateBinding() }
                }

                if frequency == .weekly {
                    Section(String(localized: "recurrence.weekdays.section")) {
                        weekdayGrid
                    }
                }

                Section(String(localized: "recurrence.end.section")) {
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
                }

                Section {
                    Text(summaryLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "recurrence.editor.title"))
        .onAppear { loadFromBinding() }
    }

    // MARK: - Frequency binding (bridges Optional<RecurrenceFrequency>)

    private var frequencyBinding: Binding<RecurrenceFrequency?> {
        Binding(
            get: { recurrence == nil ? nil : frequency },
            set: { newValue in
                if let newValue {
                    frequency = newValue
                    if recurrence == nil {
                        // Turning on — build a default rule.
                        interval = 1
                        selectedWeekdays = []
                        endType = .never
                    }
                    updateBinding()
                } else {
                    recurrence = nil
                }
            }
        )
    }

    // MARK: - Weekday grid

    private var weekdayGrid: some View {
        let days: [(Int, LocalizedStringKey)] = [
            (0, "recurrence.weekday.mon"),
            (1, "recurrence.weekday.tue"),
            (2, "recurrence.weekday.wed"),
            (3, "recurrence.weekday.thu"),
            (4, "recurrence.weekday.fri"),
            (5, "recurrence.weekday.sat"),
            (6, "recurrence.weekday.sun"),
        ]
        return HStack(spacing: 6) {
            ForEach(days, id: \.0) { dayIndex, label in
                weekdayChip(index: dayIndex, label: label)
            }
        }
        .padding(.vertical, 4)
    }

    private func weekdayChip(index: Int, label: LocalizedStringKey) -> some View {
        let isSelected = selectedWeekdays.contains(index)
        return Button {
            if isSelected {
                selectedWeekdays.remove(index)
            } else {
                selectedWeekdays.insert(index)
            }
            updateBinding()
        } label: {
            Text(label)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

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

    // MARK: - Binding sync

    private func loadFromBinding() {
        guard let rule = recurrence else { return }
        frequency = rule.frequency
        interval = rule.interval
        selectedWeekdays = Set(rule.byWeekday ?? [])
        endType = rule.endType
        if let countVal = rule.count { occurrenceCount = countVal }
        if let dateStr = rule.endDate,
           let parsed = Self.dateFromString(dateStr) {
            endDate = parsed
        }
    }

    private func updateBinding() {
        let weekdays: [Int]? = frequency == .weekly && !selectedWeekdays.isEmpty
            ? Array(selectedWeekdays).sorted()
            : nil
        let endDateStr: String? = endType == .untilDate
            ? Self.stringFromDate(endDate)
            : nil
        let countVal: Int? = endType == .count ? occurrenceCount : nil
        recurrence = RecurrenceRuleInput(
            frequency: frequency,
            interval: interval,
            byWeekday: weekdays,
            byMonthDay: nil,
            byMonth: nil,
            endType: endType,
            endDate: endDateStr,
            count: countVal
        )
    }

    private static func stringFromDate(_ date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d",
            comps.year ?? 2026, comps.month ?? 1, comps.day ?? 1)
    }

    private static func dateFromString(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: str)
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

        // Base: every N frequency
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

        // Weekday suffix
        if frequency == .weekly, let weekdays = byWeekday, !weekdays.isEmpty {
            let names = weekdays.sorted().compactMap { index -> String? in
                guard (0...6).contains(index) else { return nil }
                return Self.weekdayName(index)
            }
            if !names.isEmpty {
                let joined = names.joined(separator: ", ")
                parts.append(String(format: String(localized: "recurrence.summary.on"), joined))
            }
        }

        var result = parts.joined(separator: " ")

        // End suffix
        switch endType {
        case .never:
            break
        case .untilDate:
            if let dateStr = endDate {
                result += " · \(dateStr)"
            }
        case .count:
            if let countVal = count {
                result += " · \(String(format: String(localized: "recurrence.summary.forCount"), countVal))"
            }
        }
        return result
    }

    private static func weekdayName(_ index: Int) -> String? {
        // 0=Mon, 1=Tue, … 6=Sun
        let names = [
            String(localized: "recurrence.weekday.mon"),
            String(localized: "recurrence.weekday.tue"),
            String(localized: "recurrence.weekday.wed"),
            String(localized: "recurrence.weekday.thu"),
            String(localized: "recurrence.weekday.fri"),
            String(localized: "recurrence.weekday.sat"),
            String(localized: "recurrence.weekday.sun"),
        ]
        guard index < names.count else { return nil }
        return names[index]
    }
}
