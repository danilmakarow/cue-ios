//
//  PersonaEditorView.swift
//  cue
//

import SwiftUI

/// Assistant Persona editor — edit the AI persona prompt that shapes how the
/// assistant talks (tone, verbosity, formatting), pick from presets, and reset to
/// the default persona.
///
/// Pushed from `SettingsView` ("AI Assistant" row) within the Settings tab's
/// `NavigationStack`. Takes no arguments; the feature team will read/write the
/// persona via the appropriate store/endpoint from the environment.
///
// TODO(4c): Assistant workstream builds this out — a multi-line persona prompt
// editor (`CueField`), a row of preset `CueChip`s, a character/usage hint, and a
// destructive "Reset to default". Wire load/save through the assistant store.
struct PersonaEditorView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        EmptyStateView(
            title: String(localized: "assistant.persona.title"),
            message: String(localized: "assistant.persona.placeholder.message"),
            systemImage: "sparkles"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("assistant.persona.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PersonaEditorView()
    }
    .environment(\.theme, AppPalette.kraftInk.colors)
}
