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

    /// One windowed query over the whole displayable range, replacing the old
    /// one-`@Query`-per-page fan-out: a single live observer whose results are
    /// bucketed by day and handed to pages as plain values. A `context.save()`
    /// now re-evaluates this one query, not every realized page's query.
    @Query private var windowTasks: [TaskItem]

    /// Page window — ±90 days around today. Stored, not recomputed per `body`:
    /// it depends only on "today", and `CalendarView.init` runs per navigation
    /// (not per `selectedDate` change). Lazy-realized by `LazyHStack`.
    private let pageDates: [Date]
    private let calendar = Calendar.current

    init(
        user: UserDTO,
        onOpenToday: @escaping () -> Void = {},
        onSelect: @escaping (ScheduleEvent) -> Void = { _ in }
    ) {
        self.user = user
        self.onOpenToday = onOpenToday
        self.onSelect = onSelect

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let window = (-90...90).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        self.pageDates = window

        // Windowed range predicate. `#Predicate` requires a single expression, so
        // the optional start is coalesced to `.distantPast` (matching the original
        // per-day query); a nil/occurrence-less start lands below the window and is
        // excluded — correct, since it can't be placed on a timeline anyway.
        let lower = window.first ?? today
        let upper = calendar.date(byAdding: .day, value: 1, to: window.last ?? today) ?? today
        let sentinel = Date.distantPast
        _windowTasks = Query(
            filter: #Predicate<TaskItem> { task in
                (task.occurrenceStart ?? sentinel) >= lower &&
                (task.occurrenceStart ?? sentinel) < upper
            },
            sort: \.occurrenceStart
        )
    }

    var body: some View {
        @Bindable var store = store
        let eventsByDay = bucketedEvents()

        VStack(alignment: .leading, spacing: 12) {
            WeekStripPicker(selectedDate: $store.selectedDate)

            if store.isLoading {
                InlineLoadingRow()
                    .padding(.horizontal, 16)
                    .transition(.opacity)
            }

            paginatedContent(eventsByDay: eventsByDay)
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

    /// Groups the windowed occurrences into per-day slices, keyed by `startOfDay`
    /// so each page looks up its events in O(1). Runs once per `body` eval (cheap
    /// array work over the windowed rows — not N SwiftData fetches). Keys are
    /// byte-equal to `pageDates` (both `startOfDay`-normalized, same calendar).
    private func bucketedEvents() -> [Date: [ScheduleEvent]] {
        Dictionary(grouping: windowTasks.compactMap { $0.asScheduleEvent() }) { event in
            calendar.startOfDay(for: event.startAt)
        }
    }

    /// Horizontal paging of day pages. The child rendered per page is chosen by
    /// `store.viewMode`; switching modes preserves the current day because the
    /// window and scroll binding are unchanged. Each page gets its pre-bucketed
    /// `events` slice — no per-page query.
    private func paginatedContent(eventsByDay: [Date: [ScheduleEvent]]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(pageDates, id: \.self) { date in
                    DayEventsProvider(
                        date: date,
                        events: eventsByDay[date] ?? [],
                        viewMode: store.viewMode,
                        onToggle: toggleCompletion,
                        onSelect: onSelect
                    )
                    .containerRelativeFrame(.horizontal)
                    .id(date)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: pageScrollBinding, anchor: .center)
    }

    /// Toggles an occurrence's completion by its (indexed, unique) key. Pages no
    /// longer own a `@Query`, so they pass the event id rather than a pre-fetched
    /// `TaskItem`; the store resolves the row.
    private func toggleCompletion(_ event: ScheduleEvent) {
        Task { await store.toggleCompletion(occurrenceKey: event.id, context: modelContext) }
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
