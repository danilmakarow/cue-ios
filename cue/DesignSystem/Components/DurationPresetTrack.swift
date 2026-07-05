//
//  DurationPresetTrack.swift
//  cue
//
//  A SCROLLING segmented track for duration presets (5m / 10m / … / 3h). CUE —
//  Clean treatment: a recessed `surfaceSunken` container holds the segments in a
//  horizontal scroll; the SELECTED segment is carried by a WHITE raised pill
//  (`surface` + 1px border + soft rest shadow), unselected segments are
//  transparent with a muted mono label. It is the inverse of the old loose-chip
//  look (which painted the SELECTED chip flat gray) and the scrolling sibling of
//  `SegmentedControl` — that control is fixed equal-width and CANNOT scroll, so
//  the up-to-nine duration presets need this distinct component.
//

import SwiftUI

/// A horizontally-scrolling segmented picker over any `Hashable` value, sized for
/// the duration presets. Renders one segment per option on a recessed gray track;
/// the selected segment sits under a white raised pill (`surface` + 1px border +
/// soft rest shadow) that slides between positions (160ms). Labels use the mono
/// receipt font (durations are numeric). Selected ink reads `textPrimary`,
/// unselected `textSecondary` — no accent colour, since this is a non-semantic
/// preset switch. React analogy: a scrollable `<SegmentedControl options selection
/// label onChange>` over any `Hashable` value.
struct DurationPresetTrack<Value: Hashable>: View {
    @Environment(\.theme) private var theme
    @Namespace private var pill

    @Binding private var selection: Value
    private let options: [Value]
    private let label: (Value) -> String

    /// - Parameters:
    ///   - selection: the bound selected value.
    ///   - options: the ordered preset segments to render.
    ///   - label: maps an option to its segment title (rendered in mono).
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xxs) {
                ForEach(options, id: \.self) { option in
                    segment(for: option)
                }
            }
            .padding(Spacing.xxs + 1)
        }
        .scrollClipDisabled()
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
                .cueText(.code)
                .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
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

#Preview("DurationPresetTrack") {
    struct Demo: View {
        @State private var minutes = 30
        private let presets = [5, 10, 15, 30, 45, 60, 90, 120, 180]

        /// Formats a minute count as a compact preset label (e.g. 90 → "1.5h").
        private func format(_ value: Int) -> String {
            guard value >= 60 else { return "\(value)m" }
            let hours = Double(value) / 60
            let trimmed = hours.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(hours))
                : String(hours)
            return "\(trimmed)h"
        }

        var body: some View {
            VStack(spacing: Spacing.xl) {
                DurationPresetTrack(
                    selection: $minutes,
                    options: presets,
                    label: format
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
