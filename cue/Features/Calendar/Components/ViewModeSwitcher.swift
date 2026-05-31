//
//  ViewModeSwitcher.swift
//  cue
//

import SwiftUI

/// Pill-style segmented toggle that switches between the two Calendar
/// view modes. Purely presentational — holds no state of its own.
struct ViewModeSwitcher: View {
    @Binding var mode: CalendarViewMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalendarViewMode.allCases) { option in
                segment(for: option)
            }
        }
        .padding(4)
        .background {
            Capsule().fill(Color.secondary.opacity(0.15))
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
                .foregroundStyle(
                    isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary)
                )
                .frame(width: 56, height: 30)
                .background {
                    if isSelected {
                        Capsule().fill(.tint)
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
    return ViewModeSwitcher(mode: $mode).padding().tint(.blue)
}
