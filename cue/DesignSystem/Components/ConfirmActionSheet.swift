//
//  ConfirmActionSheet.swift
//  cue
//
//  A destructive-confirm presentation for irreversible choices — "Delete series /
//  Delete this occurrence", "Sign out", "Delete account". Wraps the system
//  `.confirmationDialog`: the idiomatic primitive for a small set of role-typed
//  choices (it renders the brick `.destructive` ink and the `.cancel` affordance
//  natively, anchors from the bottom, and dismisses on outside-tap for free).
//

import SwiftUI

/// A single confirm choice presented inside a `ConfirmActionSheet`.
///
/// The primary action is the destructive one (system brick ink via the
/// `.destructive` role). A `secondary` is the second branch of a fork — e.g.
/// "Delete this occurrence" beside a primary "Delete entire series" — and may
/// itself be destructive.
struct ConfirmAction {
    let label: String
    let isDestructive: Bool
    let handler: () -> Void

    /// - Parameters:
    ///   - label: the button title.
    ///   - isDestructive: whether the button carries the destructive (brick) role
    ///     (default `true` — the common case for this sheet).
    ///   - handler: invoked when the user taps the action.
    init(_ label: String, isDestructive: Bool = true, handler: @escaping () -> Void) {
        self.label = label
        self.isDestructive = isDestructive
        self.handler = handler
    }
}

private struct ConfirmActionSheetModifier: ViewModifier {
    @Binding var isPresented: Bool

    let title: String
    let message: String?
    let primary: ConfirmAction
    let secondary: ConfirmAction?
    let cancelLabel: String

    /// Maps a `ConfirmAction` onto a system dialog button carrying the right role.
    @ViewBuilder
    private func button(for action: ConfirmAction) -> some View {
        Button(action.label, role: action.isDestructive ? .destructive : nil) {
            action.handler()
        }
    }

    func body(content: Content) -> some View {
        content.confirmationDialog(
            title,
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            button(for: primary)
            if let secondary {
                button(for: secondary)
            }
            Button(cancelLabel, role: .cancel) {}
        } message: {
            if let message {
                Text(message)
            }
        }
    }
}

extension View {
    /// Presents a destructive-confirm action sheet when `isPresented` is `true`.
    ///
    /// Use for irreversible forks and confirmations — "Delete series / Delete this
    /// occurrence", "Sign out", "Delete account". The `primary` action is the
    /// destructive one; `secondary` is an optional second branch; a cancel button
    /// is always added.
    ///
    /// - Parameters:
    ///   - isPresented: drives presentation.
    ///   - title: the sheet title (the question being asked).
    ///   - message: optional supporting copy beneath the title.
    ///   - primary: the destructive primary action.
    ///   - secondary: an optional second action (e.g. the narrower delete branch).
    ///   - cancelLabel: the cancel button title (default localized "Cancel").
    func confirmActionSheet(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        primary: ConfirmAction,
        secondary: ConfirmAction? = nil,
        cancelLabel: String = String(localized: "common.cancel")
    ) -> some View {
        modifier(
            ConfirmActionSheetModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                primary: primary,
                secondary: secondary,
                cancelLabel: cancelLabel
            )
        )
    }
}

// MARK: - Preview

#Preview("ConfirmActionSheet") {
    struct Demo: View {
        @Environment(\.theme) private var theme
        @State private var showDeleteSeries = false
        @State private var showSignOut = false

        var body: some View {
            VStack(spacing: Spacing.lg) {
                Button("Delete recurring task") { showDeleteSeries = true }
                    .buttonStyle(.cue(.destructive))
                Button("Sign out") { showSignOut = true }
                    .buttonStyle(.cue(.secondary))
            }
            .padding(Spacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.surfaceGrouped)
            .confirmActionSheet(
                isPresented: $showDeleteSeries,
                title: "Delete this task?",
                message: "This task repeats weekly. Choose what to remove.",
                primary: ConfirmAction("Delete entire series") {},
                secondary: ConfirmAction("Delete this occurrence") {},
                cancelLabel: "Cancel"
            )
            .confirmActionSheet(
                isPresented: $showSignOut,
                title: "Sign out?",
                message: "You will need to sign in again to sync.",
                primary: ConfirmAction("Sign out") {},
                cancelLabel: "Cancel"
            )
        }
    }
    return Demo()
        .environment(\.theme, AppPalette.kraftInk.colors)
}
