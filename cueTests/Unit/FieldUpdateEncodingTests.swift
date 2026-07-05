//
//  FieldUpdateEncodingTests.swift
//  cueTests
//
//  Covers the tri-state PATCH encoding contract of `FieldUpdate` as exercised by
//  `UpdateTaskRequest` and `UpdateTaskGroupRequest`:
//    - .unchanged  -> key ABSENT entirely
//    - .clear      -> key PRESENT with explicit JSON null
//    - .set(value) -> key PRESENT with the value
//  Plus the plain-optional `encodeIfPresent` semantics (omit-on-nil) and the
//  "replace whole set" reminders contract (nil omits, [] emits empty array).
//

import Foundation
import Testing
@testable import cue

struct FieldUpdateEncodingTests {

    // MARK: - Helpers

    /// Encodes an `Encodable` request body and re-parses it into a loosely-typed
    /// dictionary via `JSONSerialization`. This is the ONLY way to distinguish an
    /// absent key from a key whose value is an explicit JSON `null` — `Codable`
    /// alone collapses both to "nothing".
    private func encodeToObject<Body: Encodable>(_ body: Body) throws -> [String: Any] {
        let data = try JSONEncoder().encode(body)
        let parsed = try JSONSerialization.jsonObject(with: data)
        let object = try #require(parsed as? [String: Any])
        return object
    }

    /// True when the key is present AND its value is an explicit JSON null
    /// (surfaced by `JSONSerialization` as `NSNull`).
    private func isExplicitNull(_ object: [String: Any], _ key: String) -> Bool {
        guard let value = object[key] else { return false }
        return value is NSNull
    }

    /// A minimal valid recurrence input used as a `.set` payload.
    private func sampleRecurrence() -> RecurrenceRuleInput {
        return RecurrenceRuleInput(
            frequency: .weekly,
            interval: 1,
            byWeekday: [0, 2],
            byMonthDay: nil,
            byMonth: nil,
            endType: .never,
            endDate: nil,
            count: nil
        )
    }

    // MARK: - UpdateTaskRequest.icon (FieldUpdate<String>)

    @Test func taskIconUnchangedOmitsKey() throws {
        var request = UpdateTaskRequest()
        request.icon = .unchanged

        let object = try encodeToObject(request)
        #expect(object["icon"] == nil)
    }

    @Test func taskIconClearEmitsExplicitNull() throws {
        var request = UpdateTaskRequest()
        request.icon = .clear

        let object = try encodeToObject(request)
        #expect(object.keys.contains("icon"))
        #expect(isExplicitNull(object, "icon"))
    }

    @Test func taskIconSetEmitsValue() throws {
        var request = UpdateTaskRequest()
        request.icon = .set("star.fill")

        let object = try encodeToObject(request)
        #expect(object["icon"] as? String == "star.fill")
    }

    // MARK: - UpdateTaskRequest.recurrence (FieldUpdate<RecurrenceRuleInput>)

    @Test func taskRecurrenceUnchangedOmitsKey() throws {
        var request = UpdateTaskRequest()
        request.recurrence = .unchanged

        let object = try encodeToObject(request)
        #expect(object["recurrence"] == nil)
    }

    @Test func taskRecurrenceClearEmitsExplicitNull() throws {
        var request = UpdateTaskRequest()
        request.recurrence = .clear

        let object = try encodeToObject(request)
        #expect(object.keys.contains("recurrence"))
        #expect(isExplicitNull(object, "recurrence"))
    }

    @Test func taskRecurrenceSetEmitsNestedObject() throws {
        var request = UpdateTaskRequest()
        request.recurrence = .set(sampleRecurrence())

        let object = try encodeToObject(request)
        let nested = try #require(object["recurrence"] as? [String: Any])
        #expect(nested["frequency"] as? String == "WEEKLY")
        #expect(nested["interval"] as? Int == 1)
        #expect(nested["byWeekday"] as? [Int] == [0, 2])
    }

    // MARK: - UpdateTaskGroupRequest.requiresCompletion (FieldUpdate<Bool>)

    @Test func groupRequiresCompletionUnchangedOmitsKey() throws {
        var request = UpdateTaskGroupRequest()
        request.requiresCompletion = .unchanged

        let object = try encodeToObject(request)
        #expect(object["requiresCompletion"] == nil)
    }

    @Test func groupRequiresCompletionClearEmitsExplicitNull() throws {
        var request = UpdateTaskGroupRequest()
        request.requiresCompletion = .clear

        let object = try encodeToObject(request)
        #expect(object.keys.contains("requiresCompletion"))
        #expect(isExplicitNull(object, "requiresCompletion"))
    }

    @Test func groupRequiresCompletionSetTrueEmitsValue() throws {
        var request = UpdateTaskGroupRequest()
        request.requiresCompletion = .set(true)

        let object = try encodeToObject(request)
        #expect(object["requiresCompletion"] as? Bool == true)
    }

    @Test func groupRequiresCompletionSetFalseEmitsValueNotOmitted() throws {
        // `false` must still produce a present key with `false` — not be confused
        // with omission. JSONSerialization decodes a JSON bool as NSNumber, so
        // compare against the Bool projection.
        var request = UpdateTaskGroupRequest()
        request.requiresCompletion = .set(false)

        let object = try encodeToObject(request)
        #expect(object.keys.contains("requiresCompletion"))
        #expect(isExplicitNull(object, "requiresCompletion") == false)
        #expect(object["requiresCompletion"] as? Bool == false)
    }

    // MARK: - UpdateTaskGroupRequest.recurrence (FieldUpdate<RecurrenceRuleInput>)

    @Test func groupRecurrenceUnchangedOmitsKey() throws {
        var request = UpdateTaskGroupRequest()
        request.recurrence = .unchanged

        let object = try encodeToObject(request)
        #expect(object["recurrence"] == nil)
    }

    @Test func groupRecurrenceClearEmitsExplicitNull() throws {
        var request = UpdateTaskGroupRequest()
        request.recurrence = .clear

        let object = try encodeToObject(request)
        #expect(object.keys.contains("recurrence"))
        #expect(isExplicitNull(object, "recurrence"))
    }

    @Test func groupRecurrenceSetEmitsNestedObject() throws {
        var request = UpdateTaskGroupRequest()
        request.recurrence = .set(sampleRecurrence())

        let object = try encodeToObject(request)
        let nested = try #require(object["recurrence"] as? [String: Any])
        #expect(nested["frequency"] as? String == "WEEKLY")
    }

    // MARK: - Plain-optional encodeIfPresent semantics

    @Test func taskNilTitleOmitsKey() throws {
        var request = UpdateTaskRequest()
        request.title = nil

        let object = try encodeToObject(request)
        #expect(object["title"] == nil)
    }

    @Test func taskSetTitleEmitsValue() throws {
        var request = UpdateTaskRequest()
        request.title = "Renamed"

        let object = try encodeToObject(request)
        #expect(object["title"] as? String == "Renamed")
    }

    @Test func defaultUpdateTaskRequestEncodesToEmptyObject() throws {
        // A freshly-constructed request (all optionals nil, both FieldUpdates
        // defaulting to .unchanged) must serialize to `{}` — no spurious keys.
        let request = UpdateTaskRequest()

        let object = try encodeToObject(request)
        #expect(object.isEmpty)
    }

    @Test func defaultUpdateTaskGroupRequestEncodesToEmptyObject() throws {
        let request = UpdateTaskGroupRequest()

        let object = try encodeToObject(request)
        #expect(object.isEmpty)
    }

    // MARK: - reminders "replace whole set" contract

    @Test func taskRemindersNilOmitsKey() throws {
        var request = UpdateTaskRequest()
        request.reminders = nil

        let object = try encodeToObject(request)
        #expect(object["reminders"] == nil)
    }

    @Test func taskRemindersEmptyArrayEmitsEmptyArrayKey() throws {
        // The contract: an empty array is NOT the same as nil — it means
        // "clear all reminders" and must travel as a present, empty JSON array.
        var request = UpdateTaskRequest()
        request.reminders = []

        let object = try encodeToObject(request)
        #expect(object.keys.contains("reminders"))
        let array = try #require(object["reminders"] as? [Any])
        #expect(array.isEmpty)
    }

    @Test func taskRemindersPopulatedArrayEmitsElements() throws {
        var request = UpdateTaskRequest()
        request.reminders = [
            ReminderInput(offsetMinutes: -15, channel: .push),
            ReminderInput(offsetMinutes: 30, channel: .telegram)
        ]

        let object = try encodeToObject(request)
        let array = try #require(object["reminders"] as? [[String: Any]])
        #expect(array.count == 2)
        #expect(array[0]["offsetMinutes"] as? Int == -15)
        #expect(array[0]["channel"] as? String == "PUSH")
        #expect(array[1]["channel"] as? String == "TELEGRAM")
    }

    // MARK: - FieldUpdate.from(optional:)

    @Test func fromOptionalNonNilProducesSet() throws {
        let update = FieldUpdate<String>.from(optional: "value")

        // Verify the mapped case by routing through the encoder: .set keeps the value.
        var request = UpdateTaskRequest()
        request.icon = update

        let object = try encodeToObject(request)
        #expect(object["icon"] as? String == "value")
    }

    @Test func fromOptionalNilProducesClearNotUnchanged() throws {
        // Critical contract: nil maps to .clear (explicit null), NOT .unchanged
        // (omitted). A `.unchanged` here would silently fail to clear the field.
        let update = FieldUpdate<String>.from(optional: nil)

        var request = UpdateTaskRequest()
        request.icon = update

        let object = try encodeToObject(request)
        #expect(object.keys.contains("icon"))
        #expect(isExplicitNull(object, "icon"))
    }

    @Test func fromOptionalNilBoolProducesClear() throws {
        let update = FieldUpdate<Bool>.from(optional: nil)

        var request = UpdateTaskGroupRequest()
        request.requiresCompletion = update

        let object = try encodeToObject(request)
        #expect(object.keys.contains("requiresCompletion"))
        #expect(isExplicitNull(object, "requiresCompletion"))
    }

    // MARK: - Independence: multiple fields in one body

    @Test func mixedTriStateFieldsCoexistCorrectly() throws {
        // icon set, recurrence cleared, title present, reminders omitted — all in
        // one body, to prove the per-field switch doesn't bleed across keys.
        var request = UpdateTaskRequest()
        request.title = "Mixed"
        request.icon = .set("bell")
        request.recurrence = .clear
        request.reminders = nil

        let object = try encodeToObject(request)
        #expect(object["title"] as? String == "Mixed")
        #expect(object["icon"] as? String == "bell")
        #expect(object.keys.contains("recurrence"))
        #expect(isExplicitNull(object, "recurrence"))
        #expect(object["reminders"] == nil)
    }
}
