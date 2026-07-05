//
//  ViewModeSwitcher.swift
//  cue
//

import SwiftUI

/// Text segmented toggle ("Timeline | List") that switches between the two
/// Calendar view modes. Purely presentational — holds no state of its own.
///
/// Matches `Calendar Day.dc.html`'s inline control: WORD labels (12px / 600) on
/// `Radius.chip` pills over a recessed `surfaceSunken` track, the active segment
/// a raised `surface` pill — not SF Symbol icons. Per the CUE — Clean selection
/// rule a mode picker is a NEUTRAL selection, so the active label carries clay
/// (`primary`) ink on the raised pill rather than a solid clay fill.
struct ViewModeSwitcher: View {
    @Environment(\.theme) private var theme
    @Binding var mode: CalendarViewMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalendarViewMode.allCases) { option in
                segment(for: option)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: Radius.chip + 3, style: .continuous)
                .fill(theme.surfaceSunken)
        }
        .accessibilityElement(children: .contain)
    }

    private func segment(for option: CalendarViewMode) -> some View {
        let isSelected = mode == option
        return Button {
            withAnimation(.snappy) { mode = option }
        } label: {
            Text(option.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? theme.primary : theme.textSecondary)
                .padding(.horizontal, Spacing.sm)
                .frame(height: 26)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                            .fill(theme.surface)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    @Previewable @State var mode: CalendarViewMode = .timeline
    return ViewModeSwitcher(mode: $mode).padding()
}
