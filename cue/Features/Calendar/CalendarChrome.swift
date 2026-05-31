//
//  CalendarChrome.swift
//  cue
//

import SwiftUI

/// Persistent bottom control cluster for the month and day scopes — a "Today"
/// button on the leading side and a Liquid-Glass pill (calendar / inbox) on
/// the trailing side, mirroring the reference design.
///
/// `onToday` is scope-local: on the day scope it recenters the pager on today,
/// on the month scope it scrolls to the current month. Hosted via
/// `.safeAreaInset(edge: .bottom)` by each scope view.
struct CalendarChrome: View {
    var onToday: () -> Void

    var body: some View {
        HStack {
            Button(action: onToday) {
                Text("calendar.chrome.today")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)

            Spacer()

            HStack(spacing: 2) {
                Button(action: onToday) {
                    Image(systemName: "calendar")
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("calendar.chrome.today.accessibility")

                Button {
                    // Inbox — not implemented yet.
                } label: {
                    Image(systemName: "tray")
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("calendar.chrome.inbox")
            }
            .font(.title3)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .tint(.primary)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }
}

#Preview {
    ZStack { Color(.systemBackground) }
        .safeAreaInset(edge: .bottom) { CalendarChrome(onToday: {}) }
}
