//
//  CueChip.swift
//  cue
//
//  One selectable chip, unifying the previously-duplicated duration / weekday /
//  option chips. Kraft & Ink shape: a crisp 4pt "rubber-stamp" rectangle — a
//  word in a filled or empty box — NOT a pill, and never a pill-with-a-dot.
//

import SwiftUI

/// A selectable stamp chip. Selection is carried by *fill + ink*, not a separate
/// indicator dot: unselected reads as an empty stamp (surface fill + 1px
/// functional border + muted ink); selected reads as a pressed stamp (espresso
/// fill + cream ink, no border). Espresso — not the rationed clay — is the
/// selected fill, so the chip never competes with the wax seal or a decisive CTA.
struct CueChip: View {
    @Environment(\.theme) private var theme

    private let title: String
    private let systemImage: String?
    private let isSelected: Bool
    private let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .cueText(.label)
            .foregroundStyle(isSelected ? theme.onAccent : theme.textSecondary)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
            .background(shape.fill(isSelected ? theme.primary : theme.surface))
            .overlay(
                // Empty stamp shows its functional edge; the filled stamp drops it
                // so the espresso block reads clean.
                shape.strokeBorder(isSelected ? Color.clear : theme.border, lineWidth: 1)
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.16), value: isSelected)
    }
}

// MARK: - Preview

#Preview("CueChip") {
    struct Demo: View {
        @State private var selected = 1
        var body: some View {
            HStack(spacing: Spacing.sm) {
                ForEach(0..<4) { index in
                    CueChip("Opt \(index)", isSelected: selected == index) { selected = index }
                }
            }
            .padding(Spacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: 0xFFFFFF))
        }
    }
    return Demo()
}
