//
//  CalendarView.swift
//  cue
//

import SwiftData
import SwiftUI

/// Day scope of the Calendar tab. Renders the week strip plus a horizontally
/// paged set of day pages; `DayEventsProvider` picks timeline vs. list per the
/// store's `viewMode`. Selection and events come from the shared
/// `CalendarStore` + SwiftData, so this view holds no data of its own.
struct CalendarView: View {
    let user: UserDTO
    /// Navigates the day scope to today (re-anchoring the navigation entry),
    /// as opposed to the pill which only recenters the pager. Supplied by
    /// `CalendarRootView`; defaults to a no-op for previews.
    var onOpenToday: () -> Void = {}
    /// Called when the user taps an event card (not the completion checkbox).
    var onSelect: (ScheduleEvent) -> Void = { _ in }

    @Environment(CalendarStore.self) private var store
    @Environment(\.modelContext) private var modelContext

    /// Page window — ±90 days around today. Lazy-realized by `LazyHStack`.
    private var pageDates: [Date] {
        let today = CalendarMath.startOfDay(.now)
        return (-90...90).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: today)
        }
    }

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 12) {
            WeekStripPicker(selectedDate: $store.selectedDate)

            if store.isLoading {
                InlineLoadingRow()
                    .padding(.horizontal, 16)
                    .transition(.opacity)
            }

            paginatedContent
        }
        .padding(.top, 8)
        .navigationTitle(dayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isOnToday {
                ToolbarItem(placement: .topBarTrailing) {
                    openTodayButton
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                ViewModeSwitcher(mode: $store.viewMode)
            }
        }
        .overlay(alignment: .bottomLeading) {
            JumpToTodayButton(isVisible: !isOnToday, action: goToToday)
                .padding(.leading, 20)
                .padding(.bottom, 24)
        }
        // Request failures surface through the global notification host
        // (wired in `CalendarStore`), so no per-screen error alert here.
        .task(id: store.selectedDate) {
            await store.ensureDaySynced(store.selectedDate, context: modelContext)
        }
    }

    // MARK: - Header

    private var dayTitle: String {
        store.selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// Toolbar button that *navigates* to today's day page (re-anchoring the
    /// day route via `onOpenToday`). Distinct from the floating "Today" pill,
    /// which only recenters the pager within the current scope. Lives in the
    /// nav bar so it never overlaps the pill (bottom-leading) or other chrome.
    /// Reuses the existing "Go to today" accessibility string.
    private var openTodayButton: some View {
        Button(action: onOpenToday) {
            Image(systemName: "calendar.circle")
        }
        .accessibilityLabel("calendar.chrome.today.accessibility")
    }

    // MARK: - Horizontally paged content

    /// Horizontal paging of day pages. The child rendered per page is chosen by
    /// `DayEventsProvider` based on `store.viewMode`; switching modes preserves
    /// the current day because the window and scroll binding are unchanged.
    private var paginatedContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(pageDates, id: \.self) { date in
                    DayEventsProvider(date: date, onSelect: onSelect)
                        .containerRelativeFrame(.horizontal)
                        .id(date)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: pageScrollBinding, anchor: .center)
    }

    /// Two-way bridge between the horizontal scroll position and the store's
    /// `selectedDate`: reads it as the current page, writes it on swipe.
    private var pageScrollBinding: Binding<Date?> {
        Binding(
            get: { store.selectedDate },
            set: { newDate in
                if let newDate, newDate != store.selectedDate {
                    store.selectedDate = newDate
                }
            }
        )
    }

    /// True when the day pager is showing today, so the "jump to today" pill
    /// can hide — mirroring the month and year scopes.
    private var isOnToday: Bool {
        CalendarMath.isToday(store.selectedDate)
    }

    private func goToToday() {
        withAnimation(.snappy) {
            store.selectedDate = CalendarMath.startOfDay(.now)
        }
    }
}

#Preview {
    NavigationStack {
        CalendarView(
            user: UserDTO(
                id: UUID().uuidString,
                appleUserId: "preview",
                email: nil,
                displayName: "Danil Makarov",
                avatarBase64: nil,
                timezone: TimeZone.current.identifier,
                createdAt: Date(),
                updatedAt: Date()
            )
        )
    }
    .environment(CalendarStore(user: UserDTO(
        id: UUID().uuidString,
        appleUserId: "preview",
        email: nil,
        displayName: "Danil Makarov",
        avatarBase64: nil,
        timezone: TimeZone.current.identifier,
        createdAt: Date(),
        updatedAt: Date()
    )))
    .environment(AppNavigation())
    .environment(ThemeSettings())
    .modelContainer(for: [EventCalendar.self, TaskItem.self], inMemory: true)
}
