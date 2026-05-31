//
//  DashboardView.swift
//  cue
//

import SwiftUI

/// Dashboard tab — completion reporting and summaries of past periods.
struct DashboardView: View {
    var body: some View {
        ContentUnavailableView(
            "dashboard.title",
            systemImage: "chart.bar.fill",
            description: Text("dashboard.empty.description")
        )
        .navigationTitle("dashboard.title")
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(AppNavigation())
}
