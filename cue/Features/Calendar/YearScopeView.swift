//
//  YearScopeView.swift
//  cue
//

import SwiftUI

/// Year scope — the root of the calendar stack. An infinitely-scrolling column
/// of `YearPage`s; tapping a month zooms into the month scope. This is the
/// calendar "home"; tab switching is handled by the native `TabView` bar.
///
/// The window of year anchors grows lazily, but only *after* the scroll settles
/// (see `extendIfNeeded`), and a `FlingClampBehavior` caps how far one fling can
/// travel — together these stop a fast flick from coasting through centuries in
/// a single gesture.
struct YearScopeView: View {
    let namespace: Namespace.ID
    var onSelectMonth: (Date) -> Void

    @State private var yearAnchors: [Date]
    @State private var centered: Date?

    /// Vertical content offset captured when the current drag began; feeds the
    /// fling clamp so travel is measured from the gesture's origin.
    @State private var flingStartOffsetY: CGFloat = 0
    /// Live vertical content offset, updated as the user scrolls.
    @State private var currentOffsetY: CGFloat = 0
    /// Approximate on-screen height of one `YearPage`, derived from the laid-out
    /// content. Drives the per-fling travel cap (~10 years).
    @State private var pointsPerYear: CGFloat = 0

    /// How close to either end of the window before we grow it.
    private static let edgeThreshold = 3
    private static let growBy = 8
    /// Most years a single fling may cross before settling.
    private static let maxYearsPerFling: CGFloat = 10

    init(namespace: Namespace.ID, onSelectMonth: @escaping (Date) -> Void) {
        self.namespace = namespace
        self.onSelectMonth = onSelectMonth
        _yearAnchors = State(initialValue: CalendarMath.yearAnchors(around: .now, radius: 12))
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
        .scrollIndicators(.hidden)
        .scrollPosition(id: $centered, anchor: .top)
        .scrollTargetBehavior(
            FlingClampBehavior(
                flingStartOffsetY: flingStartOffsetY,
                maxTravel: pointsPerYear * Self.maxYearsPerFling
            )
        )
        .onScrollGeometryChange(for: ScrollGeometry.self, of: { $0 }) { _, geometry in
            currentOffsetY = geometry.contentOffset.y
            updatePointsPerYear(contentHeight: geometry.contentSize.height)
        }
        .onScrollPhaseChange { oldPhase, newPhase in
            // Snapshot the origin when a drag begins so the clamp measures from
            // there; extend the window only once motion fully settles.
            if !oldPhase.isScrolling, newPhase.isScrolling {
                flingStartOffsetY = currentOffsetY
            }
            if oldPhase.isScrolling, newPhase == .idle {
                extendIfNeeded()
            }
        }
        .navigationTitle(yearTitle)
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .bottom) {
            JumpToTodayButton(isVisible: !isOnCurrentYear, action: scrollToCurrentYear)
                .padding(.bottom, 24)
        }
    }

    private var yearTitle: String {
        (centered ?? CalendarMath.startOfYear(.now)).formatted(.dateTime.year())
    }

    /// True when the topmost year is the current calendar year.
    private var isOnCurrentYear: Bool {
        centered == CalendarMath.startOfYear(.now)
    }

    // MARK: - Actions

    /// Jumps the column back to the current year. Snappy even mid-fling and
    /// even after scrolling centuries away.
    ///
    /// Two things made the old version slow and unreliable:
    /// 1. **Lag (item 3):** it reassigned the entire `yearAnchors` array
    ///    (`yearAnchors(around:)`), changing the identity of every page so the
    ///    `LazyVStack` tore down and rebuilt all ~25 `YearPage`s — each ~500
    ///    text views — on the main actor, a multi-second hang after a long
    ///    scroll. We now *extend* the window to include today (adding only the
    ///    missing years), preserving existing page identities so almost nothing
    ///    re-realizes.
    /// 2. **Ignored mid-scroll (item 2):** writing `centered = target` while a
    ///    fling is decelerating loses the race with the scroll view's own
    ///    offset write-backs. Clearing the binding first abandons the in-flight
    ///    target, then assigning the destination on the next tick lands as a
    ///    fresh programmatic scroll the view can't override.
    private func scrollToCurrentYear() {
        let currentYear = CalendarMath.startOfYear(.now)
        if !yearAnchors.contains(currentYear) {
            yearAnchors = CalendarMath.yearAnchorsExtended(yearAnchors, toInclude: currentYear, margin: 4)
        }
        jumpCentered(to: currentYear)
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

    /// Caches the average height of a single year page so the fling clamp can
    /// express its limit in "years" rather than raw points.
    private func updatePointsPerYear(contentHeight: CGFloat) {
        guard !yearAnchors.isEmpty, contentHeight > 0 else { return }
        pointsPerYear = contentHeight / CGFloat(yearAnchors.count)
    }

    /// Grows the year window when the centered year nears an end, keeping the
    /// centered id stable so prepending doesn't jump the viewport. Called on
    /// scroll-settle (not mid-fling) so the window can't run away during a fast
    /// flick.
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
