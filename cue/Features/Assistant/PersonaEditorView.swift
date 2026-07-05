//
//  PersonaEditorView.swift
//  cue
//

import SwiftUI

/// Assistant Persona editor — view and edit the AI persona prompt that shapes
/// how the Telegram assistant talks (tone, verbosity, formatting), pick from
/// curated presets as starting points, save a custom persona, and reset back to
/// the seeded preset.
///
/// Pushed from `SettingsView` ("AI Assistant" row) within the Settings tab's
/// `NavigationStack`. Reads / writes the persona through `PersonaStore`
/// (`@Observable @MainActor`), created locally here and bound to the global
/// `NotificationStore` for mutation banners.
///
/// Per the Assistant Persona spec: a single prompt field is the source of truth,
/// rendered read-only/muted while a preset is active (locked) and fully editable
/// once the user customizes. A receipt-voice tag (PRESET / CUSTOM) and a
/// character count sit above the well; a pinned decisive "Save persona" CTA lives
/// in the thumb zone and stamps a wax seal on success.
struct PersonaEditorView: View {
    @Environment(\.theme) private var theme
    @Environment(NotificationStore.self) private var notifications

    /// Locally-owned store: this screen is the only place the persona is edited,
    /// so the store's lifetime matches the screen (unlike `TelegramLinkStore`,
    /// which lives at app root because its deep link can arrive first). The init
    /// default keeps existing call sites (`PersonaEditorView()`) unchanged; tests
    /// pass a pre-loaded store so the editor renders its settled content without an
    /// async load.
    @State private var store: PersonaStore

    /// Seeds the locally-owned `PersonaStore`. Passing `nil` (the default) makes a
    /// fresh store that cold-loads in `.task` (the app's runtime path); a caller
    /// can supply an already-loaded store (e.g. snapshot tests) to render the
    /// settled editor directly. The store is built inside this MainActor init so
    /// the default doesn't evaluate `PersonaStore()` in a nonisolated context.
    init(store: PersonaStore? = nil) {
        _store = State(initialValue: store ?? PersonaStore())
    }

    /// The editing buffer for the custom prompt. Distinct from `store.active` so
    /// edits stay local until saved; seeded from the active persona on load and
    /// when the user switches presets / customizes.
    @State private var draft: String = ""

    /// Whether the user is in custom-editing mode (the field is unlocked). When
    /// `false`, the active preset is shown read-only.
    @State private var isCustomizing: Bool = false

    /// The preset id the user has tapped in the chip row (mirrors the active
    /// preset on load). `nil` once a custom persona is the active selection.
    @State private var selectedPresetId: String?

    /// Drives the reset-to-preset confirmation sheet.
    @State private var showResetConfirm: Bool = false

    /// Briefly true after a successful save to stamp the wax seal over the CTA.
    @State private var showSeal: Bool = false

    @FocusState private var promptFocused: Bool

    private let maxLength = 2000

    // MARK: Derived

    /// The text the field renders: the live editing buffer when customizing,
    /// otherwise the read-only active persona text.
    private var displayedText: String {
        isCustomizing ? draft : (store.active?.promptText ?? "")
    }

    /// The receipt tag shown beside the field — CUSTOM while editing, else the
    /// active persona's provenance.
    private var tagText: String {
        isCustomizing
            ? String(localized: "assistant.persona.tag.custom", defaultValue: "CUSTOM")
            : store.sourceTag
    }

    /// Live character count of whatever text the field is showing.
    private var characterCount: Int {
        displayedText.count
    }

    /// True when the draft is empty / whitespace-only — an invalid persona.
    private var isDraftEmpty: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// True when the draft exceeds the length budget the backend enforces.
    private var isOverLimit: Bool {
        characterCount > maxLength
    }

    /// Save is enabled only in custom mode with a non-empty, in-bounds draft that
    /// actually differs from the active persona, and no mutation in flight.
    private var canSave: Bool {
        guard isCustomizing, !store.isMutating else { return false }
        guard !isDraftEmpty, !isOverLimit else { return false }
        return draft != store.active?.promptText
    }

    /// The count caption colour: danger when invalid, accent near the ceiling,
    /// muted otherwise. Mirrors the spec's count treatment.
    private var countColor: Color {
        if isOverLimit || (isDraftEmpty && isCustomizing) { return theme.danger }
        if characterCount >= 1_900 { return theme.accentText }
        return theme.textSecondary
    }

    // MARK: Body

    var body: some View {
        content
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("assistant.persona.title")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                store.bind(notifications: notifications)
                if store.loadState != .loaded {
                    await store.load()
                }
                // Seed the local editing state from the active persona — both after
                // a cold load and when an already-loaded store was injected (tests /
                // re-entry), so the injected case isn't left with an empty draft.
                syncFromActive()
            }
            .confirmActionSheet(
                isPresented: $showResetConfirm,
                title: String(
                    localized: "assistant.persona.reset.confirm.title",
                    defaultValue: "Reset to preset?"
                ),
                message: String(
                    localized: "assistant.persona.reset.confirm.message",
                    defaultValue: "Your custom persona will be replaced by the default preset. This can't be undone."
                ),
                primary: ConfirmAction(
                    String(localized: "assistant.persona.reset.confirm.action", defaultValue: "Reset persona")
                ) {
                    Task { await performReset() }
                }
            )
    }

    /// True while the persona is still loading — the chrome stays mounted and the
    /// prompt well hosts a localized spinner (matching the design's in-well
    /// loading state) rather than collapsing to a full-screen loader.
    private var isLoading: Bool {
        switch store.loadState {
        case .idle, .loading: return true
        default: return false
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.loadState {
        case .idle, .loading:
            loadedContent
        case let .failed(message):
            ErrorStateView(
                title: String(
                    localized: "assistant.persona.error.load",
                    defaultValue: "Couldn't load persona"
                ),
                message: message,
                retry: { Task { await store.load(); syncFromActive() } }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            loadedContent
        }
    }

    private var loadedContent: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    header
                    presetSection
                    promptSection
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                // Leave room for the pinned CTA in the thumb zone.
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)

            saveBar
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("assistant.persona.title")
                .cueText(.displayL)
                .foregroundStyle(theme.textPrimary)
            Text(
                String(
                    localized: "assistant.persona.intro",
                    defaultValue: "Choose how your Telegram assistant speaks to you. Presets are a starting point — make it your own."
                )
            )
            .cueText(.callout)
            .foregroundStyle(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(String(localized: "assistant.persona.presets.label", defaultValue: "PRESETS"))
                .cueText(.label)
                .foregroundStyle(theme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(store.presets) { preset in
                        CueChip(
                            preset.presetName,
                            systemImage: "sparkles",
                            isSelected: !isCustomizing && selectedPresetId == preset.id,
                            selection: .neutral
                        ) {
                            selectPreset(preset)
                        }
                    }
                    CueChip(
                        String(localized: "assistant.persona.chip.custom", defaultValue: "Custom"),
                        systemImage: "plus",
                        isSelected: isCustomizing,
                        selection: .neutral
                    ) {
                        beginCustomizing()
                    }
                }
                .padding(.vertical, Spacing.xxs)
            }
            .opacity(store.isMutating ? 0.5 : 1)
            .disabled(store.isMutating)
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            promptHeaderRow
            promptWell
            if !isCustomizing {
                presetHelper
            }
        }
    }

    private var promptHeaderRow: some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Text(String(localized: "assistant.persona.prompt.label", defaultValue: "PROMPT"))
                    .cueText(.label)
                    .foregroundStyle(theme.textSecondary)
                if !isCustomizing {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                        .accessibilityHidden(true)
                }
            }

            Spacer(minLength: Spacing.sm)

            HStack(spacing: Spacing.sm) {
                Text(tagText)
                    .cueText(.codeSmall)
                    .foregroundStyle(isCustomizing ? theme.onAccent : theme.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs + 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isCustomizing ? theme.primary : theme.surfaceSunken)
                    )

                Text("\(characterCount.formatted()) / \(maxLength)")
                    .cueText(.code)
                    .foregroundStyle(countColor)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var promptWell: some View {
        // Editable well: functional 12px (`Radius.card`) corner + floating depth.
        // Locked preset well: calmer 6px corner, no depth — per the Clean spec.
        let editShape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        let lockedShape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        Group {
            if isLoading {
                // Field-level loading: chrome stays mounted, only the well shows a
                // centered spinner — mirrors the design's in-well 22px ring.
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 168)
                    .background(lockedShape.fill(theme.surfaceSunken))
                    .overlay(lockedShape.strokeBorder(theme.separator, lineWidth: 1))
                    .clipShape(lockedShape)
                    .accessibilityLabel(String(localized: "common.loading"))
            } else if isCustomizing {
                TextEditor(text: $draft)
                    .focused($promptFocused)
                    .cueText(.body)
                    .foregroundStyle(theme.textPrimary)
                    .tint(theme.primary)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.lg - 2)
                    .frame(height: 168)
                    .background(editShape.fill(theme.surfaceSunken))
                    .overlay(
                        editShape.strokeBorder(
                            promptFocused ? theme.primary : theme.border,
                            lineWidth: 1
                        )
                    )
                    .cueDepth(.valueCut, radius: Radius.card)
                    .animation(.easeOut(duration: 0.16), value: promptFocused)
            } else {
                ScrollView {
                    Text(displayedText)
                        .cueText(.body)
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.lg - 2)
                }
                .frame(height: 168)
                .background(lockedShape.fill(theme.surfaceSunken))
                .overlay(lockedShape.strokeBorder(theme.separator, lineWidth: 1))
                .clipShape(lockedShape)
                .opacity(0.92)
            }
        }
    }

    private var presetHelper: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(
                String(
                    localized: "assistant.persona.preset.helper",
                    defaultValue: "This preset is read-only. Customize it to edit."
                )
            )
            .cueText(.caption)
            .foregroundStyle(theme.textSecondary)

            Button(String(localized: "assistant.persona.customize", defaultValue: "Customize this preset")) {
                beginCustomizing()
            }
            .buttonStyle(.cue(.secondary))
        }
    }

    // MARK: Save bar (pinned thumb-zone CTA)

    private var saveBar: some View {
        VStack(spacing: Spacing.md) {
            ZStack(alignment: .topTrailing) {
                if store.isMutating {
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(theme.onAccent)
                        Text(String(localized: "assistant.persona.saving", defaultValue: "Saving…"))
                            .cueText(.bodyEmphasis)
                            .foregroundStyle(theme.onAccent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(theme.secondary)
                            .opacity(0.85)
                    )
                } else {
                    Button(String(localized: "assistant.persona.save", defaultValue: "Save persona")) {
                        Task { await performSave() }
                    }
                    .buttonStyle(.cue(.decisive))
                    .disabled(!canSave)
                }

                if showSeal {
                    WaxSeal(isStamped: true, size: 46, systemImage: "checkmark")
                        .offset(x: 4, y: -16)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }

            if isCustomizing {
                Button(
                    String(localized: "assistant.persona.reset", defaultValue: "Reset to preset"),
                    role: .destructive
                ) {
                    showResetConfirm = true
                }
                .buttonStyle(.cue(.ghost))
                .disabled(store.isMutating)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.md)
        .background(
            LinearGradient(
                colors: [theme.background.opacity(0), theme.background],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: Intent

    /// Seeds the local editing state from the freshly-loaded active persona:
    /// custom mode when the user already has custom text, else the locked preset
    /// with its chip selected.
    private func syncFromActive() {
        guard let active = store.active else { return }
        draft = active.promptText
        if active.source == .custom {
            isCustomizing = true
            selectedPresetId = nil
        } else {
            isCustomizing = false
            selectedPresetId = store.presets.first { $0.promptText == active.promptText }?.id
        }
    }

    /// Selects a preset chip: shows its text read-only and seeds the draft so a
    /// later "Customize" starts from that preset.
    private func selectPreset(_ preset: PersonaPresetDTO) {
        guard !store.isMutating else { return }
        selectedPresetId = preset.id
        isCustomizing = false
        promptFocused = false
        draft = preset.promptText
    }

    /// Enters custom-editing mode, seeding the buffer from whatever text is
    /// currently shown (the active persona or the selected preset).
    private func beginCustomizing() {
        guard !store.isMutating else { return }
        if draft.isEmpty {
            draft = store.active?.promptText ?? ""
        }
        isCustomizing = true
        selectedPresetId = nil
        promptFocused = true
    }

    /// Persists the custom draft, then stamps the wax seal briefly on success.
    private func performSave() async {
        promptFocused = false
        let saved = await store.save(promptText: draft)
        guard saved else { return }
        syncFromActive()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.6)) { showSeal = true }
        try? await Task.sleep(for: .seconds(1.6))
        withAnimation(.easeOut(duration: 0.2)) { showSeal = false }
    }

    /// Resets to the seeded preset, re-seeding the editing state from the result.
    private func performReset() async {
        promptFocused = false
        let resetText = await store.reset()
        guard resetText != nil else { return }
        syncFromActive()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PersonaEditorView()
    }
    .environment(NotificationStore())
    .environment(\.theme, AppPalette.kraftInk.colors)
}
