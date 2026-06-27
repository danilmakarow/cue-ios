//
//  CueField.swift
//  cue
//
//  A labelled text input. An uppercase eyebrow label sits over a gray-filled
//  well with a real 1px functional edge the user must locate; the edge deepens to
//  the clay primary on focus (no glow) and to danger when the field errors. An
//  optional helper/error caption sits beneath. React analogy: a `<Field label
//  helper error mono>` form primitive.
//

import SwiftUI

/// A labelled text input in the Clean style: an uppercase eyebrow label
/// (`.label`, `textSecondary`), a `surfaceSunken` gray fill, a 1px `border` that
/// deepens to `primary` on focus and `danger` on error (the edge moves, it never
/// glows), and `Radius.small` corners. The optional `mono` flag renders the
/// value in the JetBrains Mono receipt voice (IDs, codes, amounts). A `helper`
/// caption explains the field; an `error` supersedes it and tints the caption to
/// `accentText`.
struct CueField: View {
    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    private let label: String?
    @Binding private var text: String
    private let placeholder: String
    private let helper: String?
    private let error: String?
    private let mono: Bool
    private let keyboardType: UIKeyboardType
    private let textContentType: UITextContentType?

    /// - Parameters:
    ///   - label: optional uppercase eyebrow above the field.
    ///   - text: the bound value.
    ///   - placeholder: the empty-state prompt.
    ///   - helper: supporting caption below the field (hidden when `error` is set).
    ///   - error: error caption; supersedes `helper`, turns the edge + caption red.
    ///   - mono: render the value in the monospaced receipt voice (default `false`).
    ///   - keyboardType: the software keyboard variant (default `.default`).
    ///   - textContentType: the semantic content type for autofill (default `nil`).
    init(
        label: String? = nil,
        text: Binding<String>,
        placeholder: String = "",
        helper: String? = nil,
        error: String? = nil,
        mono: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.helper = helper
        self.error = error
        self.mono = mono
        self.keyboardType = keyboardType
        self.textContentType = textContentType
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
    }

    /// The current edge colour: danger when erroring, clay when focused, otherwise
    /// the resting functional border.
    private var edge: Color {
        if error != nil { return theme.danger }
        return isFocused ? theme.primary : theme.border
    }

    /// The caption text to show beneath the field — error wins over helper.
    private var caption: String? {
        error ?? helper
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let label {
                Text(label.uppercased())
                    .cueText(.label)
                    .foregroundStyle(theme.textSecondary)
            }

            field

            if let caption {
                Text(caption)
                    .cueText(.caption)
                    .foregroundStyle(error != nil ? theme.accentText : theme.textSecondary)
            }
        }
    }

    private var field: some View {
        TextField(placeholder, text: $text)
            .focused($isFocused)
            .cueText(mono ? .code : .body)
            .foregroundStyle(theme.textPrimary)
            .tint(theme.primary)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.md)
            .background(shape.fill(theme.surfaceSunken))
            .overlay(shape.strokeBorder(edge, lineWidth: 1))
            .contentShape(shape)
            .animation(.easeOut(duration: 0.16), value: isFocused)
            .animation(.easeOut(duration: 0.16), value: error)
    }
}

// MARK: - Preview

#Preview("CueField") {
    struct Demo: View {
        @State private var name = ""
        @State private var code = "EVT-4821"
        @State private var amount = ""
        var body: some View {
            VStack(spacing: Spacing.xl) {
                CueField(
                    label: "Title",
                    text: $name,
                    placeholder: "Morning stand-up",
                    helper: "Shown on the calendar."
                )
                CueField(
                    label: "Reference",
                    text: $code,
                    placeholder: "EVT-0000",
                    mono: true
                )
                CueField(
                    label: "Amount",
                    text: $amount,
                    placeholder: "0.00",
                    error: "Enter a positive amount.",
                    keyboardType: .decimalPad
                )
            }
            .padding(Spacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: 0xFFFFFF))
        }
    }
    return Demo()
        .environment(\.theme, AppPalette.kraftInk.colors)
}
