//
//  YearScopeView.swift
//  cue
//

import SwiftUI

/// Year scope — the root of the calendar stack. An infinitely-scrolling column
/// of `YearPage`s; tapping a month zooms into the month scope. This is the
/// calendar "home"; tab switching is handled by the native `TabView` bar.
struct YearScopeView: View {
    let namespace: Namespace.ID
    var onSelectMonth: (Date) -> Void

    @State private var yearAnchors: [Date]
    @State private var centered: Date?

    /// How close to either end of the window before we grow it.
    private static let edgeThreshold = 2
    private static let growBy = 5

    init(namespace: Namespace.ID, onSelectMonth: @escaping (Date) -> Void) {
        self.namespace = namespace
        self.onSelectMonth = onSelectMonth
        _yearAnchors = State(initialValue: CalendarMath.yearAnchors(around: .now, radius: 6))
        _centered = State(initialValue: CalendarMath.startOfYear(.now))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 36) {
                ForEach(yearAnchors, id: \.self) { yearAnchor in
                    YearPage(yearAnchor: yearAnchor, namespace: namespace, onSelectMonth: onSelectMonth)
                        .id(yearAnchor)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 16)
        }
        .scrollPosition(id: $centered, anchor: .top)
        .navigationTitle(yearTitle)
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: centered) { _, _ in extendIfNeeded() }
    }

    private var yearTitle: String {
        (centered ?? CalendarMath.startOfYear(.now)).formatted(.dateTime.year())
    }

    /// Grows the year window when the centered year nears an end, keeping the
    /// centered id stable so prepending doesn't jump the viewport.
    private func extendIfNeeded() {
        guard let centered, let index = yearAnchors.firstIndex(of: centered) else { return }
        if index < Self.edgeThreshold, let first = yearAnchors.first {
            yearAnchors.insert(contentsOf: CalendarMath.years(before: first, count: Self.growBy), at: 0)
        }
        if index > yearAnchors.count - 1 - Self.edgeThreshold, let last = yearAnchors.last {
            yearAnchors.append(contentsOf: CalendarMath.years(after: last, count: Self.growBy))
        }
    }
}

#Preview {
    @Previewable @Namespace var namespace
    NavigationStack {
        YearScopeView(namespace: namespace, onSelectMonth: { _ in })
    }
    .environment(AppNavigation())
    .environment(ThemeSettings())
}
