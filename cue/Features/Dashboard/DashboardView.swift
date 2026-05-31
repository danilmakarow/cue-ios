//
//  DashboardView.swift
//  cue
//

import SwiftUI

/// Dashboard tab — completion reporting and summaries of past periods.
struct DashboardView: View {
    var body: some View {
        ContentUnavailableView(
            "Dashboard",
            systemImage: "chart.bar.fill",
            description: Text("Reports on what you've completed will live here.")
        )
        .navigationTitle("Dashboard")
        .safeAreaInset(edge: .bottom) {
            AppTabBar()
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(AppNavigation())
}
