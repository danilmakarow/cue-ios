//
//  PersonaSnapshotTests.swift
//  cueTests
//
//  Storybook-style snapshot suite for `PersonaEditorView` (the AI-assistant
//  persona editor pushed from Settings → "AI Assistant").
//
//  How we reach the loaded editor (no network, no settle timing):
//  `PersonaEditorView` now accepts a store via `init(store:)` (defaulting to a
//  fresh `PersonaStore()` for the app's runtime path). Tests build a store that is
//  already `.loaded` via the DEBUG-only `PersonaStore.previewLoaded(active:presets:)`
//  factory and inject it, so the editor renders its settled content on the first
//  layout — no `URLProtocol` stub, no async cold load, no `settle:` window.
//
//  The injected `active.source` drives WHICH editor state renders, both statically
//  reachable on load (see `PersonaEditorView.syncFromActive`):
//    • source == .preset → locked/read-only preset well, PRESET tag, "Customize
//      this preset" helper.  → "persona-preset"
//    • source == .custom → unlocked `TextEditor`, CUSTOM tag, "Reset to preset"
//      → the custom-editing state.  → "persona-custom-edit"
//

import Foundation
import SwiftUI
import Testing
@testable import cue

@MainActor
struct PersonaSnapshotTests {
    // MARK: - Fixtures

    /// A realistic Jarvis-style preset persona used as the seeded preset and the
    /// body of the preset chip row.
    private static let jarvisPrompt = """
    You are a calm, dry-witted British butler assistant. Address the user as \
    "sir". Be impeccably polite and understated, flag bad ideas gently, and keep \
    answers concise and genuinely useful underneath the voice.
    """

    /// A second preset so the chip row shows more than one option.
    private static let coachPrompt = """
    You are an upbeat accountability coach. Keep me moving with short, punchy \
    nudges, celebrate small wins, and never let a task slip without a follow-up.
    """

    /// A user-authored custom persona, used to drive the custom-editing state.
    private static let customPrompt = """
    Talk to me like a terse senior engineer in standup: bullet the plan, surface \
    risks first, skip the pleasantries, and ping me the moment anything is blocked.
    """

    /// The curated preset list both states render around.
    private func presets() -> [PersonaPresetDTO] {
        [
            PersonaPresetDTO(id: "preset_jarvis", presetName: "Jarvis", promptText: Self.jarvisPrompt),
            PersonaPresetDTO(id: "preset_coach", presetName: "Coach", promptText: Self.coachPrompt),
        ]
    }

    /// The active `PersonaSettingsDTO` for the given source.
    private func active(source: PersonaPromptSource) -> PersonaSettingsDTO {
        switch source {
        case .preset:
            return PersonaSettingsDTO(promptText: Self.jarvisPrompt, source: .preset, presetName: "Jarvis")
        case .custom:
            return PersonaSettingsDTO(promptText: Self.customPrompt, source: .custom, presetName: nil)
        }
    }

    // MARK: - Harness

    /// Builds a `PersonaStore` already `.loaded` with the given source's active
    /// persona + presets, injects it into `PersonaEditorView(store:)`, wraps the
    /// screen in the full app environment, and records the PNG. No async load and
    /// no settle timing — the editor renders its settled content directly.
    private func record(named name: String, source: PersonaPromptSource) {
        let store = PersonaStore.previewLoaded(active: active(source: source), presets: presets())

        let container = MockData.container()
        let screen = NavigationStack {
            PersonaEditorView(store: store)
        }
        let hosted = ScreenHost.wrap(screen, container: container)
        #expect(SnapshotHarness.record(hosted, named: name) != nil)
    }

    // MARK: - Tests

    /// Default state: the active persona is a seeded preset, so the editor loads
    /// locked — read-only well with the PRESET tag, the preset chip row (Jarvis /
    /// Coach / Custom), the "This preset is read-only" helper, and the pinned
    /// "Save persona" CTA disabled.
    @Test
    func personaPreset() {
        record(named: "persona-preset", source: .preset)
    }

    /// Custom-editing state: the active persona is the user's custom text, so
    /// `syncFromActive` opens straight into editing — unlocked `TextEditor`, the
    /// CUSTOM tag, live character count, the active "Custom" chip, and the
    /// "Reset to preset" destructive action under the Save CTA.
    @Test
    func personaCustomEdit() {
        record(named: "persona-custom-edit", source: .custom)
    }
}
