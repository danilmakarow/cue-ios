//
//  CalendarHostView.swift
//  cue
//

import SwiftData
import SwiftUI

/// Entry point for the Calendar tab and SwiftUI host of the UIKit calendar.
///
/// It is the successor to `CalendarRootView`: it reads the shared
/// ``CalendarStore`` from the environment (owned and injected by `MainTabs`, so
/// the Today and Calendar tabs share one instance), provides the
/// `NavigationStack` used for leaf pushes (task detail), and drives the
/// foreground-refresh trigger off `@Environment(\.scenePhase)`. The actual
/// year/month/day surface and the continuous zoom between scopes now live in the
/// UIKit ``CalendarContainerViewController``, bridged in via ``CalendarUIKitView``.
///
/// **Why the toolbar lives here.** The old day scope (`CalendarView`) rendered
/// its nav-bar chrome — the serif date title and the timeline/list
/// ``ViewModeSwitcher`` — through SwiftUI's `.toolbar`. The UIKit
/// `DayScopeViewController` can't contribute to the SwiftUI nav bar, so this host
/// reproduces those affordances at the SwiftUI level. Today is handled entirely
/// by each scope's own bottom-right floating Today *pill* (`DayJumpToTodayButton`
/// in the Day/Month/Year scope VCs); the duplicate nav-bar "today" button was
/// removed so there is a single Today control. The host still keeps the one-shot
/// `jump(to:)` (`pendingJump`) plumbing as the deep-link seam.
struct CalendarHostView: View {
    let user: UserDTO

    @Environment(\.theme) private var theme
    @Environment(AppNavigation.self) private var navigation
    /// The shared calendar store, owned by `MainTabs` and injected into the
    /// environment so the Today and Calendar tabs operate on the same instance.
    @Environment(CalendarStore.self) private var store
    @State private var path = NavigationPath()
    /// A one-shot "jump to date" handed to the representable, cleared once the
    /// container consumes it (via `onConsumeJump`) so it fires exactly once. This
    /// is the deep-link seam the container drives through `jump(to:)`; the in-scope
    /// "Today" affordance is each scope's own floating pill, not the nav bar, so
    /// nothing sets this today — it stays wired for future deep links.
    @State private var pendingJump: Date?

    var body: some View {
        @Bindable var store = store

        NavigationStack(path: $path) {
            CalendarUIKitView(
                user: user,
                store: store,
                theme: theme,
                viewMode: store.viewMode,
                onSelectEvent: { occurrence in path.append(occurrence.asScheduleEvent) },
                pendingJump: pendingJump,
                onConsumeJump: { pendingJump = nil }
            )
            // The container fills the screen under the nav bar; ignore only the
            // bottom safe area so the day scope's content can extend behind the
            // tab bar while the nav bar still lays the toolbar out correctly.
            .ignoresSafeArea(edges: .bottom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { calendarToolbar(store: store) }
            .navigationDestination(for: ScheduleEvent.self) { event in
                TaskDetailScreen(event: event)
            }
        }
        // Foreground-refresh + the periodic sync heartbeat are hoisted to
        // `MainTabs`, so they run for the whole authenticated session regardless of
        // the selected tab (this handler used to be dead until the Calendar tab was
        // first opened).
    }

    // MARK: - Toolbar

    /// Reproduces the day-scope nav-bar chrome: an inline principal date title, a
    /// search affordance, and the timeline/list view-mode switcher. There is no
    /// nav-bar "today" control — Today is the scope's own floating pill.
    @ToolbarContentBuilder
    private func calendarToolbar(store: CalendarStore) -> some ToolbarContent {
        @Bindable var store = store

        ToolbarItem(placement: .principal) {
            // System-sans inline nav date title — CUE — Clean reserves IBM Plex
            // Serif for display titles only; nav/section headings use sans.
            Text(dayTitle)
                .font(.system(.title3, design: .default).weight(.semibold))
                .foregroundStyle(theme.textPrimary)
        }
        // Search affordance — every calendar scope's nav carries it (matching the
        // Day/Month/Year design specs). Routes to the global search sheet parked on
        // `AppNavigation`, the same entry RootView presents.
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                navigation.isPresentingSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel(String(localized: "calendar.chrome.search.accessibility", defaultValue: "Search"))
            .accessibilityIdentifier("calendar.chrome.search")
        }
        // NOTE: no nav-bar "today" button here. Each scope owns its own bottom-right
        // floating Today pill (`DayJumpToTodayButton` in the Day/Month/Year scope
        // VCs), so a duplicate nav-bar affordance was removed — the pill is the
        // single Today control. The one-shot `pendingJump` plumbing below stays as
        // the deep-link seam the container consumes via `jump(to:)`.
        ToolbarItem(placement: .topBarTrailing) {
            ViewModeSwitcher(mode: $store.viewMode)
        }
    }

    /// The inline nav-bar date, set in the same `weekday day month` format the
    /// old `CalendarView` used.
    private var dayTitle: String {
        store.selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}

// MARK: - OccurrenceVM → ScheduleEvent

extension OccurrenceVM {
    /// Maps the UIKit-side occurrence value to the ``ScheduleEvent`` the
    /// task-detail `navigationDestination` consumes. The two types are
    /// field-for-field identical (same occurrence-identity contract), so this is
    /// a direct projection — keeping `TaskDetailScreen`/`ScheduleEvent` untouched.
    ///
    /// The full color set (`colorToken` + `groupColorToken`) AND the `groupId` are
    /// forwarded so the pushed detail resolves the same effective task color and
    /// group name the calendar cells show — otherwise the sheet would paint a bare
    /// gray with no group meta.
    var asScheduleEvent: ScheduleEvent {
        ScheduleEvent(
            id: id,
            seriesId: seriesId,
            occurrenceStart: occurrenceStart,
            originalStart: originalStart,
            title: title,
            notes: notes,
            startAt: startAt,
            endAt: endAt,
            isAllDay: isAllDay,
            groupId: groupId,
            colorToken: colorToken,
            groupColorToken: groupColorToken,
            requiresCompletion: requiresCompletion,
            completedAt: completedAt,
            isRecurring: isRecurring
        )
    }
}
