//
//  AppNavigation.swift
//  cue
//

import SwiftUI

// MARK: - AppTab

/// One of the three top-level sections of the app.
enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case calendar
    case dashboard
    case settings

    var id: String { rawValue }

    /// User-facing label.
    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .dashboard: return "Dashboard"
        case .settings: return "Settings"
        }
    }

    /// SF Symbol shown in the native `TabView` bar for this tab.
    var systemImage: String {
        switch self {
        case .calendar: return "calendar"
        case .dashboard: return "chart.bar.fill"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - AppNavigation

/// Shared navigation state — currently just the selected top-level tab,
/// bound to the native `TabView(selection:)` in `RootView`.
@Observable
@MainActor
final class AppNavigation {
    var selectedTab: AppTab = .calendar
}
