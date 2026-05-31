//
//  OpenTodayButton.swift
//  cue
//

import SwiftUI

/// Floating glass button that resets the calendar to *today's day page* — the
/// "back to right now" affordance shown next to the `JumpToTodayButton` pill in
/// the bottom-trailing corner of the year and month overviews. Tapping it drills
/// all the way down to today, no matter how far the user has scrolled.
///
/// Distinct from the pill, which only recenters the *current* scope in place
/// (year stays on year, month on month). This button changes scope; the pill
/// does not. Styled to match the pill — interactive liquid glass + soft shadow —
/// so the two read as a single control cluster.
struct OpenTodayButton: View {
    /// Whether the button should show. Mirrors `JumpToTodayButton.isVisible` so
    /// the two can live in one cluster and fade together. Defaults to always
    /// visible — the year and month scopes always offer "go to today".
    var isVisible: Bool = true
    /// Navigates the calendar to today's day page.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "calendar.circle")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .tint(.primary)
        .glassEffect(.regular.interactive(), in: .capsule)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        // Hidden (not removed) so it animates in/out smoothly and keeps a stable
        // identity across day changes — mirroring `JumpToTodayButton`.
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.85)
        .allowsHitTesting(isVisible)
        .animation(.snappy, value: isVisible)
        .accessibilityHidden(!isVisible)
        .accessibilityLabel("calendar.chrome.today.accessibility")
    }
}

#Preview {
    ZStack { Color(.systemBackground) }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 10) {
                JumpToTodayButton(isVisible: true, action: {})
                OpenTodayButton(action: {})
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
}
