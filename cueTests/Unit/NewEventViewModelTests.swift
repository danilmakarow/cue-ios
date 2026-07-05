//
//  NewEventViewModelTests.swift
//  cueTests
//
//  Unit tests for NewEventViewModel form-state derivation:
//  duration/end syncing via didSet, canSubmit validation, and applyDraft prefill.
//

import Foundation
import Testing
@testable import cue

@MainActor
struct NewEventViewModelTests {

    // MARK: - Fixtures

    /// Builds a fixed reference date so duration math is deterministic.
    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(identifier: "UTC")
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: components) ?? .now
    }

    /// Decodes a `TaskDraftDTO` from a JSON fixture, mirroring how the wire DTO is
    /// produced in production (decoder-only, never a memberwise init).
    private func decodeDraft(_ json: String) throws -> TaskDraftDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try #require(json.data(using: .utf8))
        return try decoder.decode(TaskDraftDTO.self, from: data)
    }

    // MARK: - EventDuration

    @Test func eventDurationSecondsIsRawValueTimesSixty() {
        #expect(EventDuration.fiveMin.seconds == 300)
        #expect(EventDuration.oneHour.seconds == 3600)
        #expect(EventDuration.threeHours.seconds == 10800)
        for duration in EventDuration.allCases {
            #expect(duration.seconds == TimeInterval(duration.rawValue * 60))
        }
    }

    // MARK: - startAt didSet → endAt sync

    @Test func settingStartAtRecomputesEndFromActiveDuration() {
        let viewModel = NewEventViewModel()
        // Default duration is .oneHour.
        let start = makeDate(year: 2026, month: 6, day: 28, hour: 9, minute: 0)
        viewModel.startAt = start
        #expect(viewModel.endAt == start.addingTimeInterval(EventDuration.oneHour.seconds))
    }

    @Test func settingStartAtDoesNotMoveEndWhenDurationIsNil() {
        let viewModel = NewEventViewModel()
        viewModel.useClassicPicker = true // nils duration
        #expect(viewModel.duration == nil)

        let fixedEnd = makeDate(year: 2026, month: 6, day: 28, hour: 18, minute: 0)
        viewModel.endAt = fixedEnd
        let start = makeDate(year: 2026, month: 6, day: 28, hour: 9, minute: 0)
        viewModel.startAt = start
        // No active duration → endAt is left untouched (free editing).
        #expect(viewModel.endAt == fixedEnd)
    }

    // MARK: - duration didSet → endAt sync

    @Test func changingDurationRecomputesEndFromCurrentStart() {
        let viewModel = NewEventViewModel()
        let start = makeDate(year: 2026, month: 6, day: 28, hour: 10, minute: 0)
        viewModel.startAt = start

        viewModel.duration = .thirtyMin
        #expect(viewModel.endAt == start.addingTimeInterval(EventDuration.thirtyMin.seconds))

        viewModel.duration = .twoHours
        #expect(viewModel.endAt == start.addingTimeInterval(EventDuration.twoHours.seconds))
    }

    // MARK: - useClassicPicker didSet

    @Test func enablingClassicPickerNilsDuration() {
        let viewModel = NewEventViewModel()
        #expect(viewModel.duration == .oneHour)
        viewModel.useClassicPicker = true
        #expect(viewModel.duration == nil)
    }

    @Test func disablingClassicPickerRestoresOneHourWhenDurationWasNil() {
        let viewModel = NewEventViewModel()
        viewModel.useClassicPicker = true
        #expect(viewModel.duration == nil)

        viewModel.useClassicPicker = false
        #expect(viewModel.duration == .oneHour)
    }

    @Test func disablingClassicPickerKeepsExistingDuration() {
        let viewModel = NewEventViewModel()
        // Pick a non-default duration while not in classic mode.
        viewModel.duration = .fifteenMin
        // useClassicPicker is false already; set it false again — duration is
        // non-nil so it must be left as-is.
        viewModel.useClassicPicker = false
        #expect(viewModel.duration == .fifteenMin)
    }

    // MARK: - canSubmit

    @Test func canSubmitFalseWhenTitleBlank() {
        let viewModel = NewEventViewModel()
        #expect(viewModel.canSubmit == false)
    }

    @Test func canSubmitFalseWhenTitleWhitespaceOnly() {
        let viewModel = NewEventViewModel()
        viewModel.title = "   "
        #expect(viewModel.canSubmit == false)
    }

    @Test func canSubmitTrueWithNonBlankTitle() {
        let viewModel = NewEventViewModel()
        viewModel.title = "Dentist"
        #expect(viewModel.canSubmit == true)
    }

    @Test func canSubmitFalseWhileSubmitting() {
        let viewModel = NewEventViewModel()
        viewModel.title = "Dentist"
        viewModel.isSubmitting = true
        #expect(viewModel.canSubmit == false)
    }

    // MARK: - applyDraft

    @Test func applyDraftOverwritesTitle() throws {
        let viewModel = NewEventViewModel()
        viewModel.title = "old"
        let draft = try decodeDraft(#"{"title":"Buy milk"}"#)
        viewModel.applyDraft(draft)
        #expect(viewModel.title == "Buy milk")
    }

    @Test func applyDraftParsesStartAndClearsAllDay() throws {
        let viewModel = NewEventViewModel()
        viewModel.isAllDay = true
        let draft = try decodeDraft(#"{"title":"Standup","start":"2026-06-28T09:30:00Z"}"#)
        viewModel.applyDraft(draft)

        let expected = try #require(QuickCreateWell.parseISO("2026-06-28T09:30:00Z"))
        #expect(viewModel.isAllDay == false)
        #expect(viewModel.startAt == expected)
    }

    @Test func applyDraftLeavesStartUntouchedWhenAbsent() throws {
        let viewModel = NewEventViewModel()
        let original = makeDate(year: 2030, month: 1, day: 1, hour: 8, minute: 0)
        viewModel.startAt = original
        let draft = try decodeDraft(#"{"title":"Timeless todo"}"#)
        viewModel.applyDraft(draft)
        #expect(viewModel.startAt == original)
    }

    @Test func applyDraftMapsPresetDurationMinutesToEnum() throws {
        let viewModel = NewEventViewModel()
        let draft = try decodeDraft(
            #"{"title":"Call","start":"2026-06-28T09:00:00Z","durationMinutes":30}"#
        )
        viewModel.applyDraft(draft)

        let start = try #require(QuickCreateWell.parseISO("2026-06-28T09:00:00Z"))
        #expect(viewModel.duration == .thirtyMin)
        #expect(viewModel.endAt == start.addingTimeInterval(TimeInterval(30 * 60)))
    }

    @Test func applyDraftNonPresetDurationYieldsNilDurationButStillSetsEnd() throws {
        let viewModel = NewEventViewModel()
        // 25 is not a preset EventDuration raw value.
        let draft = try decodeDraft(
            #"{"title":"Odd","start":"2026-06-28T09:00:00Z","durationMinutes":25}"#
        )
        viewModel.applyDraft(draft)

        let start = try #require(QuickCreateWell.parseISO("2026-06-28T09:00:00Z"))
        #expect(viewModel.duration == nil)
        #expect(viewModel.endAt == start.addingTimeInterval(TimeInterval(25 * 60)))
    }

    @Test func applyDraftAppliesRecurrenceWhenPresent() throws {
        let viewModel = NewEventViewModel()
        let json = """
        {
          "title":"Weekly sync",
          "recurrence":{
            "frequency":"WEEKLY",
            "interval":1,
            "byWeekday":[1],
            "byMonthDay":null,
            "byMonth":null,
            "endType":"NEVER",
            "endDate":null,
            "count":null
          }
        }
        """
        let draft = try decodeDraft(json)
        viewModel.applyDraft(draft)

        let recurrence = try #require(viewModel.recurrenceInput)
        #expect(recurrence.frequency == .weekly)
        #expect(recurrence.interval == 1)
        #expect(recurrence.byWeekday == [1])
        #expect(recurrence.endType == .never)
    }

    @Test func applyDraftLeavesRecurrenceUntouchedWhenAbsent() throws {
        let viewModel = NewEventViewModel()
        let existing = RecurrenceRuleInput(
            frequency: .daily,
            interval: 2,
            byWeekday: nil,
            byMonthDay: nil,
            byMonth: nil,
            endType: .never,
            endDate: nil,
            count: nil
        )
        viewModel.recurrenceInput = existing
        let draft = try decodeDraft(#"{"title":"No repeat stated"}"#)
        viewModel.applyDraft(draft)
        #expect(viewModel.recurrenceInput == existing)
    }

    @Test func applyDraftAppliesGroupIdWhenPresent() throws {
        let viewModel = NewEventViewModel()
        let draft = try decodeDraft(#"{"title":"Chore","groupId":"grp-123"}"#)
        viewModel.applyDraft(draft)
        #expect(viewModel.selectedGroupId == "grp-123")
    }

    @Test func applyDraftLeavesGroupIdUntouchedWhenAbsent() throws {
        let viewModel = NewEventViewModel()
        viewModel.selectedGroupId = "existing-group"
        let draft = try decodeDraft(#"{"title":"No group"}"#)
        viewModel.applyDraft(draft)
        #expect(viewModel.selectedGroupId == "existing-group")
    }

    @Test func applyDraftLeavesOmittedFieldsUntouched() throws {
        let viewModel = NewEventViewModel()
        viewModel.notes = "keep me"
        viewModel.requiresCompletion = true
        viewModel.icon = "star"
        let draft = try decodeDraft(#"{"title":"Minimal"}"#)
        viewModel.applyDraft(draft)

        #expect(viewModel.notes == "keep me")
        #expect(viewModel.requiresCompletion == true)
        #expect(viewModel.icon == "star")
    }
}
