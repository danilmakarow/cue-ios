//
//  CalendarRootView.swift
//  cue
//

import SwiftUI

/// Entry point for the Calendar tab. Owns the shared `CalendarStore`, the zoom
/// `@Namespace`, and the scope `NavigationStack`.
///
/// The stack root is the year scope; the path is seeded at launch to
/// `[month(thisMonth), day(today)]` so the app opens on the day scope while
/// back-swipe zooms out Day → Month → Year. (A programmatically-seeded stack
/// renders without a zoom on cold launch — there's no on-screen source cell to
/// morph from — which is the desired behavior.)
struct CalendarRootView: View {
    let user: UserDTO

    @State private var store: CalendarStore
    @State private var path: NavigationPath
    @Namespace private var zoom

    init(user: UserDTO) {
        self.user = user
        _store = State(initialValue: CalendarStore(user: user))

        var seeded = NavigationPath()
        seeded.append(CalendarScopeRoute.month(CalendarMath.startOfMonth(.now)))
        seeded.append(CalendarScopeRoute.day(CalendarMath.startOfDay(.now)))
        _path = State(initialValue: seeded)
    }

    var body: some View {
        NavigationStack(path: $path) {
            YearScopeView(namespace: zoom, onSelectMonth: selectMonth)
                .navigationDestination(for: CalendarScopeRoute.self) { route in
                    scopeDestination(route)
                }
                .navigationDestination(for: CalendarRoute.self) { route in
                    switch route {
                    case .newEvent: NewEventScreen()
                    }
                }
        }
        .environment(store)
    }

    @ViewBuilder
    private func scopeDestination(_ route: CalendarScopeRoute) -> some View {
        switch route {
        case .month(let anchor):
            MonthScopeView(monthAnchor: anchor, namespace: zoom, onSelectDay: selectDay)
                .navigationTransition(.zoom(sourceID: anchor, in: zoom))
        case .day(let day):
            CalendarView(user: user)
                .navigationTransition(.zoom(sourceID: day, in: zoom))
        }
    }

    private func selectMonth(_ anchor: Date) {
        path.append(CalendarScopeRoute.month(anchor))
    }

    private func selectDay(_ day: Date) {
        store.selectedDate = day
        path.append(CalendarScopeRoute.day(day))
    }
}
