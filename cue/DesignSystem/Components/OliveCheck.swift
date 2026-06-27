//
//  OliveCheck.swift
//  cue
//
//  The canonical task DONE marker: an olive (`theme.success`) filled circle with
//  a white checkmark. This REPLACES the clay wax seal as the everyday completion
//  marker — the seal/roots motion is reserved for the heavier commit moments,
//  while this is the quiet, repeatable "this row is done" dot.
//
//  When it transitions to done it springs in (scale + a brief overshoot); when it
//  transitions back to not-done it settles out. Empty state is a hairline ring,
//  so the control reads as a tappable affordance even before completion.
//

import SwiftUI

/// An olive filled circle with a white checkmark — the standard task-done marker.
///
/// Drive `isDone` from the model; the view animates the check on toggle. Size is
/// caller-controlled via `size` (the checkmark and ring scale with it).
struct OliveCheck: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let isDone: Bool
    private let size: CGFloat

    /// - Parameters:
    ///   - isDone: whether the task is complete; toggling animates the check.
    ///   - size: the marker diameter in points (default 22).
    init(isDone: Bool, size: CGFloat = 22) {
        self.isDone = isDone
        self.size = size
    }

    var body: some View {
        ZStack {
            // Empty affordance — a hairline ring that fades out as the fill arrives.
            Circle()
                .strokeBorder(theme.border, lineWidth: max(1, size * 0.07))
                .opacity(isDone ? 0 : 1)

            // Done state — olive fill + white check.
            ZStack {
                Circle()
                    .fill(theme.success)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(theme.onAccent)
            }
            .scaleEffect(isDone ? 1 : 0.55)
            .opacity(isDone ? 1 : 0)
        }
        .frame(width: size, height: size)
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.18)
                : .spring(response: 0.32, dampingFraction: 0.58),
            value: isDone
        )
        .accessibilityHidden(true)
    }
}

#Preview("OliveCheck") {
    struct Demo: View {
        @State private var done = false
        var body: some View {
            VStack(spacing: 28) {
                HStack(spacing: 20) {
                    OliveCheck(isDone: false)
                    OliveCheck(isDone: true)
                    OliveCheck(isDone: true, size: 34)
                    OliveCheck(isDone: true, size: 14)
                }
                Button {
                    done.toggle()
                } label: {
                    HStack(spacing: 12) {
                        OliveCheck(isDone: done, size: 26)
                        Text(done ? "Done" : "Tap to complete")
                    }
                }
            }
            .padding(40)
        }
    }
    return Demo()
        .environment(\.theme, AppPalette.kraftInk.colors)
}
