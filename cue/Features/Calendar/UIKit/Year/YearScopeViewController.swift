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
/// ## Sync throttle (bounded concurrency + coalescing)
/// A fast zoom-out/scroll materializes a whole year of mini-months at once, and
/// both `willDisplay` and the prefetch source fire a month sync for each — so a
/// naive fire-and-forget per call would launch 12+ (up to ~36 across the seeded
/// years) concurrent `ensureMonthSynced` tasks, whose `isLoading`/`revision`/
/// `context` churn stalls the main actor and delays the zoom-out/close. Every month
/// sync therefore funnels through a single coalescing pump
/// (``enqueueMonthSync(_:)`` → ``pumpMonthSyncs()``): duplicate month requests are
/// dropped and the queue is drained by at most ``maxConcurrentMonthSyncs`` serial
/// workers, so at any instant only one or two syncs are actually in flight.
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

    /// How many years to seed on each side of the centered year (so the window
    /// holds `2 * yearSeedRadius + 1` sections). Small on purpose: the design shows
    /// only ~3 years (a tail-peek, the full current year, a head-peek), and each
    /// year section is 12 mini-months. The `InfiniteSectionWindow` DEFAULT radius
    /// (18 → 37 years → ~444 mini-month cells materialized + a 37-year windowed
    /// occurrence fetch) is what made `applySnapshot` stall the year scope; a tight
    /// window with cheap on-settle growth fixes it while keeping infinite scroll.
    private static let yearSeedRadius = 2

    /// The sliding window of year-start anchors (one per section). Seeded around the
    /// centered year (see ``yearSeedRadius``); grown/trimmed on scroll-settle only.
    /// Small growth/cap sized for years (not months): `growBy 3`, `maxWindowSize 9`,
    /// `edgeThreshold 1` — grow a few years at a time, keep at most ~9 in memory.
    private var window = InfiniteSectionWindow(
        step: .year,
        growBy: 3,
        maxWindowSize: 9,
        edgeThreshold: 1
    )

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

    /// Whether the user has scrolled the year overview away from where it opened.
    /// Drives the progressive Today button (mirrors Month/Day): once scrolled, a
    /// tap scrolls back to the current year and resets this; if never scrolled, a
    /// tap zooms one level into today's month. Reset on a Today recenter and on a
    /// cross-scope `center(on:)`.
    private var hasScrolled = false

    // MARK: - Per-day heatmap density

    /// Per-day task-occurrence counts for every windowed year, keyed by
    /// `startOfDay`. Drives the mini-month heatmap tint. Rebuilt from a single
    /// windowed fetch on every `revision` change (and as years sync in), exactly
    /// like the Month scope's `chipsByDay`. Days with no tasks are absent (⇒ 0).
    private var countsByDay: [Date: Int] = [:]

    // MARK: - Sync coalescing / throttle

    /// Years whose month-sync fan-out is currently in flight, so a re-entrant
    /// `syncYear` (fast scroll re-triggering `willDisplay`/prefetch for the same
    /// year) doesn't launch a second bounded burst for it.
    private var syncingYears: Set<Date> = []

    /// Ceiling on how many `ensureMonthSynced` may run **at once** across the whole
    /// scope. A fast zoom-out/scroll materializes twelve mini-months (×3 seeded
    /// years on open) and both `willDisplay` and the prefetch source fire
    /// `syncMonth` for each — previously spawning 12–36 concurrent
    /// fire-and-forget tasks whose `isLoading`/`revision`/`context` churn stalled
    /// the main actor and delayed the zoom-out/close. All month syncs now funnel
    /// through ``enqueueMonthSync(_:)`` into a small pool of at most this many
    /// serial drain workers, with duplicate month requests dropped.
    private static let maxConcurrentMonthSyncs = 2

    /// Months requested but not yet started, in insertion order, deduplicated by
    /// ``queuedMonths``. Drained by the ``runningMonthSyncWorkers`` pool.
    private var pendingMonthSyncs: [Date] = []

    /// Membership mirror of `pendingMonthSyncs` (+ the in-flight month keys) so a
    /// re-requested month is dropped rather than enqueued twice — the coalescing
    /// that stops fast scrolling from stacking duplicate syncs for the same month.
    private var queuedMonths: Set<Date> = []

    /// How many drain workers are currently running, capped at
    /// ``maxConcurrentMonthSyncs`` — the live concurrency the throttle enforces.
    private var runningMonthSyncWorkers = 0

    /// Per-year set of that year's month anchors still queued or in flight, so a
    /// year's loading spinner is dismissed only once its *last* month settles even
    /// though the months drain through the shared throttle (out of year order). A
    /// set (not a count) so it stays correct when a month is already pending for a
    /// different reason or completes between enqueues. A year is removed from
    /// `syncingYears` when its set empties.
    private var pendingMonthsByYear: [Date: Set<Date>] = [:]

    /// The year the loading overlay is currently gating on, if any — the last year
    /// whose sync we surfaced a spinner for. Cleared when its sync settles.
    private var loadingYear: Date?

    // MARK: - Reload debounce

    /// Trailing-debounce window for the reactive reload. A single year sync bumps
    /// `revision` twelve times (once per month), so an undebounced reload would run
    /// twelve full windowed count-fetches back to back; coalescing to one trailing
    /// reload keeps that work off the hot path (mirrors the Month scope's fix).
    private static let reloadDebounce: TimeInterval = 0.12

    /// The pending debounced reload, cancelled + rescheduled on each `revision`.
    private var reloadWorkItem: DispatchWorkItem?

    // MARK: - Views

    private let jumpToToday = DayJumpToTodayButton()
    private let loadingOverlay = YearSyncOverlayView()

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
        window.seed(around: centeredYear, radius: Self.yearSeedRadius)
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

        // One-time reactive registration: rebuild heatmap counts + re-style visible
        // cells on data change so a zoom-in finds freshly-synced months without
        // rebuilding the snapshot. Debounced so a year sync's twelve `revision`
        // bumps coalesce into a single trailing reload.
        adapter.observeRevision { [weak self] in self?.scheduleReload() }

        applySnapshot(animated: false)
        reload()
        // Fill the initially-centered year's heatmap (coalesced + throttled), which
        // also surfaces the loading spinner on a cold launch.
        syncYear(centeredYear, surfaceLoading: true)
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
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        view.addSubview(loadingOverlay)
        view.addSubview(jumpToToday)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // A small floating spinner pinned bottom-center, ABOVE the tab bar — it
            // never blocks the grid (which renders + closes immediately), it only
            // signals that the visible year is still filling its heatmap.
            loadingOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Spacing.xxl),

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

    /// Configures a mini-month cell from its month anchor — the model is memoized
    /// and the per-day counts are a dictionary slice, so this stays allocation-light
    /// while scrolling.
    private func configure(_ cell: YearMiniMonthCell, with monthAnchor: Date) {
        let todayMonth = CalendarMath.startOfMonth(.now)
        cell.configure(
            model: MonthGridModel.model(for: monthAnchor),
            countsByDay: countsForMonth(monthAnchor),
            todayKey: monthAnchor == todayMonth ? CalendarMath.startOfDay(.now) : nil,
            theme: theme
        )
    }

    /// The per-day counts restricted to `monthAnchor`'s `[startOfMonth,
    /// startOfNextMonth)` — the slice a single mini-month heatmap needs. Handing a
    /// small per-month dictionary (rather than the whole windowed map) keeps each
    /// cell's draw pass reading only its own days.
    private func countsForMonth(_ monthAnchor: Date) -> [Date: Int] {
        let (from, to) = CalendarMath.monthBounds(monthAnchor)
        return countsByDay.filter { $0.key >= from && $0.key < to }
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
        titleHeader.configure(title: heading(for: year), isCurrentYear: isCurrentYear(year), theme: theme)
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

    /// Schedules a debounced reload on the main queue, cancelling any pending one.
    /// The store bumps `revision` once per month-sync completion; a year sync would
    /// otherwise fire twelve full re-fetches back to back. Coalescing to a single
    /// trailing reload keeps that work off the hot path.
    private func scheduleReload() {
        reloadWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.reload() }
        reloadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reloadDebounce, execute: workItem)
    }

    /// Rebuilds the per-day heatmap counts from a single windowed fetch, then
    /// re-styles the visible mini-months in place. Bound (debounced) to
    /// `store.revision` via the adapter (the `@Query` replacement) and called after a
    /// year's months finish syncing, so the heatmap tints fill in as data arrives.
    private func reload() {
        rebuildCounts()
        reconfigureVisible()
    }

    /// Rebuilds `countsByDay` from a single fetch spanning only the **visible year(s)
    /// (padded one year on each side)**, grouped by day. The old version fetched the
    /// entire multi-year section window `[firstYear, yearAfterLast)` — up to 9 years —
    /// on every debounced reload, even though only the ~3 on-screen years render a
    /// heatmap; the pad covers the years a partial scroll straddles so their tints are
    /// ready before they fully settle. Each cell still slices out its own days from
    /// the result; a cell outside the fetched range simply reads zero (no fill) until
    /// it scrolls into range and a settle reload widens the fetch to include it.
    private func rebuildCounts() {
        guard let (fromYear, toYear) = visibleYearRange() else { return }
        let from = CalendarMath.startOfYear(fromYear)
        // Exclusive upper bound: the start of the year after the last visible year
        // (December's `monthBounds` upper bound is the next year's January 1).
        let lastDecember = CalendarMath.monthsOfYear(toYear).last ?? toYear
        let to = CalendarMath.monthBounds(lastDecember).to
        let byDay = adapter.occurrencesByDay(from: from, to: to)
        var counts: [Date: Int] = [:]
        for (day, occurrences) in byDay {
            counts[day] = occurrences.count
        }
        countsByDay = counts
    }

    /// The `(first, last)` year anchors the heatmap fetch should span: the currently
    /// on-screen years padded one year on each side, clamped to the section window.
    /// Falls back to the centered year ± 1 (still window-clamped) before the
    /// collection view has visible items (e.g. the first `reload()` pre-layout), so
    /// the initial center's heatmap still fills. Returns nil only when the window is
    /// empty.
    private func visibleYearRange() -> (first: Date, last: Date)? {
        guard let windowFirst = window.anchors.first, let windowLast = window.anchors.last else {
            return nil
        }
        let visibleYears = Set(
            collectionView.indexPathsForVisibleItems.compactMap { year(forSection: $0.section) }
        )
        let lowerCenter = CalendarMath.startOfYear(visibleYears.min() ?? centeredYear)
        let upperCenter = CalendarMath.startOfYear(visibleYears.max() ?? centeredYear)
        // Pad one year on each side, then clamp into the materialized window so we
        // never fetch a range with no cells to tint.
        let padLower = CalendarMath.years(before: lowerCenter, count: 1).first ?? lowerCenter
        let padUpper = CalendarMath.years(after: upperCenter, count: 1).last ?? upperCenter
        let lower = max(padLower, windowFirst)
        let upper = min(padUpper, windowLast)
        return (lower, upper)
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

    // MARK: - Per-unit sync (coalesced + throttled)

    /// Requests a single month's occurrences via the shared throttle. Idempotent and
    /// cheap — the store early-returns on its durable `WindowSyncMeta` memo while
    /// fresh (TTL-gated) — so it is safe to call for every visible and prefetched
    /// mini-month. Driven from `willDisplay` and `prefetchItemsAt`.
    ///
    /// Unlike the old fire-and-forget `Task { ensureMonthSynced }`, this funnels
    /// through ``enqueueMonthSync(_:)`` so a fast scroll that materializes a dozen
    /// mini-months at once can never launch a dozen concurrent syncs — duplicates
    /// are dropped and at most ``maxConcurrentMonthSyncs`` run at a time.
    private func syncMonth(_ month: Date) {
        enqueueMonthSync(CalendarMath.startOfMonth(month))
    }

    /// Requests all twelve months of a year through the same shared throttle rather
    /// than fanning out twelve unstructured `Task`s at once. This is the fix for the
    /// year-scope lag: the old whole-year path launched 12 concurrent
    /// `ensureMonthSynced` per visible year (×3 seeded years on open = up to 36 in
    /// flight), whose `isLoading`/`revision`/`context` churn stalled the main actor
    /// and delayed the zoom-out and close.
    ///
    /// Now the year's months are enqueued into the coalescing pump, which drains
    /// them through at most ``maxConcurrentMonthSyncs`` serial workers. The whole
    /// pass is coalesced so a re-entrant call for an in-flight year is a no-op (fast
    /// scroll re-fires `willDisplay`/prefetch for the same visible year repeatedly),
    /// and gated by a loading overlay so the grid renders + closes immediately while
    /// the heatmap fills in behind the spinner. The spinner is dismissed only once
    /// the year's *last* month drains (tracked in ``pendingMonthsByYear``), since
    /// the months no longer complete in a single ordered task.
    ///
    /// - Parameters:
    ///   - year: the year whose months to sync.
    ///   - surfaceLoading: whether to gate the loading spinner on this sync. `true`
    ///     for the visible/centered year (the user is looking at it); `false` for
    ///     offscreen growth/prefetch years, so the spinner never tracks a year the
    ///     user can't see.
    private func syncYear(_ year: Date, surfaceLoading: Bool = false) {
        let anchor = CalendarMath.startOfYear(year)
        // Coalesce: don't relaunch a burst for a year already syncing (fast scroll
        // re-fires willDisplay/prefetch for the same visible year repeatedly).
        guard !syncingYears.contains(anchor) else {
            // Already in flight, but a now-visible year should still claim the
            // spinner if this call is the one surfacing it.
            if surfaceLoading { beginLoading(for: anchor) }
            return
        }
        syncingYears.insert(anchor)
        if surfaceLoading { beginLoading(for: anchor) }

        let months = CalendarMath.monthsOfYear(anchor).map { CalendarMath.startOfMonth($0) }
        // Track exactly the months this year is still waiting on. Enqueue first so a
        // month that turns out to be already-drained isn't recorded as pending (its
        // completion has already fired and won't come again). Any month still in the
        // shared queue after enqueuing — freshly added or already pending from a
        // single-month request — will emit a `finishMonthSync`, so it belongs here.
        for month in months { enqueueMonthSync(month) }
        let waiting = months.filter { queuedMonths.contains($0) }
        guard !waiting.isEmpty else {
            // Everything was already synced (nothing left in flight) — nothing will
            // decrement, so settle the year immediately.
            syncingYears.remove(anchor)
            endLoading(for: anchor)
            return
        }
        pendingMonthsByYear[anchor] = Set(waiting)
    }

    // MARK: - Month-sync throttle (coalescing pump)

    /// Adds `month` (a `startOfMonth`) to the drain queue unless it is already
    /// queued or in flight (dedup via ``queuedMonths``), then kicks the pump. This
    /// is the single choke point every month sync passes through, so no scroll speed
    /// can stack duplicate or unbounded-concurrent syncs.
    private func enqueueMonthSync(_ month: Date) {
        guard !queuedMonths.contains(month) else { return }
        queuedMonths.insert(month)
        pendingMonthSyncs.append(month)
        pumpMonthSyncs()
    }

    /// Starts drain workers up to ``maxConcurrentMonthSyncs`` while the queue has
    /// work. Each worker awaits one `ensureMonthSynced`, then re-pumps — so the pool
    /// self-refills as syncs complete but never exceeds the concurrency cap.
    ///
    /// Staying on `@MainActor` (each worker `Task` inherits this scope's isolation)
    /// keeps the non-`Sendable` `ModelContext` from crossing an isolation boundary —
    /// the reason a `TaskGroup` of unstructured child tasks isn't used here.
    private func pumpMonthSyncs() {
        while runningMonthSyncWorkers < Self.maxConcurrentMonthSyncs, !pendingMonthSyncs.isEmpty {
            let month = pendingMonthSyncs.removeFirst()
            runningMonthSyncWorkers += 1
            Task { [weak self] in
                guard let self else { return }
                await self.store.ensureMonthSynced(month, context: self.modelContext)
                self.finishMonthSync(month)
            }
        }
    }

    /// Completes one month's drain: releases its worker slot, clears its dedup
    /// membership, decrements its owning year's remaining count (dismissing that
    /// year's spinner when it hits zero), then re-pumps to admit the next queued
    /// month.
    private func finishMonthSync(_ month: Date) {
        runningMonthSyncWorkers -= 1
        queuedMonths.remove(month)

        let year = CalendarMath.startOfYear(month)
        if var waiting = pendingMonthsByYear[year] {
            waiting.remove(month)
            if waiting.isEmpty {
                pendingMonthsByYear[year] = nil
                syncingYears.remove(year)
                endLoading(for: year)
            } else {
                pendingMonthsByYear[year] = waiting
            }
        }
        pumpMonthSyncs()
    }

    // MARK: - Loading overlay

    /// Marks `year` as the year the loading spinner gates on and shows it. Only the
    /// most recently-surfaced (visible) year owns the spinner, so scrolling through
    /// several years shows a single spinner tracking the latest, not a stack. The
    /// overlay's own show-delay means an already-cached (instant) year never flashes.
    private func beginLoading(for year: Date) {
        loadingYear = year
        loadingOverlay.setVisible(true, animated: true)
    }

    /// Hides the spinner when the year it was gating on finishes. A completion for a
    /// year that no longer owns the spinner (a superseded earlier year, or an
    /// offscreen growth/prefetch sync that never surfaced) is ignored, so it can't
    /// hide a spinner still owed to the visible year.
    private func endLoading(for year: Date) {
        guard loadingYear == year else { return }
        loadingYear = nil
        loadingOverlay.setVisible(false, animated: true)
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
        // A settled user scroll that lands on a different year means the overview
        // has moved — arm the progressive Today button's "scroll back" behavior.
        if centered != centeredYear {
            hasScrolled = true
        }
        centeredYear = centered
        jumpToToday.setVisible(true, animated: true)
        // Ensure the now-centered year's heatmap fills in (coalesced: a no-op if it
        // is already syncing/synced), surfacing the spinner while it does.
        syncYear(centered, surfaceLoading: true)

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
        // Refresh the heatmap counts for the widened window so already-cached
        // newly-prepended years paint immediately (a fresh sync also re-drives this
        // via `revision` once it lands).
        reload()
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
        // Refresh the heatmap counts for the widened window so already-cached
        // newly-appended years paint immediately.
        reload()
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

    /// Whether the given start-of-year anchor is the current calendar year — drives
    /// the olive emphasis on the year heading and underline (per CUE — Clean design).
    private func isCurrentYear(_ year: Date) -> Bool {
        year == CalendarMath.startOfYear(.now)
    }

    // MARK: - Jump-to-Today

    /// Progressive "Today", identical in spirit to the Month/Day scopes: if the
    /// user has scrolled the overview away (or the current year simply isn't
    /// centered), a tap scrolls the current year back into view and resets the
    /// scrolled flag; if the overview hasn't been scrolled since it opened (and the
    /// current year is centered), a tap zooms one level into today's month via
    /// `scopeDidRequestToday`.
    private func handleJumpToToday() {
        let currentYear = CalendarMath.startOfYear(.now)
        if hasScrolled || centeredYear != currentYear {
            scrollToCurrentYear()
        } else {
            scopeDelegate?.scopeDidRequestToday(self)
        }
    }

    /// Brings the current year back into the window (extending it if the user has
    /// scrolled far away), centers on it, and clears `hasScrolled` so the NEXT tap
    /// (with the current year now centered and unscrolled) zooms in instead.
    private func scrollToCurrentYear() {
        let currentYear = CalendarMath.startOfYear(.now)
        if !window.contains(currentYear) {
            window.seed(around: currentYear, radius: Self.yearSeedRadius)
            applySnapshot(animated: false)
            reload()
        }
        centeredYear = currentYear
        hasScrolled = false
        requestCenter(on: currentYear, animated: true)
        syncYear(currentYear, surfaceLoading: true)
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
        loadingOverlay.apply(theme: theme)
        for case let cell as YearMiniMonthCell in collectionView.visibleCells {
            cell.apply(theme: theme)
        }
        for indexPath in collectionView.indexPathsForVisibleSupplementaryElements(ofKind: YearLayout.yearTitleKind) {
            let view = collectionView.supplementaryView(forElementKind: YearLayout.yearTitleKind, at: indexPath)
            if let title = view as? YearTitleHeaderView, let year = year(forSection: indexPath.section) {
                title.configure(title: heading(for: year), isCurrentYear: isCurrentYear(year), theme: theme)
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
            window.seed(around: year, radius: Self.yearSeedRadius)
            applySnapshot(animated: false)
            reload()
        }
        centeredYear = year
        // A cross-scope zoom-out lands the scope freshly on `year`; it hasn't been
        // scrolled, so the next Today tap should zoom in (when it's the current year).
        hasScrolled = false
        requestCenter(on: year, animated: animated)
        syncYear(year, surfaceLoading: true)
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

    /// A fresh drag starts: drop stale velocity/direction history and mark the
    /// overview as scrolled so the progressive Today button switches to its
    /// "scroll back to the current year" behavior (a settle onto a different year
    /// also arms this, but a drag that returns to the same year should count too).
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }
        hasScrolled = true
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
