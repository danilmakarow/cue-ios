//
//  CalendarGroupUpsertTests.swift
//  cueTests
//
//  Covers the cache-mirror upsert mapping for EventCalendar (from CalendarDTO)
//  and EventTaskGroup (from TaskGroupDTO). These upserts back every sync path,
//  so field mapping + id-keyed idempotency are load-bearing.
//

import Foundation
import SwiftData
import Testing
@testable import cue

@MainActor
struct CalendarGroupUpsertTests {

    // MARK: - Fixture helpers

    /// Spins up an isolated in-memory store for the cache-mirror @Model types.
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: EventCalendar.self, TaskItem.self, EventTaskGroup.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// Decodes a `CalendarDTO` from a JSON fixture; the type uses synthesized
    /// Codable, but we still go through the decoder to mirror the wire path.
    private func decodeCalendar(_ json: String) throws -> CalendarDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = json.data(using: .utf8) else {
            throw DecodeFixtureError.invalidUTF8
        }
        return try decoder.decode(CalendarDTO.self, from: data)
    }

    /// Decodes a `TaskGroupDTO` through its custom `init(from:)`. The DTO is
    /// decoder-only, so this is the only valid construction path.
    private func decodeGroup(_ json: String) throws -> TaskGroupDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = json.data(using: .utf8) else {
            throw DecodeFixtureError.invalidUTF8
        }
        return try decoder.decode(TaskGroupDTO.self, from: data)
    }

    private enum DecodeFixtureError: Error {
        case invalidUTF8
    }

    /// Builds a calendar fixture JSON string with overridable fields.
    private func calendarJSON(
        id: String = "cal-1",
        name: String = "Work",
        color: String? = "#FF0000",
        icon: String? = "briefcase",
        sortOrder: Int = 3,
        createdAt: String = "2026-01-01T00:00:00Z",
        updatedAt: String = "2026-01-02T00:00:00Z"
    ) -> String {
        let colorField = color.map { "\"\($0)\"" } ?? "null"
        let iconField = icon.map { "\"\($0)\"" } ?? "null"
        return """
        {
          "id": "\(id)",
          "ownerId": "owner-1",
          "name": "\(name)",
          "color": \(colorField),
          "icon": \(iconField),
          "sortOrder": \(sortOrder),
          "createdAt": "\(createdAt)",
          "updatedAt": "\(updatedAt)"
        }
        """
    }

    // MARK: - EventCalendar upsert

    @Test func calendarUpsertMapsAllFields() throws {
        let context = try makeContext()
        let dto = try decodeCalendar(calendarJSON())

        let calendar = EventCalendar.upsert(from: dto, in: context)
        try context.save()

        #expect(calendar.id == "cal-1")
        #expect(calendar.name == "Work")
        #expect(calendar.colorHex == "#FF0000") // colorHex <- dto.color
        #expect(calendar.icon == "briefcase")
        #expect(calendar.sortOrder == 3)
        #expect(calendar.createdAt == ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z"))
        #expect(calendar.updatedAt == ISO8601DateFormatter().date(from: "2026-01-02T00:00:00Z"))
    }

    @Test func calendarUpsertMapsNilColorAndIcon() throws {
        let context = try makeContext()
        let dto = try decodeCalendar(calendarJSON(color: nil, icon: nil))

        let calendar = EventCalendar.upsert(from: dto, in: context)

        #expect(calendar.colorHex == nil)
        #expect(calendar.icon == nil)
    }

    @Test func calendarUpsertSameIdUpdatesInPlace() throws {
        let context = try makeContext()

        _ = EventCalendar.upsert(from: try decodeCalendar(calendarJSON(name: "Work", sortOrder: 1)), in: context)
        try context.save()

        let afterInsert = try context.fetch(FetchDescriptor<EventCalendar>())
        #expect(afterInsert.count == 1)

        // Same id, changed fields -> overwrite in place, count stays 1.
        _ = EventCalendar.upsert(
            from: try decodeCalendar(calendarJSON(name: "Personal", color: "#00FF00", sortOrder: 9)),
            in: context
        )
        try context.save()

        let afterUpdate = try context.fetch(FetchDescriptor<EventCalendar>())
        #expect(afterUpdate.count == 1)
        #expect(afterUpdate.first?.name == "Personal")
        #expect(afterUpdate.first?.colorHex == "#00FF00")
        #expect(afterUpdate.first?.sortOrder == 9)
    }

    @Test func calendarUpsertDistinctIdsInsertTwoRows() throws {
        let context = try makeContext()

        _ = EventCalendar.upsert(from: try decodeCalendar(calendarJSON(id: "cal-1")), in: context)
        _ = EventCalendar.upsert(from: try decodeCalendar(calendarJSON(id: "cal-2")), in: context)
        try context.save()

        let rows = try context.fetch(FetchDescriptor<EventCalendar>())
        #expect(rows.count == 2)
        #expect(Set(rows.map(\.id)) == ["cal-1", "cal-2"])
    }

    // MARK: - TaskGroupDTO decoding edge cases

    @Test func groupDecodeAbsentRequiresCompletionIsNil() throws {
        // requiresCompletion key entirely absent -> nil, NOT false.
        let json = """
        {
          "id": "grp-1",
          "calendarId": "cal-1",
          "name": "Errands",
          "color": "BLUE",
          "icon": "cart",
          "sortOrder": 0,
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-01T00:00:00Z"
        }
        """
        let dto = try decodeGroup(json)
        #expect(dto.requiresCompletion == nil)
    }

    @Test func groupDecodeExplicitRequiresCompletionPreserved() throws {
        let jsonTrue = """
        {
          "id": "grp-t",
          "calendarId": "cal-1",
          "name": "Strict",
          "color": null,
          "icon": null,
          "sortOrder": 0,
          "requiresCompletion": true,
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-01T00:00:00Z"
        }
        """
        let jsonFalse = """
        {
          "id": "grp-f",
          "calendarId": "cal-1",
          "name": "Loose",
          "color": null,
          "icon": null,
          "sortOrder": 0,
          "requiresCompletion": false,
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-01T00:00:00Z"
        }
        """
        #expect(try decodeGroup(jsonTrue).requiresCompletion == true)
        #expect(try decodeGroup(jsonFalse).requiresCompletion == false)
    }

    @Test func groupDecodePresetColorNamePassesThroughVerbatim() throws {
        // colorHex is documented as "NOT always a hex": a TaskColor preset name
        // (e.g. "BLUE") must pass through unchanged, not be coerced.
        let json = """
        {
          "id": "grp-c",
          "calendarId": "cal-1",
          "name": "Preset",
          "color": "BLUE",
          "icon": null,
          "sortOrder": 0,
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-01T00:00:00Z"
        }
        """
        let dto = try decodeGroup(json)
        #expect(dto.color == "BLUE")
    }

    // MARK: - EventTaskGroup upsert

    @Test func groupUpsertMapsAllFields() throws {
        let context = try makeContext()
        let json = """
        {
          "id": "grp-1",
          "calendarId": "cal-42",
          "name": "Shopping",
          "color": "BLUE",
          "icon": "cart",
          "sortOrder": 5,
          "requiresCompletion": true,
          "defaultRecurrenceRuleId": "rule-9",
          "createdAt": "2026-03-01T00:00:00Z",
          "updatedAt": "2026-03-02T00:00:00Z"
        }
        """
        let dto = try decodeGroup(json)

        let group = EventTaskGroup.upsert(from: dto, in: context)
        try context.save()

        #expect(group.id == "grp-1")
        #expect(group.calendarId == "cal-42")
        #expect(group.name == "Shopping")
        #expect(group.colorHex == "BLUE") // colorHex <- dto.color (preset name verbatim)
        #expect(group.icon == "cart")
        #expect(group.sortOrder == 5)
        #expect(group.requiresCompletion == true)
        #expect(group.defaultRecurrenceRuleId == "rule-9")
        #expect(group.createdAt == ISO8601DateFormatter().date(from: "2026-03-01T00:00:00Z"))
        #expect(group.updatedAt == ISO8601DateFormatter().date(from: "2026-03-02T00:00:00Z"))
    }

    @Test func groupUpsertAbsentRequiresCompletionMapsToNil() throws {
        let context = try makeContext()
        let json = """
        {
          "id": "grp-2",
          "calendarId": "cal-1",
          "name": "Optional",
          "color": null,
          "icon": null,
          "sortOrder": 0,
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-01T00:00:00Z"
        }
        """
        let group = EventTaskGroup.upsert(from: try decodeGroup(json), in: context)

        #expect(group.requiresCompletion == nil)
        #expect(group.defaultRecurrenceRuleId == nil)
        #expect(group.colorHex == nil)
        #expect(group.icon == nil)
    }

    @Test func groupUpsertSameIdUpdatesInPlace() throws {
        let context = try makeContext()

        let firstJSON = """
        {
          "id": "grp-x",
          "calendarId": "cal-1",
          "name": "Before",
          "color": "BLUE",
          "icon": null,
          "sortOrder": 1,
          "requiresCompletion": false,
          "defaultRecurrenceRuleId": null,
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-01T00:00:00Z"
        }
        """
        _ = EventTaskGroup.upsert(from: try decodeGroup(firstJSON), in: context)
        try context.save()

        let afterInsert = try context.fetch(FetchDescriptor<EventTaskGroup>())
        #expect(afterInsert.count == 1)

        // Same id, every field changed -> overwritten in place.
        let secondJSON = """
        {
          "id": "grp-x",
          "calendarId": "cal-2",
          "name": "After",
          "color": "RED",
          "icon": "star",
          "sortOrder": 7,
          "requiresCompletion": true,
          "defaultRecurrenceRuleId": "rule-1",
          "createdAt": "2026-02-01T00:00:00Z",
          "updatedAt": "2026-02-02T00:00:00Z"
        }
        """
        _ = EventTaskGroup.upsert(from: try decodeGroup(secondJSON), in: context)
        try context.save()

        let afterUpdate = try context.fetch(FetchDescriptor<EventTaskGroup>())
        #expect(afterUpdate.count == 1)
        let row = afterUpdate.first
        #expect(row?.calendarId == "cal-2")
        #expect(row?.name == "After")
        #expect(row?.colorHex == "RED")
        #expect(row?.icon == "star")
        #expect(row?.sortOrder == 7)
        #expect(row?.requiresCompletion == true)
        #expect(row?.defaultRecurrenceRuleId == "rule-1")
    }

    @Test func groupUpsertDistinctIdsInsertTwoRows() throws {
        let context = try makeContext()

        let makeJSON: (String) -> String = { id in
            """
            {
              "id": "\(id)",
              "calendarId": "cal-1",
              "name": "G",
              "color": null,
              "icon": null,
              "sortOrder": 0,
              "createdAt": "2026-01-01T00:00:00Z",
              "updatedAt": "2026-01-01T00:00:00Z"
            }
            """
        }
        _ = EventTaskGroup.upsert(from: try decodeGroup(makeJSON("grp-a")), in: context)
        _ = EventTaskGroup.upsert(from: try decodeGroup(makeJSON("grp-b")), in: context)
        try context.save()

        let rows = try context.fetch(FetchDescriptor<EventTaskGroup>())
        #expect(rows.count == 2)
        #expect(Set(rows.map(\.id)) == ["grp-a", "grp-b"])
    }
}
