//
//  MonthScopeView.swift
//  cue
//

import SwiftData
import SwiftUI

/// Month scope — an infinitely-scrolling column of `MonthPage`s with a pinned
/// weekday header. Tapping a day zooms into the day scope.
///
/// Infinite scroll uses a growing window of month anchors plus
/// `.scrollPosition(id:)` bound to the *centered* anchor: because the centered
/// id stays put, prepending older months above it doesn't jump the viewport.
struct MonthScopeView: View {
    let monthAnchor: Date
    let namespace: Namespace.ID
    var onSelectDay: (Date) -> Void

    @Environment(CalendarStore.self) private var store
    @Environment(\.modelContext) private var modelContext

    @State private var monthAnchors: [Date]
    @State private var centered: Date?

    private static let edgeThreshold = 6
    private static let growBy = 12

    init(monthAnchor: Date, namespace: Namespace.ID, onSelectDay: @escaping (Date) -> Void) {
        self.monthAnchor = monthAnchor
        self.namespace = namespace
        self.onSelectDay = onSelectDay
        _monthAnchors = State(initialValue: CalendarMath.monthAnchors(around: monthAnchor, radius: 18))
        _centered = State(initialValue: CalendarMath.startOfMonth(monthAnchor))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 28) {
                ForEach(monthAnchors, id: \.self) { anchor in
                    MonthPage(
                        monthAnchor: anchor,
                        selectedDate: store.selectedDate,
                        namespace: namespace,
                        onSelectDay: onSelectDay
                    )
                    .id(anchor)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 12)
        }
        .scrollPosition(id: $centered, anchor: .top)
        .safeAreaInset(edge: .top) { weekdayHeader }
        .safeAreaInset(edge: .bottom) { CalendarChrome(onToday: scrollToCurrentMonth) }
        .navigationTitle(monthTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: centered) { _, newValue in
            extendIfNeeded()
            Task { await syncAround(newValue) }
        }
        .task { await syncAround(centered) }
    }

    // MARK: - Header

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(Array(CalendarMath.orderedWeekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var monthTitle: String {
        (centered ?? monthAnchor).formatted(.dateTime.month(.wide))
    }

    // MARK: - Actions

    private func scrollToCurrentMonth() {
        withAnimation(.snappy) { centered = CalendarMath.startOfMonth(.now) }
    }

    /// Grows the month window when the centered month nears an end.
    private func extendIfNeeded() {
        guard let centered, let index = monthAnchors.firstIndex(of: centered) else { return }
        if index < Self.edgeThreshold, let first = monthAnchors.first {
            monthAnchors.insert(contentsOf: CalendarMath.months(before: first, count: Self.growBy), at: 0)
        }
        if index > monthAnchors.count - 1 - Self.edgeThreshold, let last = monthAnchors.last {
            monthAnchors.append(contentsOf: CalendarMath.months(after: last, count: Self.growBy))
        }
    }

    /// Ensures the centered month and its neighbors are synced so dots are
    /// ready just before they scroll into view.
    private func syncAround(_ anchor: Date?) async {
        guard let anchor else { return }
        let calendar = Calendar.current
        for offset in -1...1 {
            guard let month = calendar.date(byAdding: .month, value: offset, to: anchor) else { continue }
            await store.ensureMonthSynced(CalendarMath.startOfMonth(month), context: modelContext)
        }
    }
}
