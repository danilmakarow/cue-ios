//
//  GroupEditSnapshotTests.swift
//  cueTests
//
//  Storybook-style snapshot tests for `GroupEditSheet` — the modal that
//  creates or edits a task group (name + color + icon + requires-completion
//  toggle + default recurrence). Two states per the design reference
//  (Group Edit.dc.html):
//    • new  — create mode: empty fields, "New Group" title, Save disabled
//    • edit — edit mode: a pre-filled group (name, preset color, icon,
//             requires-completion on, weekly default recurrence) populated via
//             `populateFromDTO` from an `existingDTO`
//
//  `TaskGroupDTO` exposes only a custom `init(from:)`, so the edit fixture is
//  decoded from inline JSON via an ISO-8601 `JSONDecoder` (mirroring `APIClient`)
//  — the only valid construction path.
//

import SwiftData
import SwiftUI
import Testing
@testable import cue

@MainActor
struct GroupEditSnapshotTests {
    /// ISO-8601 decoder matching `APIClient`'s strategy, used to build the
    /// `TaskGroupDTO` fixture through its decoder-only init.
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Decodes a `TaskGroupDTO` from wire JSON (force-try: a decode failure here
    /// is a test bug, not a runtime path).
    private static func decodeGroup(_ json: String) -> TaskGroupDTO {
        try! makeDecoder().decode(TaskGroupDTO.self, from: Data(json.utf8))
    }

    // MARK: - New (create)

    /// Create mode: `existingDTO == nil` → empty name/color/icon, "New Group"
    /// title, the no-color and unselected-icon defaults, requires-completion off.
    /// Save is disabled while the name is blank.
    @Test func new() {
        let container = MockData.container()

        let sheet = NavigationStack {
            GroupEditSheet(existingDTO: nil, onSaved: { _ in })
        }

        #expect(
            SnapshotHarness.record(
                ScreenHost.wrap(sheet, container: container),
                named: "group-edit-new"
            ) != nil
        )
    }

    // MARK: - Edit (pre-filled)

    /// Edit mode: a fully populated `TaskGroupDTO` drives `populateFromDTO` —
    /// name "Fitness", the olive preset color (`#466234`, so its swatch shows the
    /// selected ring), the `dumbbell.fill` preset icon (selected tile), the
    /// requires-completion toggle on, and a weekly default recurrence (so the
    /// recurrence section is active and the inherit note renders).
    @Test func edit() {
        let container = MockData.container()

        let json = """
        {
          "id": "grp-fitness",
          "calendarId": "cal-1",
          "name": "Fitness",
          "color": "#466234",
          "icon": "dumbbell.fill",
          "sortOrder": 2,
          "requiresCompletion": true,
          "defaultRecurrenceRuleId": "rule-fitness",
          "recurrence": {
            "id": "rule-fitness",
            "frequency": "WEEKLY",
            "interval": 1,
            "byWeekday": [0, 2, 4],
            "byMonthDay": null,
            "byMonth": null,
            "bySetPos": null,
            "monthlyAnchor": null,
            "endType": "NEVER",
            "endDate": null,
            "count": null
          },
          "defaultNotificationStrategyId": null,
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-01T00:00:00Z"
        }
        """
        let dto = Self.decodeGroup(json)

        let sheet = NavigationStack {
            GroupEditSheet(existingDTO: dto, onSaved: { _ in })
        }

        #expect(
            SnapshotHarness.record(
                ScreenHost.wrap(sheet, container: container),
                named: "group-edit-edit"
            ) != nil
        )
    }
}
