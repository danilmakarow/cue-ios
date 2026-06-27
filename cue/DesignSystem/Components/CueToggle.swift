//
//  CueToggle.swift
//  cue
//
//  A switch. ON fills OLIVE (the positive/"on" semantic accent) so it never
//  competes with the clay seal or a decisive CTA; OFF is a neutral recessed gray
//  track. The white knob slides 160ms with a small resting shadow. React analogy:
//  a `<Toggle checked onChange label>` form primitive.
//

import SwiftUI

/// A Clean switch built on a custom 46×28 track (knob 22) so the knob's 160ms
/// slide reads as the control's signature. ON fills `success` (olive — the
/// positive/on semantic); OFF is a neutral `surfaceSunken` track with a hairline
/// edge. The white (`onAccent`) knob carries a small shadow and slides between
/// the two ends. An optional trailing `label` sits to the right; tapping either
/// the track or the label toggles.
struct CueToggle: View {
    @Environment(\.theme) private var theme

    @Binding private var isOn: Bool
    private let label: String?

    private static let trackWidth: CGFloat = 46
    private static let trackHeight: CGFloat = 28
    private static let knobSize: CGFloat = 22
    private static let knobInset: CGFloat = 3

    /// - Parameters:
    ///   - isOn: the bound on/off state.
    ///   - label: optional trailing label (default `nil`).
    init(isOn: Binding<Bool>, label: String? = nil) {
        self._isOn = isOn
        self.label = label
    }

    /// The knob's horizontal offset: pinned to the inset on each end so it slides
    /// the full track width minus its own size and both insets.
    private var knobOffset: CGFloat {
        let travel = Self.trackWidth - Self.knobSize - (Self.knobInset * 2)
        return isOn ? travel : 0
    }

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: Spacing.sm) {
                track
                if let label {
                    Text(label)
                        .cueText(.body)
                        .foregroundStyle(theme.textPrimary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.16), value: isOn)
    }

    private var track: some View {
        Capsule()
            .fill(isOn ? theme.success : theme.surfaceSunken)
            .overlay(
                Capsule().strokeBorder(isOn ? theme.success : theme.border, lineWidth: 1)
            )
            .frame(width: Self.trackWidth, height: Self.trackHeight)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(theme.onAccent)
                    .frame(width: Self.knobSize, height: Self.knobSize)
                    .shadow(color: theme.textPrimary.opacity(0.12), radius: 1, x: 0, y: 1)
                    .padding(.leading, Self.knobInset)
                    .offset(x: knobOffset)
            }
    }
}

// MARK: - Preview

#Preview("CueToggle") {
    struct Demo: View {
        @State private var notifications = true
        @State private var allDay = false
        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                CueToggle(isOn: $notifications, label: "Notifications")
                CueToggle(isOn: $allDay, label: "All-day")
                CueToggle(isOn: .constant(true))
                CueToggle(isOn: .constant(false))
            }
            .padding(Spacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color(hex: 0xFFFFFF))
        }
    }
    return Demo()
        .environment(\.theme, AppPalette.kraftInk.colors)
}
