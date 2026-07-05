//
//  SegmentedControl.swift
//  cue
//
//  A generic segmented picker. CUE — Clean treatment: the selected segment is
//  carried by a WHITE raised pill (`surface` + 1px border + a soft resting
//  shadow) sliding on a recessed `surfaceSunken` track — the track reads sunken,
//  the active segment reads lifted. (The calendar week-strip's "today = clay"
//  case is a separate, semantic control; standalone selection chips stay neutral
//  gray — see `CueChip`.) React analogy: a `<SegmentedControl options selection
//  onChange>` over any `Hashable` value.
//

import SwiftUI

/// A segmented picker over any `Hashable` selection. Renders one segment per
/// option on a recessed gray track; the selected segment sits under a white
/// raised pill (`surface` + 1px border + soft rest shadow) that slides between
/// positions (160ms). Selected ink reads `textPrimary`, unselected
/// `textSecondary` — no accent colour, since this is a non-semantic mode/scope
/// switch.
struct SegmentedControl<Value: Hashable>: View {
    @Environment(\.theme) private var theme
    @Namespace private var pill

    @Binding private var selection: Value
    private let options: [Value]
    private let label: (Value) -> String

    /// - Parameters:
    ///   - selection: the bound selected value.
    ///   - options: the ordered segments to render.
    ///   - label: maps an option to its segment title.
    init(
        selection: Binding<Value>,
        options: [Value],
        label: @escaping (Value) -> String
    ) {
        self._selection = selection
        self.options = options
        self.label = label
    }

    private var trackShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
    }

    private var pillShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
    }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(options, id: \.self) { option in
                segment(for: option)
            }
        }
        .padding(Spacing.xxs)
        .background(trackShape.fill(theme.surfaceSunken))
        .overlay(trackShape.strokeBorder(theme.border, lineWidth: 1))
        .animation(.easeOut(duration: 0.16), value: selection)
    }

    private func segment(for option: Value) -> some View {
        let isSelected = option == selection
        return Button {
            selection = option
        } label: {
            Text(label(option))
                .cueText(.label)
                .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background {
                    if isSelected {
                        pillShape
                            .fill(theme.surface)
                            .overlay(pillShape.strokeBorder(theme.border, lineWidth: 1))
                            .shadow(color: theme.textPrimary.opacity(0.05), radius: 2, y: 1)
                            .matchedGeometryEffect(id: "pill", in: pill)
                    }
                }
                .contentShape(pillShape)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("SegmentedControl") {
    struct Demo: View {
        enum Scope: String, CaseIterable { case day, week, month }
        @State private var scope: Scope = .week
        @State private var density = 1
        var body: some View {
            VStack(spacing: Spacing.xl) {
                SegmentedControl(
                    selection: $scope,
                    options: Scope.allCases,
                    label: { $0.rawValue.capitalized }
                )
                SegmentedControl(
                    selection: $density,
                    options: [0, 1, 2],
                    label: { ["Compact", "Cozy", "Roomy"][$0] }
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
