//
//  ViewModeSwitcher.swift
//  cue
//

import SwiftUI

/// Pill-style segmented toggle that switches between the two Calendar
/// view modes. Purely presentational — holds no state of its own.
struct ViewModeSwitcher: View {
    @Environment(\.theme) private var theme
    @Binding var mode: CalendarViewMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalendarViewMode.allCases) { option in
                segment(for: option)
            }
        }
        .padding(4)
        .background {
            Capsule().fill(theme.surfaceSunken)
        }
        .accessibilityElement(children: .contain)
    }

    private func segment(for option: CalendarViewMode) -> some View {
        let isSelected = mode == option
        return Button {
            withAnimation(.snappy) { mode = option }
        } label: {
            Image(systemName: option.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(isSelected ? theme.onAccent : theme.textSecondary)
                .frame(width: 56, height: 30)
                .background {
                    if isSelected {
                        Capsule().fill(theme.primary)
                    }
                }
                .contentShape(.capsule)
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
