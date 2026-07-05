//
//  CueChip.swift
//  cue
//
//  One selectable chip, unifying the previously-duplicated duration / weekday /
//  option chips. CUE — Clean shape: a soft 8pt `Radius.chip` rectangle whose
//  selection is carried by a clay WASH, not a solid fill — never a pill-with-a-dot.
//

import SwiftUI

/// How a `CueChip` paints its SELECTED state.
///
/// - `accent`: the default clay WASH (`accentSoft` + `accentText`, no border) —
///   the semantic "this option is chosen" treatment.
/// - `neutral`: a gray selection (`fillSelected` + `textPrimary`) for a
///   NON-semantic picker (e.g. a persona/preset switcher) where clay would
///   over-signal. The unselected look is identical to `.accent`.
enum CueChipSelection {
    case accent
    case neutral
}

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
    private let selection: CueChipSelection
    private let action: () -> Void

    /// - Parameters:
    ///   - title: the chip label.
    ///   - systemImage: an optional leading SF Symbol.
    ///   - isSelected: whether the chip is currently chosen.
    ///   - selection: the selected-state treatment — `.accent` (clay wash,
    ///     default) for a semantic choice, `.neutral` (gray) for a non-semantic
    ///     picker. Defaults to `.accent` so existing callers are unchanged.
    ///   - action: invoked on tap.
    init(
        _ title: String,
        systemImage: String? = nil,
        isSelected: Bool,
        selection: CueChipSelection = .accent,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.selection = selection
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
        .buttonStyle(CueChipStyle(isSelected: isSelected, selection: selection))
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
    let selection: CueChipSelection

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
    }

    /// The ink color for the current state — selected ink depends on the
    /// selection style (clay `accentText` vs neutral `textPrimary`).
    private var inkColor: Color {
        guard isSelected else { return theme.textSecondary }
        return selection == .neutral ? theme.textPrimary : theme.accentText
    }

    /// The resting fill — selected fill depends on the selection style (clay
    /// `accentSoft` wash vs neutral `fillSelected` gray).
    private var fillColor: Color {
        // Unselected resting chip is WHITE (`theme.surface`) so the 1px functional
        // border defines it; selected states (clay wash / neutral gray) unchanged.
        guard isSelected else { return theme.surface }
        return selection == .neutral ? theme.fillSelected : theme.accentSoft
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .cueText(.label)
            .foregroundStyle(inkColor)
            .padding(.vertical, Spacing.xs + 2)
            .padding(.horizontal, Spacing.sm + 2)
            .background(shape.fill(fillColor))
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
