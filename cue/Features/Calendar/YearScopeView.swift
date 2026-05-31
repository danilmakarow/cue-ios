//
//  YearScopeView.swift
//  cue
//

import SwiftUI

/// Year scope — the root of the calendar stack. An infinitely-scrolling column
/// of `YearPage`s; tapping a month zooms into the month scope. This is the
/// calendar "home", so it hosts the global `AppTabBar` for tab switching.
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
        .safeAreaInset(edge: .bottom) { AppTabBar() }
        .overlay(alignment: .bottom) {
            JumpToTodayButton(isVisible: !isOnCurrentYear, action: scrollToCurrentYear)
                .padding(.bottom, 96)
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

    private func scrollToCurrentYear() {
        let currentYear = CalendarMath.startOfYear(.now)
        // The target year must exist in the window for `.scrollPosition(id:)` to
        // move to it. After scrolling far away the current year can fall outside
        // the grown window, so re-anchor around today first.
        if !yearAnchors.contains(currentYear) {
            yearAnchors = CalendarMath.yearAnchors(around: .now, radius: 12)
        }
        withAnimation(.snappy) { centered = currentYear }
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
