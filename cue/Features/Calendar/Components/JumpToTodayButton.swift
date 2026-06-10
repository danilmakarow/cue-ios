//
//  JumpToTodayButton.swift
//  cue
//

import SwiftUI

/// Floating "Today" pill used across the calendar scopes. Visibility and tap
/// behavior are owned by the host scope via `isVisible` and `action`: the day
/// scope shows it only while off-today (recenter the pager), while the year and
/// month overviews keep it always visible with a progressive action — recenter
/// to today when it's off-screen, otherwise zoom in one level.
///
/// It floats as an overlay (rather than reserving layout via a safe-area inset)
/// so appearing/disappearing never reflows the calendar content.
struct JumpToTodayButton: View {
    /// Whether the button should show. Host-controlled.
    let isVisible: Bool
    /// The host's "today" action (recenter and/or zoom in one level).
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Today", systemImage: "arrow.uturn.backward")
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .tint(.primary)
        .glassEffect(.regular.interactive(), in: .capsule)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        // Hidden (not removed) so the transition animates in/out smoothly and
        // the view identity is stable across day changes.
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.85)
        .allowsHitTesting(isVisible)
        .animation(.snappy, value: isVisible)
        .accessibilityHidden(!isVisible)
        .accessibilityLabel("Jump to today")
    }
}

#Preview {
    ZStack { Color(.systemBackground) }
        .overlay(alignment: .bottom) {
            JumpToTodayButton(isVisible: true, action: {})
                .padding(.bottom, 32)
        }
}
