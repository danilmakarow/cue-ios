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
/// The window grows only after the scroll settles, and a `FlingClampBehavior`
/// caps single-fling travel, so a fast flick can't coast through years at once.
struct MonthScopeView: View {
    let monthAnchor: Date
    let namespace: Namespace.ID
    var onSelectDay: (Date) -> Void

    @Environment(CalendarStore.self) private var store
    @Environment(\.modelContext) private var modelContext

    @State private var monthAnchors: [Date]
    @State private var centered: Date?

    /// Vertical content offset captured when the current drag began; feeds the
    /// fling clamp so travel is measured from the gesture's origin.
    @State private var flingStartOffsetY: CGFloat = 0
    /// Live vertical content offset, updated as the user scrolls.
    @State private var currentOffsetY: CGFloat = 0
    /// Approximate on-screen height of one `MonthPage`, derived from the
    /// laid-out content. Drives the per-fling travel cap (~10 months).
    @State private var pointsPerMonth: CGFloat = 0

    private static let edgeThreshold = 6
    private static let growBy = 12
    /// Months a single fling may cross before settling.
    private static let maxMonthsPerFling: CGFloat = 10
    private static let seedRadius = 18

    init(monthAnchor: Date, namespace: Namespace.ID, onSelectDay: @escaping (Date) -> Void) {
        self.monthAnchor = monthAnchor
        self.namespace = namespace
        self.onSelectDay = onSelectDay
        _monthAnchors = State(initialValue: CalendarMath.monthAnchors(around: monthAnchor, radius: Self.seedRadius))
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
        .scrollIndicators(.hidden)
        .scrollPosition(id: $centered, anchor: .top)
        .scrollTargetBehavior(
            FlingClampBehavior(
                flingStartOffsetY: flingStartOffsetY,
                maxTravel: pointsPerMonth * Self.maxMonthsPerFling
            )
        )
        .onScrollGeometryChange(for: ScrollGeometry.self, of: { $0 }) { _, geometry in
            currentOffsetY = geometry.contentOffset.y
            updatePointsPerMonth(contentHeight: geometry.contentSize.height)
        }
        .onScrollPhaseChange { oldPhase, newPhase in
            if !oldPhase.isScrolling, newPhase.isScrolling {
                flingStartOffsetY = currentOffsetY
            }
            if oldPhase.isScrolling, newPhase == .idle {
                extendIfNeeded()
                Task { await syncAround(centered) }
            }
        }
        .safeAreaInset(edge: .top) { weekdayHeader }
        .overlay(alignment: .bottom) {
            JumpToTodayButton(isVisible: !isOnCurrentMonth, action: scrollToCurrentMonth)
                .padding(.bottom, 24)
        }
        .navigationTitle(monthTitle)
        .navigationBarTitleDisplayMode(.inline)
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

    /// True when the topmost month is the current calendar month.
    private var isOnCurrentMonth: Bool {
        centered == CalendarMath.startOfMonth(.now)
    }

    // MARK: - Actions

    private func scrollToCurrentMonth() {
        let currentMonth = CalendarMath.startOfMonth(.now)
        // The target month must exist in the window for `.scrollPosition(id:)`
        // to move to it. When the scope was entered far from today (e.g. zoomed
        // in from a distant year) the current month can fall outside the seeded
        // window, which made the Today button silently no-op. Re-anchor around
        // today first so the id is always present.
        if !monthAnchors.contains(currentMonth) {
            monthAnchors = CalendarMath.monthAnchors(around: .now, radius: Self.seedRadius)
        }
        withAnimation(.snappy) { centered = currentMonth }
        Task { await syncAround(currentMonth) }
    }

    /// Caches the average height of a single month page so the fling clamp can
    /// express its limit in "months" rather than raw points.
    private func updatePointsPerMonth(contentHeight: CGFloat) {
        guard !monthAnchors.isEmpty, contentHeight > 0 else { return }
        pointsPerMonth = contentHeight / CGFloat(monthAnchors.count)
    }

    /// Grows the month window when the centered month nears an end. Called on
    /// scroll-settle (not mid-fling) so the window can't run away during a fast
    /// flick.
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
