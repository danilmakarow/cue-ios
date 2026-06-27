//
//  YearScopeViewController.swift
//  cue
//

import SwiftData
import UIKit

/// The **year scope** of the UIKit calendar — the most zoomed-out level. An
/// infinitely-vertical-scrolling collection view with one section per year: a
/// large Fraunces year title above a three-column grid of twelve mini-month
/// cells. Tapping a mini-month zooms into the month scope anchored on that cell;
/// a floating Jump-to-Today pill recenters to the current year or, once on it,
/// zooms one level in.
///
/// This is the UIKit replacement for the SwiftUI `YearScopeView` + `YearPage` +
/// `YearMonthCell`; it preserves every behavior — infinite vertical year scroll,
/// twelve mini-months per year, tap-to-zoom, progressive Jump-to-Today, jump-free
/// prepend, locale-driven month order/formatting, theming, and Dynamic Type.
///
/// ## Per-unit sync (same correctness principle as Month)
/// The mini-month cells are the *units* of this scope. As each becomes visible or
/// is prefetched, the **month it represents** syncs itself via
/// `store.ensureMonthSynced(monthAnchor:context:)`, driven from both
/// `collectionView(_:willDisplay:)` and the prefetch data source. Each call
/// early-returns on the store's durable `WindowSyncMeta` memo while fresh
/// (TTL-gated), so calling it for every
/// visible/prefetched mini-month is cheap and **guarantees coverage at any scroll
/// speed** — no centered-only heuristic. After a sync completes the store bumps
/// `revision`; the adapter's `observeRevision` re-runs the windowed fetch (though
/// the year scope renders no event density, this keeps the shared pipeline warm so
/// a zoom-in lands on already-synced months).
///
/// ## Construction (for the Integration engineer)
/// The container builds it with the four shared dependencies and an initial theme:
/// ```swift
/// let year = YearScopeViewController(
///     store: store,
///     adapter: adapter,
///     modelContext: modelContext,
///     theme: theme
/// )
/// year.scopeDelegate = container
/// ```
/// No further wiring is needed: it observes `store.revision` itself (via the
/// adapter), syncs visible/prefetched months itself, and reports unit selection /
/// Today through `scopeDelegate`. Push the theme on change via ``apply(theme:)``.
@MainActor
final class YearScopeViewController: UIViewController, CalendarScopeViewController {

    // MARK: - CalendarScopeViewController

    let kind: CalendarScopeKind = .year
    weak var scopeDelegate: CalendarScopeDelegate?

    // MARK: - Dependencies

    private let store: CalendarStore
    private let adapter: CalendarDataAdapter
    private let modelContext: ModelContext
    private var theme: CalendarTheme

    /// Shared direction/velocity prefetch planner — computes an ahead-of-visibility
    /// month buffer (capped) routed through the same `syncMonth` path as
    /// `willDisplay`, so zoom-out flings don't fan out an unbounded sync burst.
    private let prefetchCoordinator: PrefetchCoordinator

    // MARK: - Infinite-scroll window

    /// The sliding window of year-start anchors (one per section). Seeded around
    /// the centered year; grown/trimmed on scroll-settle only.
    private var window = InfiniteSectionWindow(step: .year)

    /// The year the scope considers "centered" — drives Jump-to-Today and the
    /// edge-growth decision. Updated on scroll-settle.
    private var centeredYear: Date

    /// Guards programmatic scrolls from being treated as user settles.
    private var isProgrammaticallyScrolling = false

    /// A center request that arrived before the collection view had a non-zero
    /// size (e.g. the zoom controller centering a freshly-mounted scope on the
    /// same runloop it's added). `scrollToItem` silently no-ops on a zero-sized
    /// collection view, so we stash the target and re-apply it once
    /// `viewDidLayoutSubviews` reports real bounds — otherwise the scope lands on
    /// the oldest seeded year instead of the current/focused year.
    private var pendingCenter: (year: Date, animated: Bool)?

    // MARK: - Views

    private let jumpToToday = DayJumpToTodayButton()

    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: YearLayout.make())
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.showsVerticalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .never
        view.delegate = self
        view.isPrefetchingEnabled = true
        view.prefetchDataSource = self
        view.register(
            YearMiniMonthCell.self,
            forCellWithReuseIdentifier: YearMiniMonthCell.reuseIdentifier
        )
        view.register(
            YearTitleHeaderView.self,
            forSupplementaryViewOfKind: YearLayout.yearTitleKind,
            withReuseIdentifier: YearTitleHeaderView.reuseIdentifier
        )
        return view
    }()

    private lazy var dataSource = makeDataSource()

    // MARK: - Init

    /// Designated initializer. Injected by the container.
    ///
    /// - Parameters:
    ///   - store: the shared calendar store (selection, per-month sync, revision).
    ///   - adapter: the windowed read-side bridge over SwiftData; this VC observes
    ///     its `revision` to keep the shared sync pipeline reactive.
    ///   - modelContext: the SwiftData context passed to store sync calls.
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
        self.centeredYear = CalendarMath.startOfYear(store.selectedDate)
        super.init(nibName: nil, bundle: nil)
        window.seed(around: centeredYear)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
        wireJumpToToday()
        applyTheme()

        // One-time reactive registration: re-style visible cells on data change so
        // a zoom-in finds freshly-synced months without rebuilding the snapshot.
        adapter.observeRevision { [weak self] in self?.reload() }

        applySnapshot(animated: false)
        // Defer the initial center until the collection view has real bounds —
        // `viewDidLoad` runs before layout, so an immediate scroll would no-op.
        requestCenter(on: centeredYear, animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Drain a center request that was queued before the collection view had a
        // non-zero size, now that layout has given it real bounds.
        guard let pending = pendingCenter, collectionView.bounds.width > 0 else { return }
        pendingCenter = nil
        scrollToYear(pending.year, animated: pending.animated)
    }

    // MARK: - Setup

    private func setUpViews() {
        view.backgroundColor = theme.background

        jumpToToday.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        view.addSubview(jumpToToday)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            jumpToToday.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Spacing.xl),
            jumpToToday.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Spacing.xxl),
        ])
    }

    private func wireJumpToToday() {
        jumpToToday.action = { [weak self] in self?.handleJumpToToday() }
        // The year overview keeps the pill always visible with a progressive action
        // (recenter when off the current year, else zoom one level in).
        jumpToToday.setVisible(true, animated: false)
    }

    // MARK: - Data source

    /// Builds the diffable data source: each item is a month anchor rendered as a
    /// mini-month cell; the single supplementary kind is the per-section year title.
    private func makeDataSource() -> UICollectionViewDiffableDataSource<Date, Date> {
        let source = UICollectionViewDiffableDataSource<Date, Date>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, monthAnchor in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: YearMiniMonthCell.reuseIdentifier, for: indexPath
            )
            guard let self, let miniCell = cell as? YearMiniMonthCell else { return cell }
            self.configure(miniCell, with: monthAnchor)
            return miniCell
        }

        source.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            self?.supplementaryView(in: collectionView, kind: kind, at: indexPath)
        }
        return source
    }

    /// Configures a mini-month cell from its month anchor — the model is memoized,
    /// so this stays allocation-light while scrolling.
    private func configure(_ cell: YearMiniMonthCell, with monthAnchor: Date) {
        let todayMonth = CalendarMath.startOfMonth(.now)
        cell.configure(
            model: MonthGridModel.model(for: monthAnchor),
            todayKey: monthAnchor == todayMonth ? CalendarMath.startOfDay(.now) : nil,
            theme: theme
        )
    }

    /// Builds a supplementary view for the given kind (only the year title).
    private func supplementaryView(
        in collectionView: UICollectionView,
        kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView? {
        guard kind == YearLayout.yearTitleKind else { return nil }
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: YearTitleHeaderView.reuseIdentifier,
            for: indexPath
        )
        guard let titleHeader = header as? YearTitleHeaderView,
              let year = year(forSection: indexPath.section) else { return header }
        titleHeader.configure(title: heading(for: year), theme: theme)
        return titleHeader
    }

    /// Applies a snapshot built from the current window. Wrapped in
    /// `performWithoutAnimation` so prepend growth never animates a content shift.
    private func applySnapshot(animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Date, Date>()
        for year in window.anchors {
            snapshot.appendSections([year])
            snapshot.appendItems(CalendarMath.monthsOfYear(year), toSection: year)
        }
        if animated {
            dataSource.apply(snapshot, animatingDifferences: true)
        } else {
            UIView.performWithoutAnimation {
                dataSource.apply(snapshot, animatingDifferences: false)
            }
        }
    }

    // MARK: - Data

    /// Re-styles the visible mini-months in place after a data change. The year
    /// scope renders no event density, so there are no titles to rebuild — this
    /// only repaints the today highlight (e.g. across a midnight rollover) and
    /// keeps the shared `revision` pipeline live.
    private func reload() {
        reconfigureVisible()
    }

    /// Reconfigures the currently-visible items in place (no reload flash).
    private func reconfigureVisible() {
        var snapshot = dataSource.snapshot()
        let visibleItems = collectionView.indexPathsForVisibleItems.compactMap {
            dataSource.itemIdentifier(for: $0)
        }
        guard !visibleItems.isEmpty else { return }
        snapshot.reconfigureItems(visibleItems)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Per-unit sync

    /// Syncs a single month's occurrences. Idempotent and cheap — the store
    /// early-returns on its durable `WindowSyncMeta` memo while fresh (TTL-gated) —
    /// so it is safe to call for every
    /// visible and prefetched mini-month. Driven from `willDisplay` and
    /// `prefetchItemsAt` so coverage is independent of scroll speed.
    private func syncMonth(_ month: Date) {
        Task { await store.ensureMonthSynced(CalendarMath.startOfMonth(month), context: modelContext) }
    }

    /// Syncs all twelve months of a year. Called as a year section comes into view
    /// so a subsequent zoom-in lands on already-synced months.
    private func syncYear(_ year: Date) {
        for month in CalendarMath.monthsOfYear(year) { syncMonth(month) }
    }

    // MARK: - Prefetch (ahead-of-visibility buffer, capped)

    /// Computes the coordinator's direction/velocity-aware month buffer (capped at
    /// `yearConcurrentSyncCap`) for the leading visible mini-month and dispatches
    /// `syncMonth` for each member — the same idempotent path as `willDisplay`.
    private func dispatchYearPrefetchBuffer() {
        guard let leading = leadingVisibleMonth() else { return }
        // Clamp the buffer against EVERY windowed month anchor (not just the visible
        // ones) so the ahead-stride can actually reach months beyond the visible
        // edge — that's the whole point of prefetching.
        let months = prefetchCoordinator.computePrefetchYearMonths(
            leadingMonth: leading,
            monthAnchors: windowedMonthAnchors()
        )
        for month in months { syncMonth(month) }
    }

    /// The mini-month anchor at the leading edge of the viewport in the current
    /// scroll direction. Falls back to the centered year's January.
    private func leadingVisibleMonth() -> Date? {
        let anchors = visibleMonthAnchors()
        guard !anchors.isEmpty else { return CalendarMath.startOfMonth(centeredYear) }
        return prefetchCoordinator.direction.isBackward() ? anchors.first : anchors.last
    }

    /// The month anchors of the currently-visible year sections, ascending — used to
    /// locate the leading visible edge.
    private func visibleMonthAnchors() -> [Date] {
        collectionView.indexPathsForVisibleItems
            .sorted { lhs, rhs in
                lhs.section != rhs.section ? lhs.section < rhs.section : lhs.item < rhs.item
            }
            .compactMap { dataSource.itemIdentifier(for: $0) }
    }

    /// Every month anchor across ALL windowed years (twelve per year section),
    /// ascending — the bound the coordinator clamps its buffer to, so the buffer can
    /// extend past the visible edge into materialized-but-offscreen months.
    private func windowedMonthAnchors() -> [Date] {
        window.anchors.flatMap { CalendarMath.monthsOfYear($0) }
    }

    // MARK: - Window growth (scroll-settle only)

    /// On settle, recompute the centered year, grow the window if the centered
    /// section nears an edge, and correct `contentOffset` on prepend so the
    /// viewport doesn't jump. Never called mid-fling, so a fast flick can't run the
    /// window away.
    private func handleScrollSettled() {
        guard let centered = centeredYearFromViewport() else { return }
        centeredYear = centered
        jumpToToday.setVisible(true, animated: true)

        guard let index = window.index(of: centered) else { return }

        if window.isNearLeadingEdge(of: index) {
            growLeading()
        } else if window.isNearTrailingEdge(of: index) {
            growTrailing()
        }
    }

    /// Prepends older years and corrects `contentOffset` by the prepended height so
    /// the viewport stays visually fixed. Every section is a fixed height plus a
    /// fixed inter-section gap (`YearLayout.sectionAdvance`), so the shift is exact.
    private func growLeading() {
        let added = window.prepend()
        guard !added.isEmpty else { return }
        let trimmed = window.trimTrailing()
        evictWindowsAndRows(yearAnchors: trimmed)

        let shift = CGFloat(added.count) * YearLayout.sectionAdvance
        let priorOffset = collectionView.contentOffset
        applySnapshot(animated: false)
        // Apply the correction synchronously after the snapshot commits its new
        // content size, before the next frame paints.
        collectionView.setContentOffset(
            CGPoint(x: priorOffset.x, y: priorOffset.y + shift),
            animated: false
        )
        for year in added { syncYear(year) }
    }

    /// Appends newer years and trims the far (oldest) edge. No offset correction
    /// needed — growth below the viewport doesn't move what's on screen.
    private func growTrailing() {
        let added = window.append()
        guard !added.isEmpty else { return }
        let trimmed = window.trimLeading()
        evictWindowsAndRows(yearAnchors: trimmed)
        applySnapshot(animated: false)
        for year in added { syncYear(year) }
    }

    // MARK: - Eviction

    /// Atomically evicts the durable `WindowSyncMeta` memos and persisted
    /// `TaskItem` rows for every month of each trimmed *year*, so the on-device
    /// cache stays bounded alongside the in-memory section window. The year scope
    /// syncs per month (`syncYear` fans out to `ensureMonthSynced`), so eviction is
    /// likewise per month — expanding each trimmed year anchor to its 12 month
    /// anchors and handing them to the store's atomic month-evict.
    private func evictWindowsAndRows(yearAnchors: [Date]) {
        guard !yearAnchors.isEmpty else { return }
        let monthAnchors = yearAnchors.flatMap { CalendarMath.monthsOfYear($0) }
        store.evictMonthWindows(monthAnchors, context: modelContext)
    }

    // MARK: - Centered-year resolution

    /// The year whose section contains the vertical center of the viewport.
    private func centeredYearFromViewport() -> Date? {
        let midPoint = CGPoint(
            x: collectionView.bounds.midX,
            y: collectionView.contentOffset.y + collectionView.bounds.midY
        )
        guard let indexPath = collectionView.indexPathForItem(at: midPoint)
            ?? nearestIndexPath(to: midPoint) else { return centeredYear }
        return year(forSection: indexPath.section)
    }

    /// Falls back to the closest visible item when the midpoint lands in a gap
    /// (e.g. over a title strip or the inter-section spacing), so `centeredYear`
    /// always resolves.
    private func nearestIndexPath(to point: CGPoint) -> IndexPath? {
        collectionView.indexPathsForVisibleItems
            .min { lhs, rhs in
                let lhsY = collectionView.layoutAttributesForItem(at: lhs)?.center.y ?? .greatestFiniteMagnitude
                let rhsY = collectionView.layoutAttributesForItem(at: rhs)?.center.y ?? .greatestFiniteMagnitude
                return abs(lhsY - point.y) < abs(rhsY - point.y)
            }
    }

    // MARK: - Section ↔ year mapping

    /// The year anchor backing `section`, or nil when out of range.
    private func year(forSection section: Int) -> Date? {
        guard window.anchors.indices.contains(section) else { return nil }
        return window.anchors[section]
    }

    // MARK: - Headings

    /// The year heading (e.g. "2026"), formatted from the anchor.
    private func heading(for year: Date) -> String {
        year.formatted(.dateTime.year())
    }

    // MARK: - Jump-to-Today

    /// Progressive "Today": if the centered year isn't the current year, scroll it
    /// back into view; if it already is, ask the container to zoom one level into
    /// today's month via `scopeDidRequestToday` — mirroring the SwiftUI behavior.
    private func handleJumpToToday() {
        let currentYear = CalendarMath.startOfYear(.now)
        if centeredYear == currentYear {
            scopeDelegate?.scopeDidRequestToday(self)
        } else {
            scrollToCurrentYear()
        }
    }

    /// Brings the current year back into the window (extending it if the user has
    /// scrolled far away) and centers on it.
    private func scrollToCurrentYear() {
        let currentYear = CalendarMath.startOfYear(.now)
        if !window.contains(currentYear) {
            window.seed(around: currentYear)
            applySnapshot(animated: false)
        }
        centeredYear = currentYear
        requestCenter(on: currentYear, animated: true)
        syncYear(currentYear)
    }

    /// Centers on `year` if the collection view already has real bounds; else
    /// queues the request for the next `viewDidLayoutSubviews`. The single funnel
    /// that makes centering robust to layout timing — both the initial center and
    /// a cross-scope zoom land correctly whether or not the view has laid out yet.
    private func requestCenter(on year: Date, animated: Bool) {
        guard collectionView.bounds.width > 0 else {
            pendingCenter = (year, animated)
            return
        }
        scrollToYear(year, animated: animated)
    }

    /// Centers the scope on `year`'s section without animating a layout shift when
    /// not requested.
    private func scrollToYear(_ year: Date, animated: Bool) {
        guard let section = window.index(of: CalendarMath.startOfYear(year)),
              collectionView.numberOfSections > section,
              collectionView.numberOfItems(inSection: section) > 0 else { return }
        isProgrammaticallyScrolling = true
        let target = IndexPath(item: 0, section: section)
        collectionView.scrollToItem(at: target, at: .top, animated: animated)
        DispatchQueue.main.async { [weak self] in self?.isProgrammaticallyScrolling = false }
    }

    // MARK: - CalendarScopeViewController conformance

    /// Re-styles the whole scope (background, pill, visible cells + titles).
    func apply(theme: CalendarTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        applyTheme()
    }

    private func applyTheme() {
        view.backgroundColor = theme.background
        jumpToToday.apply(theme: theme)
        for case let cell as YearMiniMonthCell in collectionView.visibleCells {
            cell.apply(theme: theme)
        }
        for indexPath in collectionView.indexPathsForVisibleSupplementaryElements(ofKind: YearLayout.yearTitleKind) {
            let view = collectionView.supplementaryView(forElementKind: YearLayout.yearTitleKind, at: indexPath)
            if let title = view as? YearTitleHeaderView, let year = year(forSection: indexPath.section) {
                title.configure(title: heading(for: year), theme: theme)
            }
        }
    }

    /// Enables/disables the scope's scrolling for the duration of a zoom transition
    /// so the pinch/pan don't fight.
    func setScrollEnabled(_ isEnabled: Bool) {
        collectionView.isScrollEnabled = isEnabled
    }

    /// Centers the scope on `unit`'s year. `unit` may be a year-start or a
    /// month-start (after a zoom-out from month); either way we center on the
    /// containing year. Extends the window first if that year isn't currently held.
    func center(on unit: Date, animated: Bool) {
        let year = CalendarMath.startOfYear(unit)
        if !window.contains(year) {
            window.seed(around: year)
            applySnapshot(animated: false)
        }
        centeredYear = year
        requestCenter(on: year, animated: animated)
        syncYear(year)
    }

    /// The frame of `unit`'s mini-month cell, converted into `coordinateSpace`, or
    /// nil when that cell isn't currently realized. `unit` is normalized to its
    /// month anchor (the mini-month identity); the zoom controller anchors the
    /// year → month cross-scale on this rect.
    func anchorFrame(forUnit unit: Date, in coordinateSpace: UICoordinateSpace) -> CGRect? {
        let month = CalendarMath.startOfMonth(unit)
        guard let indexPath = dataSource.indexPath(for: month),
              let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
            return nil
        }
        return collectionView.convert(attributes.frame, to: coordinateSpace)
    }

    /// The month whose mini-month cell contains `point` (expressed in
    /// `coordinateSpace`), or nil when no mini-month is hit — used to pick the
    /// anchor cell under a pinch's start point.
    func unit(at point: CGPoint, in coordinateSpace: UICoordinateSpace) -> Date? {
        let localPoint = coordinateSpace.convert(point, to: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: localPoint),
              let month = dataSource.itemIdentifier(for: indexPath) else { return nil }
        return month
    }
}

// MARK: - Collection view delegate

extension YearScopeViewController: UICollectionViewDelegate {

    /// Tapping a mini-month asks the container to zoom into the month scope
    /// anchored on that cell.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let monthAnchor = dataSource.itemIdentifier(for: indexPath),
              let attributes = collectionView.layoutAttributesForItem(at: indexPath) else { return }
        // Report the tapped cell's frame in the container's coordinate space so the
        // zoom controller can anchor the zoom-in on it.
        let container = scopeDelegate as? UIViewController
        let space: UICoordinateSpace = container?.view ?? view
        let frame = collectionView.convert(attributes.frame, to: space)
        scopeDelegate?.scope(self, didSelectUnit: monthAnchor, cellFrame: frame)
    }

    /// Per-unit self-sync as a mini-month becomes visible — the month it
    /// represents syncs itself; `ensureMonthSynced` early-returns on cache.
    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let monthAnchor = dataSource.itemIdentifier(for: indexPath) else { return }
        syncMonth(monthAnchor)
    }

    // MARK: Scroll tracking (prefetch)

    /// Feeds the coordinator each offset sample so it can derive direction +
    /// velocity and (debounced) dispatch the capped ahead-of-visibility month
    /// buffer. Skips programmatic scrolls so a centering animation doesn't pollute
    /// the estimate.
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === collectionView, !isProgrammaticallyScrolling else { return }
        prefetchCoordinator.track(offset: scrollView.contentOffset, axis: .vertical) { [weak self] in
            self?.dispatchYearPrefetchBuffer()
        }
    }

    /// A fresh drag starts: drop stale velocity/direction history.
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }
        prefetchCoordinator.resetVelocity()
    }

    // MARK: Scroll settle

    /// Window growth + offset correction happen only once motion settles. Also
    /// runs an immediate settle-sync of the now-visible window + buffer.
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }
        handleScrollSettled()
        prefetchCoordinator.settleNow { [weak self] in self?.dispatchYearPrefetchBuffer() }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView === collectionView, !decelerate else { return }
        handleScrollSettled()
        prefetchCoordinator.settleNow { [weak self] in self?.dispatchYearPrefetchBuffer() }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }
        isProgrammaticallyScrolling = false
    }
}

// MARK: - Prefetching (per-unit sync, prefetch path)

extension YearScopeViewController: UICollectionViewDataSourcePrefetching {

    /// Mini-months sync as soon as their cells are *prefetched* — ahead of becoming
    /// visible — so even a fast fling that skips `willDisplay` for intermediate
    /// months still triggers their sync. `ensureMonthSynced` early-returns on
    /// cache, so the redundant calls are free.
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let months = Set(indexPaths.compactMap { dataSource.itemIdentifier(for: $0) })
        for month in months { syncMonth(month) }
    }
}
