//
//  JumpToTodayButton.swift
//  cue
//

import SwiftUI

/// Floating "Today" pill shared by all three calendar scopes (day, month,
/// year). Shown only while the scope is *not* already on the current
/// day/month/year, giving the user a single consistent way to jump back —
/// mirroring Apple Calendar's transient "Today" affordance.
///
/// It floats as an overlay (rather than reserving layout via a safe-area
/// inset) so appearing/disappearing never reflows the calendar content. Each
/// scope decides when it's visible via `isVisible` and what "today" means via
/// `action`.
struct JumpToTodayButton: View {
    /// Whether the scope is currently off-today and the button should show.
    let isVisible: Bool
    /// Recenters the hosting scope on today.
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
