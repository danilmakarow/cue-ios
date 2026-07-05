//
//  ComponentSnapshotTests.swift
//  cueTests
//
//  Storybook-style snapshot tests: render shared components in isolation with
//  fixed inputs and rasterize to PNG, so the rendered design can be diffed
//  against the reference. This first suite is the harness proof — pure
//  components, no SwiftData / stores.
//

import SwiftUI
import Testing
@testable import cue

@MainActor
struct ComponentSnapshotTests {
    private var theme: ThemeColors { AppPalette.kraftInk.colors }

    /// Proof of the snapshot pipeline: the done markers + chip selection variants
    /// the foundation pass touched (OliveCheck open/done, CueChip accent/neutral).
    @Test func doneMarkersAndChips() {
        let board = VStack(alignment: .leading, spacing: 28) {
            Text("OliveCheck — open / done")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            HStack(spacing: 20) {
                OliveCheck(isDone: false, size: 28)
                OliveCheck(isDone: true, size: 28)
            }

            Text("CueChip — accent / neutral")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            HStack(spacing: 8) {
                CueChip("Recurring", isSelected: false) {}
                CueChip("All-day", isSelected: true) {}
                CueChip("Custom", isSelected: true, selection: .neutral) {}
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.background)
        .environment(\.theme, theme)

        let url = SnapshotHarness.record(
            board,
            named: "components-markers",
            size: CGSize(width: 393, height: 360)
        )
        #expect(url != nil)
    }
}
