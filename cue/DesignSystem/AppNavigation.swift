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

    /// User-facing label. Localized via the app's String Catalog.
    var title: String {
        switch self {
        case .calendar: return String(localized: "tab.calendar")
        case .dashboard: return String(localized: "tab.dashboard")
        case .settings: return String(localized: "tab.settings")
        }
    }

    /// SF Symbol used by the custom tab bar.
    var systemImage: String {
        switch self {
        case .calendar: return "calendar"
        case .dashboard: return "chart.bar.fill"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - AppNavigation

/// Shared navigation state — currently just the selected top-level tab.
/// Root screens render `AppTabBar` themselves via `.safeAreaInset(.bottom)`;
/// pushed destinations don't, so the bar is naturally absent on detail pages.
@Observable
@MainActor
final class AppNavigation {
    var selectedTab: AppTab = .calendar
}
