//
//  AppNavigation.swift
//  cue
//

import SwiftUI

// MARK: - AppTab

/// One of the top-level sections of the app, plus the tab-bar "New Event"
/// action item.
enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case calendar
    case dashboard
    case settings
    /// Not a real destination — an action item rendered inline in the native
    /// tab bar (so it inherits Liquid Glass) that opens the New Event sheet.
    /// Its selection is intercepted in `RootView`, so it never becomes the
    /// active tab and its empty content is never shown.
    case newEvent

    /// The real, selectable destination tabs — excludes the `newEvent` action
    /// item. Use this for anything that iterates over genuine tabs.
    static var destinations: [AppTab] { [.calendar, .dashboard, .settings] }

    var id: String { rawValue }

    /// User-facing label as a plain `String`. For SwiftUI tab labels prefer
    /// ``titleKey`` so the text re-localizes live with the `\.locale` environment.
    var title: String {
        switch self {
        case .calendar: return String(localized: "tab.calendar")
        case .dashboard: return String(localized: "tab.dashboard")
        case .settings: return String(localized: "tab.settings")
        case .newEvent: return String(localized: "newEvent.title")
        }
    }

    /// User-facing label as a `LocalizedStringKey`, resolved by SwiftUI against
    /// the current `\.locale` — so the tab bar switches language live.
    var titleKey: LocalizedStringKey {
        switch self {
        case .calendar: return "tab.calendar"
        case .dashboard: return "tab.dashboard"
        case .settings: return "tab.settings"
        case .newEvent: return "newEvent.title"
        }
    }

    /// SF Symbol shown in the native `TabView` bar for this tab.
    var systemImage: String {
        switch self {
        case .calendar: return "calendar"
        case .dashboard: return "chart.bar.fill"
        case .settings: return "gearshape"
        case .newEvent: return "plus.circle.fill"
        }
    }
}

// MARK: - AppNavigation

/// Shared navigation state — the selected top-level tab (bound to the native
/// `TabView(selection:)` in `RootView`) and the global New Event sheet flag.
@Observable
@MainActor
final class AppNavigation {
    var selectedTab: AppTab = .calendar

    /// Drives the global "New Event" sheet. Presented from the tab-bar "+"
    /// action item — a tab-level create action belongs in a modal, not pushed
    /// onto a single tab's navigation stack — so it's reachable from any tab.
    var isPresentingNewEvent = false

    /// Transient linking nonce parked by an incoming Telegram deep link. Non-nil
    /// drives the global "Connect Telegram?" sheet in `RootView`. A code that
    /// arrives while signed out stays parked here until sign-in flips
    /// `AuthStore.state` to `.authenticated`, at which point the sheet surfaces.
    var pendingTelegramCode: String?
}
