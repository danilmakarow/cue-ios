//
//  CalendarHostView.swift
//  cue
//

import SwiftData
import SwiftUI

/// Entry point for the Calendar tab and SwiftUI host of the UIKit calendar.
///
/// It is the successor to `CalendarRootView`: it owns the shared
/// ``CalendarStore`` (via `@State`), injects it into the environment, provides
/// the `NavigationStack` used for leaf pushes (task detail), and drives the
/// foreground-refresh trigger off `@Environment(\.scenePhase)`. The actual
/// year/month/day surface and the continuous zoom between scopes now live in the
/// UIKit ``CalendarContainerViewController``, bridged in via ``CalendarUIKitView``.
///
/// **Why the toolbar lives here.** The old day scope (`CalendarView`) rendered
/// its nav-bar chrome — the serif date title, the "open today" button, and the
/// timeline/list ``ViewModeSwitcher`` — through SwiftUI's `.toolbar`. The UIKit
/// `DayScopeViewController` can't contribute to the SwiftUI nav bar, so this host
/// reproduces those exact affordances at the SwiftUI level. The day scope keeps
/// its own floating Today *pill* (recenter the pager); this host's nav-bar
/// "today" control mirrors the old `onOpenToday` (recenter to today's day),
/// driven through the same `jump(to:)` entry the deep link uses — so the two
/// Today affordances stay consistent and don't conflict.
struct CalendarHostView: View {
    let user: UserDTO

    @Environment(AuthStore.self) private var authStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationStore.self) private var notifications
    @Environment(\.theme) private var theme

    @State private var store: CalendarStore
    @State private var path = NavigationPath()
    /// A one-shot "jump to date" handed to the representable. Set by the nav-bar
    /// Today control (and any future deep link); cleared once the container
    /// consumes it so it fires exactly once.
    @State private var pendingJump: Date?

    init(user: UserDTO) {
        self.user = user
        _store = State(initialValue: CalendarStore(user: user))
    }

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
        .environment(store)
        .task { store.bind(notifications: notifications) }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    // MARK: - Toolbar

    /// Reproduces the old day-scope nav-bar chrome: a serif principal date title,
    /// an "open today" control (shown only while off today), and the
    /// timeline/list view-mode switcher.
    @ToolbarContentBuilder
    private func calendarToolbar(store: CalendarStore) -> some ToolbarContent {
        @Bindable var store = store

        ToolbarItem(placement: .principal) {
            Text(dayTitle)
                .cueText(.titleM)
                .foregroundStyle(theme.textPrimary)
        }
        if !isOnToday {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: goToToday) {
                    Image(systemName: "calendar.circle")
                }
                .accessibilityLabel("calendar.chrome.today.accessibility")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            ViewModeSwitcher(mode: $store.viewMode)
        }
    }

    /// The inline nav-bar date, set in the same `weekday day month` format the
    /// old `CalendarView` used.
    private var dayTitle: String {
        store.selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// True when the selection is today's day, so the "open today" control hides
    /// — mirroring the old day scope.
    private var isOnToday: Bool {
        CalendarMath.isToday(store.selectedDate)
    }

    /// Navigates the calendar to today by queuing a one-shot `jump(to:)` the
    /// container consumes. Equivalent to the old `onOpenToday` recenter.
    private func goToToday() {
        pendingJump = CalendarMath.startOfDay(.now)
    }

    // MARK: - Foreground refresh

    /// Refetches visible data when the app returns to the foreground.
    ///
    /// Only acts on a transition *into* `.active`, and only while authenticated.
    /// A real background trip (`.background → .active`) drives a precise
    /// `/tasks/changes` delta inside ``CalendarStore/refreshIfStale(context:wasBackgrounded:)``
    /// → `refresh`: only the windows touched by changed series, deletions, or
    /// exceptions are re-pulled, with a graceful fall back to the old blunt full
    /// re-pull when the delta fails or the cursor is invalid. A brief
    /// `.inactive → .active` blip defers to the store's staleness threshold so it
    /// doesn't spam the API. The store guards overlap.
    ///
    /// The store owns the delta-vs-fallback decision (it needs the resolved
    /// calendar id and the durable cursor), so this host no longer bluntly
    /// invalidates every synced month up front — that path is now the fallback only.
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        guard newPhase == .active else { return }
        guard case .authenticated = authStore.state else { return }

        let wasBackgrounded = oldPhase == .background
        store.refreshIfStale(context: modelContext, wasBackgrounded: wasBackgrounded)
    }
}

// MARK: - OccurrenceVM → ScheduleEvent

extension OccurrenceVM {
    /// Maps the UIKit-side occurrence value to the ``ScheduleEvent`` the
    /// task-detail `navigationDestination` consumes. The two types are
    /// field-for-field identical (same occurrence-identity contract), so this is
    /// a direct projection — keeping `TaskDetailScreen`/`ScheduleEvent` untouched.
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
            requiresCompletion: requiresCompletion,
            completedAt: completedAt,
            isRecurring: isRecurring
        )
    }
}
