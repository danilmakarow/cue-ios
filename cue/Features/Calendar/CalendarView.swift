//
//  CalendarView.swift
//  cue
//

import SwiftData
import SwiftUI

/// Routes pushed onto the Calendar stack as plain (non-zoom) slide pushes.
/// The zoom-based scope routes live in `CalendarScopeRoute`.
enum CalendarRoute: Hashable {
    case newEvent
}

/// Day scope of the Calendar tab. Renders the week strip plus a horizontally
/// paged set of day pages; `DayEventsProvider` picks timeline vs. list per the
/// store's `viewMode`. Selection and events come from the shared
/// `CalendarStore` + SwiftData, so this view holds no data of its own.
struct CalendarView: View {
    let user: UserDTO

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
            ToolbarItem(placement: .topBarTrailing) {
                ViewModeSwitcher(mode: $store.viewMode)
            }
        }
        .overlay(alignment: .bottomTrailing) { newEventButton }
        .safeAreaInset(edge: .bottom) {
            CalendarChrome(onToday: goToToday)
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

    private var newEventButton: some View {
        NavigationLink(value: CalendarRoute.newEvent) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 56, height: 56)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .accessibilityLabel("New Event")
        .padding(.trailing, 20)
        .padding(.bottom, 76)
    }

    // MARK: - Horizontally paged content

    /// Horizontal paging of day pages. The child rendered per page is chosen by
    /// `DayEventsProvider` based on `store.viewMode`; switching modes preserves
    /// the current day because the window and scroll binding are unchanged.
    private var paginatedContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(pageDates, id: \.self) { date in
                    DayEventsProvider(date: date)
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
