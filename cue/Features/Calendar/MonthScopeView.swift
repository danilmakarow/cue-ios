//
//  MonthScopeView.swift
//  cue
//

import SwiftData
import SwiftUI

/// Month scope — an infinitely-scrolling column of `MonthPage`s with a pinned
/// weekday header. Tapping a day zooms into the day scope.
///
/// Infinite scroll uses a sliding window of month anchors plus
/// `.scrollPosition(id:)` bound to the *centered* anchor: because the centered
/// id stays put, prepending older months above it doesn't jump the viewport.
/// The window grows only after the scroll settles (and is trimmed at the far
/// edge so it can't grow without bound), and a `FlingClampBehavior` caps
/// single-fling travel, so a fast flick can't coast through years at once.
///
/// Scroll-performance invariant: nothing here observes per-frame scroll
/// geometry. The fling clamp's gesture-start offset comes from the phase
/// change's context, and the per-month height estimate from content *size*
/// changes (rare) — so scrolling never invalidates this view's body.
struct MonthScopeView: View {
    /// Month the scope mounts centered on.
    let monthAnchor: Date
    var onSelectDay: (Date) -> Void
    /// Reports the month the list has settled on, so the zoom container can
    /// anchor a month → year zoom-out (and seed the year scope) truthfully
    /// after the user scrolls this list away from `monthAnchor`.
    var onCenteredMonthChange: (Date) -> Void = { _ in }

    @Environment(CalendarStore.self) private var store
    @Environment(\.modelContext) private var modelContext

    @State private var monthAnchors: [Date]
    @State private var centered: Date?

    /// Vertical content offset captured when the current drag began; feeds the
    /// fling clamp so travel is measured from the gesture's origin.
    @State private var flingStartOffsetY: CGFloat = 0
    /// Approximate on-screen height of one `MonthPage`, derived from the
    /// laid-out content. Drives the per-fling travel cap (~10 months).
    @State private var pointsPerMonth: CGFloat = 0

    private static let edgeThreshold = 6
    private static let growBy = 12
    /// Months a single fling may cross before settling.
    private static let maxMonthsPerFling: CGFloat = 10
    private static let seedRadius = 18
    /// Hard cap on the window; the far edge is trimmed when growth exceeds it
    /// so a long session can't accumulate unbounded pages.
    private static let maxWindowSize = 60

    init(
        monthAnchor: Date,
        onSelectDay: @escaping (Date) -> Void,
        onCenteredMonthChange: @escaping (Date) -> Void = { _ in }
    ) {
        self.monthAnchor = monthAnchor
        self.onSelectDay = onSelectDay
        self.onCenteredMonthChange = onCenteredMonthChange
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
        // Observe content *size* only — it changes when the window grows, not
        // while the user scrolls, so this never fires per frame.
        .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentSize.height }) { _, newHeight in
            updatePointsPerMonth(contentHeight: newHeight)
        }
        .onScrollPhaseChange { oldPhase, newPhase, context in
            // Snapshot the origin when a drag begins so the clamp measures from
            // there; extend the window only once motion fully settles.
            if !oldPhase.isScrolling, newPhase.isScrolling {
                flingStartOffsetY = context.geometry.contentOffset.y
            }
            if oldPhase.isScrolling, newPhase == .idle {
                extendIfNeeded()
                Task { await syncAround(centered) }
            }
        }
        .safeAreaInset(edge: .top) { weekdayHeader }
        .overlay(alignment: .bottomTrailing) {
            JumpToTodayButton(isVisible: true, action: todayButtonTapped)
                .padding(.trailing, 20)
                .padding(.bottom, 24)
        }
        .navigationTitle(monthTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await syncAround(centered) }
        .onChange(of: centered) { _, newCentered in
            if let newCentered {
                onCenteredMonthChange(newCentered)
            }
        }
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

    /// Progressive "Today" action: scroll the current month back into view if
    /// it isn't focused; if it already is, zoom one level into today's day —
    /// `onSelectDay` plays the container's anchored zoom from today's cell.
    private func todayButtonTapped() {
        if isOnCurrentMonth {
            onSelectDay(CalendarMath.startOfDay(.now))
        } else {
            scrollToCurrentMonth()
        }
    }

    /// Jumps back to the current month, reliably even while the list is still
    /// flinging. Mirrors `YearScopeView.scrollToCurrentYear` — see its doc for
    /// the full rationale:
    /// - **item 3:** extend the window to include today (add only missing
    ///   months) instead of rebuilding the whole `monthAnchors` array, so the
    ///   lazy column keeps its page identities and stays cheap.
    /// - **item 2:** clear the scroll-position binding to release an in-flight
    ///   fling, then assign the target next tick so the jump isn't dropped.
    private func scrollToCurrentMonth() {
        let currentMonth = CalendarMath.startOfMonth(.now)
        if !monthAnchors.contains(currentMonth) {
            monthAnchors = CalendarMath.monthAnchorsExtended(monthAnchors, toInclude: currentMonth, margin: 6)
        }
        jumpCentered(to: currentMonth)
        Task { await syncAround(currentMonth) }
    }

    /// Forces the lazy column to the given anchor, overriding any in-flight
    /// user fling. Detaches scroll-position tracking (`nil`) so the decelerating
    /// scroll lets go, waits one frame for the scroll view to apply the detach,
    /// then drives the real target — which now lands as a fresh programmatic
    /// scroll the in-flight gesture can't override.
    private func jumpCentered(to anchor: Date) {
        centered = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            withAnimation(.snappy) { centered = anchor }
        }
    }

    /// Caches the average height of a single month page so the fling clamp can
    /// express its limit in "months" rather than raw points.
    private func updatePointsPerMonth(contentHeight: CGFloat) {
        guard !monthAnchors.isEmpty, contentHeight > 0 else { return }
        pointsPerMonth = contentHeight / CGFloat(monthAnchors.count)
    }

    /// Grows the month window when the centered month nears an end, then trims
    /// the opposite edge past `maxWindowSize`. Called on scroll-settle (not
    /// mid-fling) so the window can't run away during a fast flick. Trimming
    /// the far edge never touches the centered id, so the id-pinned viewport
    /// doesn't move.
    private func extendIfNeeded() {
        guard let centered, let index = monthAnchors.firstIndex(of: centered) else { return }
        if index < Self.edgeThreshold, let first = monthAnchors.first {
            monthAnchors.insert(contentsOf: CalendarMath.months(before: first, count: Self.growBy), at: 0)
            trimWindowExcess(fromFront: false)
        } else if index > monthAnchors.count - 1 - Self.edgeThreshold, let last = monthAnchors.last {
            monthAnchors.append(contentsOf: CalendarMath.months(after: last, count: Self.growBy))
            trimWindowExcess(fromFront: true)
        }
    }

    /// Drops pages beyond `maxWindowSize` from the edge opposite the growth.
    private func trimWindowExcess(fromFront: Bool) {
        let excess = monthAnchors.count - Self.maxWindowSize
        guard excess > 0 else { return }
        if fromFront {
            monthAnchors.removeFirst(excess)
        } else {
            monthAnchors.removeLast(excess)
        }
    }

    /// Ensures the centered month and its neighbors are synced so day titles
    /// are ready just before they scroll into view.
    private func syncAround(_ anchor: Date?) async {
        guard let anchor else { return }
        let calendar = Calendar.current
        for offset in -1...1 {
            guard let month = calendar.date(byAdding: .month, value: offset, to: anchor) else { continue }
            await store.ensureMonthSynced(CalendarMath.startOfMonth(month), context: modelContext)
        }
    }
}
