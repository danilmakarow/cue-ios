//
//  CueChip.swift
//  cue
//
//  One selectable chip, unifying the previously-duplicated duration / weekday /
//  option chips. CUE — Clean shape: a soft 8pt `Radius.chip` rectangle whose
//  selection is carried by a clay WASH, not a solid fill — never a pill-with-a-dot.
//

import SwiftUI

/// A selectable chip. Selection is carried by *fill + ink*, not a separate
/// indicator dot: unselected reads as a neutral gray chip (`surfaceSunken` fill +
/// 1px functional border + muted `textSecondary` ink); selected flips to a clay
/// WASH (`accentSoft` background + `accentText` ink + NO border). The wash, rather
/// than a solid clay fill, keeps the chip from competing with a decisive CTA.
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
            .foregroundStyle(isSelected ? theme.accentText : theme.textSecondary)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
            .background(shape.fill(isSelected ? theme.accentSoft : theme.surfaceSunken))
            .overlay(
                // Neutral chip shows its functional edge; the selected clay wash
                // drops the border so the accent reads clean.
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
