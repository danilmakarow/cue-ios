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
/// positive/on semantic); OFF is a deeper neutral track (#D9D6D2, recessed below
/// `surfaceSunken`) so OFF reads clearly off. The white (`onAccent`) knob carries a small shadow and slides between
/// the two ends. An optional trailing `label` sits to the right; tapping either
/// the track or the label toggles.
struct CueToggle: View {
    @Environment(\.theme) private var theme

    @Binding private var isOn: Bool
    private let label: String?
    private let accessibilityLabel: String?

    private static let trackWidth: CGFloat = 46
    private static let trackHeight: CGFloat = 28
    private static let knobSize: CGFloat = 22
    private static let knobInset: CGFloat = 3

    /// The OFF track's neutral. A control-specific deeper gray than
    /// `surfaceSunken` (#F0EEEB) so the OFF state reads clearly recessed — no
    /// existing token sits this deep, so the switch owns its own constant.
    private static let offTrack = Color(hex: 0xD9D6D2)

    /// - Parameters:
    ///   - isOn: the bound on/off state.
    ///   - label: optional trailing visible label (default `nil`).
    ///   - accessibilityLabel: VoiceOver name. Required when there is no visible
    ///     `label`, so a label-less switch is never announced anonymously
    ///     (default `nil`; falls back to the visible `label` when present).
    init(isOn: Binding<Bool>, label: String? = nil, accessibilityLabel: String? = nil) {
        self._isOn = isOn
        self.label = label
        self.accessibilityLabel = accessibilityLabel
    }

    /// The name VoiceOver announces: the explicit a11y label, else the visible
    /// label. Empty when neither is supplied (a documented label-less decoration).
    private var resolvedAccessibilityLabel: String {
        accessibilityLabel ?? label ?? ""
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
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.16), value: isOn)
        .accessibilityAddTraits(.isToggle)
        .accessibilityLabel(resolvedAccessibilityLabel)
        .accessibilityValue(isOn ? "On" : "Off")
    }

    private var track: some View {
        Capsule()
            .fill(isOn ? theme.success : Self.offTrack)
            .overlay(
                Capsule().strokeBorder(isOn ? theme.success : Self.offTrack, lineWidth: 1)
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
