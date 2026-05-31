//
//  AppTabBar.swift
//  cue
//

import SwiftUI

/// Liquid-glass bottom tab bar. Rendered only by the three root screens
/// via `.safeAreaInset(edge: .bottom)`; pushed destinations don't include
/// this inset, so the bar is absent on detail views — no hide/show
/// animation, no flicker on pop.
struct AppTabBar: View {
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation

        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                tabButton(for: tab, selection: $navigation.selectedTab)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, 24)
    }

    /// A single tab button. Tinted when selected, secondary otherwise.
    @ViewBuilder
    private func tabButton(for tab: AppTab, selection: Binding<AppTab>) -> some View {
        let isSelected = selection.wrappedValue == tab

        Button {
            withAnimation(.snappy) { selection.wrappedValue = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 22, weight: .medium))
                Text(tab.title)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .frame(minHeight: 48)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
