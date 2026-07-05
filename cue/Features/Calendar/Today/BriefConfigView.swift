//
//  BriefConfigView.swift
//  cue
//

import SwiftUI

/// **Brief configuration** editor — view and edit the custom prompt that shapes
/// how the daily brief is written (tone, focus, formatting), save it, and reset
/// back to the default voice.
///
/// Pushed from `TodayView` (the "Jarvis" byline on the Today's brief card) within
/// the Today tab's `NavigationStack`. Reads / writes the prompt through
/// `BriefConfigStore` (`@Observable @MainActor`), created locally here and bound
/// to the global `NotificationStore` for mutation banners.
///
/// Structure mirrors `PersonaEditorView`: a single prompt well (a native
/// `TextEditor` at 168pt with a focus-driven border and floating depth),
/// scrollable content over a pinned decisive "Save configuration" CTA that stamps
/// a wax seal on success, plus a destructive "Reset to default" ghost.
struct BriefConfigView: View {
    @Environment(\.theme) private var theme
    @Environment(NotificationStore.self) private var notifications

    /// Locally-owned store: this screen is the only place the brief prompt is
    /// edited, so the store's lifetime matches the screen. The init default keeps
    /// call sites (`BriefConfigView()`) unchanged; tests pass a pre-loaded store so
    /// the editor renders its settled content without an async load.
    @State private var store: BriefConfigStore

    /// Seeds the locally-owned `BriefConfigStore`. Passing `nil` (the default)
    /// makes a fresh store that cold-loads in `.task` (the app's runtime path); a
    /// caller can supply an already-loaded store (e.g. snapshot tests) to render
    /// the settled editor directly. The store is built inside this MainActor init
    /// so the default doesn't evaluate `BriefConfigStore()` in a nonisolated
    /// context.
    init(store: BriefConfigStore? = nil) {
        _store = State(initialValue: store ?? BriefConfigStore())
    }

    /// The editing buffer for the custom prompt. Distinct from `store.customPrompt`
    /// so edits stay local until saved; seeded from the loaded prompt on `.task`.
    @State private var draft: String = ""

    /// Drives the reset-to-default confirmation sheet.
    @State private var showResetConfirm: Bool = false

    /// Briefly true after a successful save to stamp the wax seal over the CTA.
    @State private var showSeal: Bool = false

    @FocusState private var promptFocused: Bool

    private let maxLength = 2000

    // MARK: Derived

    /// The draft trimmed of surrounding whitespace/newlines — the exact value the
    /// backend persists and length-checks. Kept as a single source so the counter,
    /// the over-limit gate, and the save payload all agree on the same string.
    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Live character count of the editing buffer, matching the backend's budget:
    /// the TRIMMED value measured in UTF-16 code units (the unit `@MaxLength(2000)`
    /// counts). Using grapheme clusters / the untrimmed string could show an
    /// in-bounds counter that the server still rejects with a 400.
    private var characterCount: Int {
        trimmedDraft.utf16.count
    }

    /// True when the draft exceeds the length budget the backend enforces.
    private var isOverLimit: Bool {
        characterCount > maxLength
    }

    /// Save is enabled with an in-bounds draft that actually differs from the
    /// persisted prompt, and no mutation in flight. An empty draft is allowed —
    /// clearing the field then saving is a valid "no custom prompt" state (the
    /// backend treats an empty custom prompt as the default voice).
    private var canSave: Bool {
        guard !store.isMutating, !isOverLimit else { return false }
        return draft != (store.customPrompt ?? "")
    }

    /// The count caption colour: danger over the ceiling, accent near it, muted
    /// otherwise. Mirrors the persona editor's count treatment.
    private var countColor: Color {
        if isOverLimit { return theme.danger }
        if characterCount >= 1_900 { return theme.accentText }
        return theme.textSecondary
    }

    // MARK: Body

    var body: some View {
        content
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(Text(String(localized: "brief.config.title", defaultValue: "Brief configuration")))
            .navigationBarTitleDisplayMode(.inline)
            .task {
                store.bind(notifications: notifications)
                if store.loadState != .loaded {
                    await store.load()
                }
                // Seed the local editing state from the loaded prompt — both after
                // a cold load and when an already-loaded store was injected (tests /
                // re-entry), so the injected case isn't left with an empty draft.
                syncFromStore()
            }
            .confirmActionSheet(
                isPresented: $showResetConfirm,
                title: String(
                    localized: "brief.config.reset.confirm.title",
                    defaultValue: "Reset to default?"
                ),
                message: String(
                    localized: "brief.config.reset.confirm.message",
                    defaultValue: "Your custom brief configuration will be cleared and the default voice restored. This can't be undone."
                ),
                primary: ConfirmAction(
                    String(localized: "brief.config.reset.confirm.action", defaultValue: "Reset configuration")
                ) {
                    Task { await performReset() }
                }
            )
    }

    /// True while the prompt is still loading — the chrome stays mounted and the
    /// well hosts a localized spinner rather than collapsing to a full-screen
    /// loader.
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
                    localized: "brief.config.error.load",
                    defaultValue: "Couldn't load configuration"
                ),
                message: message,
                retry: { Task { await store.load(); syncFromStore() } }
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
            Text(String(localized: "brief.config.title", defaultValue: "Brief configuration"))
                .cueText(.displayL)
                .foregroundStyle(theme.textPrimary)
            Text(
                String(
                    localized: "brief.config.intro",
                    defaultValue: "Personalize how your brief is written. Leave it empty to use the default voice."
                )
            )
            .cueText(.callout)
            .foregroundStyle(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            promptHeaderRow
            promptWell
        }
    }

    private var promptHeaderRow: some View {
        HStack(spacing: Spacing.sm) {
            Text(String(localized: "brief.config.prompt.label", defaultValue: "PROMPT"))
                .cueText(.label)
                .foregroundStyle(theme.textSecondary)

            Spacer(minLength: Spacing.sm)

            // `Text(verbatim:)` renders the string as-is, bypassing the
            // `LocalizedStringKey` path whose Int interpolation would apply the
            // locale grouping separator — reads "52 / 2000", never "52 / 2 000".
            Text(verbatim: "\(characterCount) / \(maxLength)")
                .cueText(.code)
                .foregroundStyle(countColor)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var promptWell: some View {
        // Editable well: functional 12px (`Radius.card`) corner + floating depth.
        let editShape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        let lockedShape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        Group {
            if isLoading {
                // Field-level loading: chrome stays mounted, only the well shows a
                // centered spinner — mirrors the persona editor's in-well ring.
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 168)
                    .background(lockedShape.fill(theme.surfaceSunken))
                    .overlay(lockedShape.strokeBorder(theme.separator, lineWidth: 1))
                    .clipShape(lockedShape)
                    .accessibilityLabel(String(localized: "common.loading"))
            } else {
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
            }
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
                        Text(String(localized: "brief.config.saving", defaultValue: "Saving…"))
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
                    Button(String(localized: "brief.config.save", defaultValue: "Save configuration")) {
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

            Button(
                String(localized: "brief.config.reset", defaultValue: "Reset to default"),
                role: .destructive
            ) {
                showResetConfirm = true
            }
            .buttonStyle(.cue(.ghost))
            .disabled(store.isMutating)
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

    /// Seeds the local editing buffer from the loaded custom prompt (empty when
    /// the default voice is in effect).
    private func syncFromStore() {
        draft = store.customPrompt ?? ""
    }

    /// Persists the custom draft, then stamps the wax seal briefly on success.
    /// Sends the TRIMMED draft (matching the counter/over-limit gate above) so the
    /// client and the backend's trimmed `@MaxLength(2000)` check agree on the exact
    /// value and its length.
    private func performSave() async {
        promptFocused = false
        let saved = await store.save(customPrompt: trimmedDraft)
        guard saved else { return }
        syncFromStore()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.6)) { showSeal = true }
        try? await Task.sleep(for: .seconds(1.6))
        withAnimation(.easeOut(duration: 0.2)) { showSeal = false }
    }

    /// Resets to the default voice, re-seeding the editing buffer from the result.
    private func performReset() async {
        promptFocused = false
        let didReset = await store.reset()
        guard didReset else { return }
        syncFromStore()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BriefConfigView()
    }
    .environment(NotificationStore())
    .environment(\.theme, AppPalette.kraftInk.colors)
}
