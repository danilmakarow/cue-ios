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

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(CueChipStyle(isSelected: isSelected))
        .animation(.easeOut(duration: 0.16), value: isSelected)
    }
}

/// The chip's press + selection treatment, factored into a `ButtonStyle` so a
/// press picks up the same signature as `CueButtonStyle`: a 1pt downward nudge
/// paired with a one-step-darker fill, on a 160ms ease-out. Selection swaps the
/// resting fill/ink/border (neutral gray → clay wash); the press darkens
/// whichever resting fill is showing.
private struct CueChipStyle: ButtonStyle {
    @Environment(\.theme) private var theme

    let isSelected: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .cueText(.label)
            .foregroundStyle(isSelected ? theme.accentText : theme.textSecondary)
            .padding(.vertical, Spacing.xs + 2)
            .padding(.horizontal, Spacing.sm + 2)
            .background(shape.fill(isSelected ? theme.accentSoft : theme.surfaceSunken))
            // One-step fill darken on press — a subtle scrim over whichever resting
            // fill is showing, mirroring CueButtonStyle's darker-pressed fill.
            .overlay(shape.fill(Color.black.opacity(pressed ? 0.05 : 0)))
            .overlay(
                // Neutral chip shows its functional edge; the selected clay wash
                // drops the border so the accent reads clean.
                shape.strokeBorder(isSelected ? Color.clear : theme.border, lineWidth: 1)
            )
            .contentShape(shape)
            // Press signature: a 1pt downward nudge, matching CueButtonStyle.
            .offset(y: pressed ? 1 : 0)
            .animation(.easeOut(duration: 0.16), value: pressed)
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
