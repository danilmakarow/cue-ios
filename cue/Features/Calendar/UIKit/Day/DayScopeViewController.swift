//
//  DayScopeViewController.swift
//  cue
//

import SwiftData
import UIKit

/// The **day scope** of the UIKit calendar — the innermost zoom level. Hosts a
/// horizontally-paging day pager (one page per day across a ±90-day window) with
/// a week strip pinned on top and a floating Jump-to-Today pill. Each page
/// renders that day in the store's current ``CalendarViewMode`` (`.timeline` vs
/// `.list`). The selected page is bound to `store.selectedDate`.
///
/// This is the UIKit replacement for the SwiftUI `CalendarView` + its day pages;
/// it preserves every behavior: horizontal day paging, the week strip with
/// today + selected highlighting, the timeline/list mode switch, optimistic
/// completion toggles through `store.toggleCompletion`, tap-to-open, per-day data
/// sync on display, locale-driven formatting, theming, and Dynamic Type.
///
/// **Construction (for the Integration engineer).** The container builds it with
/// the four shared dependencies and an initial theme:
/// ```swift
/// let day = DayScopeViewController(
///     store: store,
///     adapter: adapter,
///     modelContext: modelContext,
///     theme: theme
/// )
/// day.scopeDelegate = container
/// ```
/// No further wiring is needed: it observes `store.revision` itself (via the
/// adapter), syncs visible days itself, and reports selection/Today through
/// `scopeDelegate`. Push the theme on change via ``apply(theme:)`` and mirror the
/// store's `viewMode` via ``viewModeDidChange()`` when the host toggles it.
@MainActor
final class DayScopeViewController: UIViewController, CalendarScopeViewController {

    // MARK: - CalendarScopeViewController

    let kind: CalendarScopeKind = .day
    weak var scopeDelegate: CalendarScopeDelegate?

    // MARK: - Dependencies

    private let store: CalendarStore
    private let adapter: CalendarDataAdapter
    private let modelContext: ModelContext
    private var theme: CalendarTheme

    /// Shared direction/velocity prefetch planner — drives both the day-events
    /// month prefetch (via the pager's prefetch data source / settle) and the
    /// week-strip counts prefetch.
    private let prefetchCoordinator: PrefetchCoordinator

    // MARK: - Paging window

    /// ±90 days around today (the launch day), matching the SwiftUI `CalendarView`
    /// window. Each is a `startOfDay` anchor and a page identity.
    private let pageDates: [Date]
    /// Events for the whole window, bucketed by `startOfDay` for O(1) per-page
    /// lookup. Refreshed on every `revision` change.
    private var eventsByDay: [Date: [OccurrenceVM]] = [:]

    // MARK: - Views

    private let weekStrip: WeekStripView
    private let jumpToToday = DayJumpToTodayButton()
    private lazy var pager: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: makePagerLayout())
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.isPagingEnabled = true
        view.showsHorizontalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isPrefetchingEnabled = true
        view.prefetchDataSource = self
        view.register(DayPageCell.self, forCellWithReuseIdentifier: DayPageCell.reuseIdentifier)
        view.contentInsetAdjustmentBehavior = .never
        return view
    }()

    /// Guards `scrollViewDidEndDecelerating` from echoing back a programmatic page.
    private var isProgrammaticallyPaging = false

    /// The pager's `contentOffset.x` captured at the start of a user drag, so the
    /// settle handler can feed the coordinator a single start→end sample to derive
    /// scroll direction (replacing the per-frame `track()` that caused the lag).
    private var dragStartOffsetX: CGFloat = 0

    /// The last locale-week range whose counts were dispatched, so revision-driven
    /// `loadVisibleCounts()` calls within the same week skip the redundant fetch +
    /// tile reconfigure storm.
    private var lastLoadedCountsWeek: ClosedRange<Date>?

    // MARK: - Init

    /// Designated initializer. Injected by the container.
    ///
    /// - Parameters:
    ///   - store: the shared calendar store (selection, view mode, sync, toggles).
    ///   - adapter: the windowed read-side bridge over SwiftData; this VC
    ///     observes its `revision` and re-buckets on change.
    ///   - modelContext: the SwiftData context passed to store sync/toggle calls.
    ///   - theme: the initial pushed UIKit theme.
    init(
        store: CalendarStore,
        adapter: CalendarDataAdapter,
        modelContext: ModelContext,
        theme: CalendarTheme,
        prefetchCoordinator: PrefetchCoordinator
    ) {
        self.store = store
        self.adapter = adapter
        self.modelContext = modelContext
        self.theme = theme
        self.prefetchCoordinator = prefetchCoordinator

        let today = CalendarMath.startOfDay(.now)
        let pageDates = (-90...90).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: today)
        }
        self.pageDates = pageDates
        // The strip needs the pager's index of today once, to map a continuous
        // pager page index into a continuous day offset (its single input).
        let todayPageIndex = pageDates.firstIndex(of: today) ?? pageDates.count / 2
        self.weekStrip = WeekStripView(
            store: store,
            selectedDate: store.selectedDate,
            todayPageIndex: todayPageIndex
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
        wireWeekStrip()
        wireJumpToToday()
        applyTheme()

        // One-time reactive registration: re-bucket + reload on any data change.
        adapter.observeRevision { [weak self] in self?.reload() }

        reload()
        scrollToSelected(animated: false)
        syncVisibleDay()
        loadVisibleCounts()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Keep the pager centered on the selected day. This also lands the FIRST
        // center: `viewDidLoad`'s `scrollToSelected` runs before layout, so on a
        // zero-width pager its `scrollToItem` no-ops — the correct page is only
        // realized here, once layout reports real bounds. The guard intentionally
        // excludes `isProgrammaticallyPaging`: this is an idempotent offset compare
        // (skips when already aligned) and must not be blocked by the brief
        // post-scroll flag window, or a freshly-mounted scope can settle off-page.
        guard pager.bounds.width > 0 else { return }
        let pageWidth = pager.bounds.width
        let expected = CGFloat(indexOfSelectedPage()) * pageWidth
        if abs(pager.contentOffset.x - expected) > 1 {
            pager.setContentOffset(CGPoint(x: expected, y: 0), animated: false)
        }
    }

    // MARK: - Setup

    private func setUpViews() {
        view.backgroundColor = theme.background

        weekStrip.translatesAutoresizingMaskIntoConstraints = false
        jumpToToday.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(weekStrip)
        view.addSubview(pager)
        view.addSubview(jumpToToday)

        NSLayoutConstraint.activate([
            weekStrip.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Spacing.sm),
            weekStrip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            weekStrip.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            pager.topAnchor.constraint(equalTo: weekStrip.bottomAnchor, constant: Spacing.md),
            pager.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pager.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pager.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            jumpToToday.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Spacing.xl),
            jumpToToday.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Spacing.xxl),
        ])
    }

    private func wireWeekStrip() {
        weekStrip.onSelectDate = { [weak self] date in
            // Tap-to-select routes through the single selection funnel. It scrolls
            // the pager programmatically (so `scrollViewDidScroll` is skipped and
            // won't drive the pill), and `commitSelection` springs the pill + pages
            // the strip by whole weeks if the tapped day is in another week.
            self?.selectDay(date, animated: true, syncStrip: true)
        }
    }

    private func wireJumpToToday() {
        jumpToToday.action = { [weak self] in self?.handleJumpToToday() }
        jumpToToday.setVisible(!isOnToday, animated: false)
    }

    // MARK: - Data

    /// Re-runs the windowed fetch, re-buckets by day, and refreshes visible pages.
    /// Bound to `store.revision` via the adapter (the `@Query` replacement).
    private func reload() {
        guard let from = pageDates.first else { return }
        let lastDay = pageDates.last ?? from
        let upper = Calendar.current.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
        eventsByDay = adapter.occurrencesByDay(from: from, to: upper)
        refreshVisiblePages()
        // Counts are invalidated on every occurrence mutation; refresh the visible
        // week's badges off the same reactive `revision` edge that drove this reload.
        loadVisibleCounts()
        // Keep the floating pill in sync (selection may have changed elsewhere).
        jumpToToday.setVisible(!isOnToday, animated: true)
    }

    /// Fetches + caches per-day task counts for the selected day's week (with the
    /// store's ±1-week load-ahead margin) and re-renders the strip's badges.
    /// Idempotent — the store skips already-synced weeks unless counts were just
    /// invalidated by a mutation.
    private func loadVisibleCounts() {
        let weekRange = weekStrip.selectedWeekRange
        // Hard early-exit when the visible week hasn't changed since the last dispatch.
        // A bare `store.revision` bump that doesn't move the visible week (Phase 3
        // delta-apply, prefetch warming, completion toggles) must do ZERO count work —
        // not even the visible-week fetch + in-place reconfigure, which on its own still
        // re-dispatched a Task and re-walked the realized tiles on every edge. The store
        // already invalidates the durable counts memo on a real occurrence mutation, so a
        // genuine same-week change re-fetches via the next selection/week-change path.
        guard weekRange != lastLoadedCountsWeek else { return }
        lastLoadedCountsWeek = weekRange
        // (Re)load the visible week — the store memoizes fresh weeks and re-fetches
        // invalidated ones, and `loadCounts` patches badges in place (no `reloadData`).
        Task { await weekStrip.loadCounts(for: weekRange, context: modelContext) }
        // Prefetch the leading-edge weeks' counts in the current scroll direction so
        // the strip's badges are already warm before the user pages into them.
        let prefetchRanges = prefetchCoordinator.computePrefetchCountsWindows(around: weekRange)
        for range in prefetchRanges where range != weekRange {
            Task { await store.ensureCountsSynced(weekRange: range, context: modelContext) }
        }
    }

    /// Computes the coordinator's day-events month buffer for the leading visible
    /// page and dispatches `ensureDaySynced` for each covering month anchor — the
    /// same idempotent store path as the pager's `willDisplay`.
    private func dispatchDayPrefetchBuffer() {
        guard pager.bounds.width > 0 else { return }
        let pageIndex = Int(round(pager.contentOffset.x / pager.bounds.width))
        guard pageDates.indices.contains(pageIndex) else { return }
        let months = prefetchCoordinator.computePrefetchDayMonths(leadingDate: pageDates[pageIndex])
        for month in months {
            Task { await store.ensureDaySynced(month, context: modelContext) }
        }
    }

    /// Reconfigures the currently-visible page cells in place (no reload flash).
    private func refreshVisiblePages() {
        for case let cell as DayPageCell in pager.visibleCells {
            guard let indexPath = pager.indexPath(for: cell) else { continue }
            configure(cell, at: indexPath)
        }
    }

    private func configure(_ cell: DayPageCell, at indexPath: IndexPath) {
        let date = pageDates[indexPath.item]
        cell.configure(
            date: date,
            events: eventsByDay[date] ?? [],
            mode: store.viewMode,
            theme: theme
        )
        cell.onToggle = { [weak self] event in self?.toggleCompletion(event) }
        cell.onSelect = { [weak self] event in
            guard let self else { return }
            self.scopeDelegate?.scope(self, didSelectEvent: event)
        }
    }

    /// Optimistic completion toggle — routed entirely through the store, which
    /// bumps `revision` and re-drives `reload()`.
    private func toggleCompletion(_ event: OccurrenceVM) {
        Task { await store.toggleCompletion(occurrenceKey: event.id, context: modelContext) }
    }

    /// Syncs the month containing the selected day (cheap; early-returns on cache).
    private func syncVisibleDay() {
        Task { await store.ensureDaySynced(store.selectedDate, context: modelContext) }
    }

    // MARK: - Selection / paging

    /// Sets the selected day, updates the store, pages the pager, and (optionally)
    /// aligns the week strip. The single funnel for every selection path.
    private func selectDay(_ date: Date, animated: Bool, syncStrip: Bool) {
        let normalized = CalendarMath.startOfDay(date)
        guard normalized != store.selectedDate else { return }
        store.selectedDate = normalized
        if syncStrip { weekStrip.commitSelection(date: normalized, animated: animated) }
        scrollToSelected(animated: animated)
        jumpToToday.setVisible(!isOnToday, animated: true)
        syncVisibleDay()
        loadVisibleCounts()
    }

    private func scrollToSelected(animated: Bool) {
        let index = indexOfSelectedPage()
        guard pager.numberOfItems(inSection: 0) > index else { return }
        isProgrammaticallyPaging = true
        pager.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: animated)
        // Clear the guard after the (possibly animated) scroll settles.
        DispatchQueue.main.async { [weak self] in self?.isProgrammaticallyPaging = false }
    }

    private func indexOfSelectedPage() -> Int {
        let selected = CalendarMath.startOfDay(store.selectedDate)
        return pageDates.firstIndex(of: selected) ?? indexOfToday()
    }

    private func indexOfToday() -> Int {
        pageDates.firstIndex(of: CalendarMath.startOfDay(.now)) ?? pageDates.count / 2
    }

    private var isOnToday: Bool {
        CalendarMath.isToday(store.selectedDate)
    }

    private func handleJumpToToday() {
        let today = CalendarMath.startOfDay(.now)
        if isOnToday {
            // Already on today — ask the container to zoom one level in toward today.
            scopeDelegate?.scopeDidRequestToday(self)
        } else {
            selectDay(today, animated: true, syncStrip: true)
        }
    }

    /// Called by the host when `store.viewMode` toggled, so pages re-render in the
    /// new mode without losing the current day.
    func viewModeDidChange() {
        refreshVisiblePages()
    }

    // MARK: - Layout

    /// Full-screen-width horizontally-paging sections, one item per day.
    private func makePagerLayout() -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .horizontal
        return UICollectionViewCompositionalLayout(
            sectionProvider: { _, _ in
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .fractionalHeight(1.0)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                return section
            },
            configuration: configuration
        )
    }

    // MARK: - CalendarScopeViewController conformance

    /// Re-styles the whole scope (background, strip, pill, visible pages).
    func apply(theme: CalendarTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        applyTheme()
    }

    private func applyTheme() {
        view.backgroundColor = theme.background
        weekStrip.apply(theme: theme)
        jumpToToday.apply(theme: theme)
        for case let cell as DayPageCell in pager.visibleCells {
            cell.apply(theme: theme)
        }
    }

    /// Enables/disables the pager and per-page inner scrolling for the duration
    /// of a zoom transition (so the pinch/pan don't fight). The week strip and
    /// each page's inner timeline/list scroll are all disabled together.
    func setScrollEnabled(_ isEnabled: Bool) {
        pager.isScrollEnabled = isEnabled
        for case let cell as DayPageCell in pager.visibleCells {
            cell.setInnerScrollEnabled(isEnabled)
        }
    }

    /// Centers the pager (and aligns the strip) on `unit`'s day. Used after a
    /// cross-scope zoom or a Today jump.
    func center(on unit: Date, animated: Bool) {
        let day = CalendarMath.startOfDay(unit)
        store.selectedDate = day
        weekStrip.commitSelection(date: day, animated: animated)
        scrollToSelected(animated: animated)
        jumpToToday.setVisible(!isOnToday, animated: animated)
        loadVisibleCounts()
    }

    /// The day is the innermost scope, so the zoom anchor is the visible day
    /// page's frame in `coordinateSpace` (the cell for `unit`, or the current
    /// page when that day isn't the realized one).
    func anchorFrame(forUnit unit: Date, in coordinateSpace: UICoordinateSpace) -> CGRect? {
        let day = CalendarMath.startOfDay(unit)
        guard let index = pageDates.firstIndex(of: day) else {
            return visiblePageFrame(in: coordinateSpace)
        }
        guard let attributes = pager.layoutAttributesForItem(at: IndexPath(item: index, section: 0)) else {
            return visiblePageFrame(in: coordinateSpace)
        }
        return pager.convert(attributes.frame, to: coordinateSpace)
    }

    private func visiblePageFrame(in coordinateSpace: UICoordinateSpace) -> CGRect? {
        guard let cell = pager.visibleCells.first else { return nil }
        return cell.convert(cell.bounds, to: coordinateSpace)
    }

    /// The day under `point` — for the day scope this is simply the currently
    /// visible day (one page fills the pager), so a pinch always anchors on it.
    func unit(at point: CGPoint, in coordinateSpace: UICoordinateSpace) -> Date? {
        let localPoint = coordinateSpace.convert(point, to: pager)
        if let indexPath = pager.indexPathForItem(at: localPoint) {
            return pageDates[indexPath.item]
        }
        return CalendarMath.startOfDay(store.selectedDate)
    }
}

// MARK: - Pager data source / delegate

extension DayScopeViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        pageDates.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: DayPageCell.reuseIdentifier, for: indexPath
        )
        guard let page = cell as? DayPageCell else { return cell }
        configure(page, at: indexPath)
        return page
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        // Per-day sync as a page becomes visible — cheap, early-returns on cache.
        let date = pageDates[indexPath.item]
        Task { await store.ensureDaySynced(date, context: modelContext) }
    }

    /// THE single per-frame driving path: the pager's live scroll position is the
    /// one source of truth for the strip. We pass the raw fractional page index
    /// (over `pageDates` space) straight down — the strip derives BOTH the pill
    /// frame and its own week content offset from this one value, so they advance
    /// in lockstep and cannot desync. No date math here. Skipped during
    /// programmatic paging (the settle/tap path snaps the pill instead).
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === pager, !isProgrammaticallyPaging else { return }
        guard pager.bounds.width > 0 else { return }
        // NOTE: `prefetchCoordinator.track()` is intentionally NOT called per frame —
        // direction is derived once on settle (see `scrollViewWillEndDragging`).
        let continuousPage = Double(pager.contentOffset.x / pager.bounds.width)
        weekStrip.syncToPager(continuousPageIndex: continuousPage)
    }

    /// A fresh drag starts: drop stale velocity/direction history so a new swipe
    /// isn't biased by the previous one, and record the drag's origin offset so the
    /// settle handler can derive its direction from a single sample (instead of the
    /// per-frame `track()` that used to churn the debounce; see `scrollViewDidScroll`).
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView === pager else { return }
        prefetchCoordinator.resetVelocity()
        dragStartOffsetX = scrollView.contentOffset.x
    }

    /// Feeds the coordinator the drag's start→end offset as a single sample so it
    /// derives a correct scroll direction for the settle-time prefetch buffer,
    /// without the per-frame tracking that caused the lag.
    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        guard scrollView === pager else { return }
        prefetchCoordinator.track(
            offset: CGPoint(x: dragStartOffsetX, y: 0), axis: .horizontal
        ) {}
        prefetchCoordinator.track(
            offset: CGPoint(x: targetContentOffset.pointee.x, y: 0), axis: .horizontal
        ) {}
    }

    /// On settle, derive the centered page and update the selection + strip, then
    /// dispatch the ahead-of-visibility day-events month buffer.
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === pager else { return }
        commitVisiblePageSelection()
        prefetchCoordinator.settleNow { [weak self] in self?.dispatchDayPrefetchBuffer() }
    }

    /// A drag that lifts without deceleration still ends the gesture, so commit the
    /// landed page here too — otherwise `scrollViewDidEndDecelerating` never fires
    /// and the strip keeps a stale committed selection until the next gesture.
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView === pager, !decelerate else { return }
        commitVisiblePageSelection()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView === pager else { return }
        isProgrammaticallyPaging = false
    }

    private func commitVisiblePageSelection() {
        guard pager.bounds.width > 0 else { return }
        let pageIndex = Int(round(pager.contentOffset.x / pager.bounds.width))
        guard pageDates.indices.contains(pageIndex) else { return }
        let date = pageDates[pageIndex]
        guard date != CalendarMath.startOfDay(store.selectedDate) else { return }
        store.selectedDate = date
        weekStrip.commitSelection(date: date, animated: true)
        jumpToToday.setVisible(!isOnToday, animated: true)
        // Selection may have crossed into a new week — load its counts (load-ahead
        // dedup keeps this cheap when the week was already fetched).
        loadVisibleCounts()
        Task { await store.ensureDaySynced(date, context: modelContext) }
    }
}

// MARK: - Pager prefetching (day-events ahead of visibility)

extension DayScopeViewController: UICollectionViewDataSourcePrefetching {

    /// The previously-missing prefetch path for the day pager: maps prefetched page
    /// index paths to their month anchors and syncs those months ahead of becoming
    /// visible. `ensureDaySynced` delegates to `ensureMonthSynced`, which
    /// early-returns on the store's durable `WindowSyncMeta` memo while fresh
    /// (TTL-gated), so the redundant calls are free and idempotent.
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        guard collectionView === pager else { return }
        let months = Set(
            indexPaths
                .filter { pageDates.indices.contains($0.item) }
                .map { CalendarMath.startOfMonth(pageDates[$0.item]) }
        )
        for month in months {
            Task { await store.ensureDaySynced(month, context: modelContext) }
        }
    }
}
