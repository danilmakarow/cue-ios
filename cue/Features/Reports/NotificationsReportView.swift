//
//  NotificationsReportView.swift
//  cue
//

import SwiftUI

/// Notifications & Report settings — configure the daily report (delivery time,
/// channel) and the brief / recap toggles that decide what the assistant sends.
///
/// Pushed from `SettingsView` ("Notifications & report" row) within the Settings
/// tab's `NavigationStack`. Takes no arguments; the feature team reads/writes the
/// report preferences via the appropriate store/endpoint from the environment.
///
// TODO(4c): Reports workstream builds this out — a daily-report enable toggle +
// time picker, a delivery channel selector (e.g. Telegram / push), and the
// "morning brief" / "evening recap" toggles. Use `SettingsRow` (`.toggle`) and
// `CueToggle`; persist through the report-settings store.
struct NotificationsReportView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        EmptyStateView(
            title: String(localized: "reports.notifications.title"),
            message: String(localized: "reports.notifications.placeholder.message"),
            systemImage: "bell.badge"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("reports.notifications.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationsReportView()
    }
    .environment(\.theme, AppPalette.kraftInk.colors)
}
