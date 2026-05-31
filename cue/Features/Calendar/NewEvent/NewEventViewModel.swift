//
//  NewEventViewModel.swift
//  cue
//

import Foundation

/// Preset event durations offered as horizontal chips when all-day is off.
enum EventDuration: Int, CaseIterable, Identifiable, Sendable {
    case fiveMin = 5
    case tenMin = 10
    case fifteenMin = 15
    case thirtyMin = 30
    case fortyFiveMin = 45
    case oneHour = 60
    case ninetyMin = 90
    case twoHours = 120
    case threeHours = 180

    var id: Int { rawValue }

    /// Duration expressed as a `TimeInterval` (seconds).
    var seconds: TimeInterval { TimeInterval(rawValue * 60) }

    /// Short label for chip buttons.
    var label: String {
        switch self {
        case .fiveMin: return "5m"
        case .tenMin: return "10m"
        case .fifteenMin: return "15m"
        case .thirtyMin: return "30m"
        case .fortyFiveMin: return "45m"
        case .oneHour: return "1h"
        case .ninetyMin: return "1.5h"
        case .twoHours: return "2h"
        case .threeHours: return "3h"
        }
    }
}

/// Form state + submission logic for `NewEventView`.
@Observable
final class NewEventViewModel {
    // MARK: Stored state
    var title: String = ""
    var notes: String = ""
    var startAt: Date = Date.nextFullHour() {
        didSet { syncEndFromDuration() }
    }
    var endAt: Date = Date.nextFullHour().addingTimeInterval(3600)
    var isAllDay: Bool = false
    var requiresCompletion: Bool = false

    /// Selected preset duration. Nil when user is in classic mode and freely edits `endAt`.
    var duration: EventDuration? = .oneHour {
        didSet { syncEndFromDuration() }
    }

    /// When true, shows the original start + end `DatePicker` pair instead of chips.
    var useClassicPicker: Bool = false {
        didSet {
            if useClassicPicker {
                duration = nil
            } else if duration == nil {
                duration = .fifteenMin
            }
        }
    }

    var isSubmitting: Bool = false
    var errorMessage: String?

    // MARK: Private
    private let api: APIClient

    // MARK: Init
    init(api: APIClient = .shared) {
        self.api = api
    }

    // MARK: Public computed
    /// Whether the form is valid enough to submit.
    var canSubmit: Bool {
        guard !isSubmitting else { return false }
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return true
    }

    // MARK: Public methods

    /// Submits the form. Returns the created task on success (so the caller
    /// can upsert it into SwiftData for immediate display), or nil on failure.
    @MainActor
    func submit() async -> TaskDTO? {
        guard canSubmit else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let calendarId = try await ensureDefaultCalendar()
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let request = CreateTaskRequest(
                calendarId: calendarId,
                title: title.trimmingCharacters(in: .whitespaces),
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                startAt: startAt,
                endAt: isAllDay ? nil : endAt,
                isAllDay: isAllDay,
                timezone: TimeZone.current.identifier,
                requiresCompletion: requiresCompletion
            )
            let created: TaskDTO = try await api.post("/tasks", body: request)
            return created
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    /// Clears any error message currently surfaced to the UI.
    func clearError() {
        errorMessage = nil
    }

    // MARK: Private helpers

    /// Recomputes `endAt` from `startAt + duration` when a preset duration is active.
    private func syncEndFromDuration() {
        guard let duration else { return }
        endAt = startAt.addingTimeInterval(duration.seconds)
    }

    /// Fetches existing calendars; creates a "Default" one if none exist; returns its id.
    private func ensureDefaultCalendar() async throws -> String {
        let calendars: [CalendarDTO] = try await api.get("/calendars")
        if let firstCalendar = calendars.first {
            return firstCalendar.id
        }
        let created: CalendarDTO = try await api.post(
            "/calendars",
            body: CreateCalendarRequest(name: "Default", color: nil, icon: nil)
        )
        return created.id
    }
}

private extension Date {
    /// The start of the next full hour after now.
    static func nextFullHour() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        guard let currentHourStart = calendar.date(from: components) else { return now }
        return calendar.date(byAdding: .hour, value: 1, to: currentHourStart) ?? now
    }
}
