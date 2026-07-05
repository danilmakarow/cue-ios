//
//  MonthScopeViewController.swift
//  cue
//

import SwiftData
import UIKit

/// The **month scope** of the UIKit calendar — the middle zoom level. An
/// infinitely-vertical-scrolling collection view with one section per month: a
/// month-title header above a 7-column day grid, under a single weekday-symbol
/// legend pinned to the top. Tapping a day zooms into the day scope anchored on
/// that cell; a floating Jump-to-Today pill recenters or zooms one level in.
///
/// This is the UIKit replacement for the SwiftUI `MonthScopeView` + `MonthPage` +
/// `MonthGrid` + `MonthDayCell`; it preserves every behavior — infinite vertical
/// month scroll, the pinned weekday header, per-day event titles/indicators,
/// tap-to-zoom, progressive Jump-to-Today, jump-free prepend, locale-driven week
/// start and formatting, theming, and Dynamic Type.
///
/// ## The recurrence bug fix (this scope owns it)
/// The old `MonthScopeView.syncAround` synced only the centered month ±1, so a
/// fling that travelled several months left the gap-months unsynced → their
/// windowed query was empty → recurring occurrences vanished. **The fix:** every
/// month section syncs *itself* as it becomes visible or is prefetched — driven
/// from both `collectionView(_:willDisplay:)` and the prefetch data source. Each
/// call is `store.ensureMonthSynced(monthAnchor:context:)`, which early-returns on
/// its durable `WindowSyncMeta` memo while the window is fresh (TTL-gated), so
/// calling it for every visible/prefetched month is cheap and **guarantees
/// coverage at any scroll speed**. There is no
/// centered-±1 heuristic here. After a section's sync completes, the store bumps
/// `revision`; the adapter's `observeRevision` re-runs the windowed fetch and
/// re-applies the snapshot, so the freshly-synced month's days populate.
///
/// ## Construction (for the Integration engineer)
/// The container builds it with the four shared dependencies and an initial theme:
/// ```swift
/// let month = MonthScopeViewController(
///     store: store,
///     adapter: adapter,
///     modelContext: modelContext,
///     theme: theme
/// )
/// month.scopeDelegate = container
/// ```
/// No further wiring is needed: it observes `store.revision` itself (via the
/// adapter), syncs visible/prefetched months itself, and reports unit selection /
/// Today through `scopeDelegate`. Push the theme on change via ``apply(theme:)``.
/// A diffable item in the month grid: either a leading blank (aligning day 1
/// under its weekday) or a real day. Blanks carry their month + index so they
/// stay unique across sections; days key by `startOfDay` (the canonical day key).
///
/// Declared at file scope (not nested in the `@MainActor` view controller) so its
/// `Hashable`/`Sendable` conformance is non-isolated — a `MainActor`-isolated
/// conformance can't satisfy `UICollectionViewDiffableDataSource`'s `Sendable`
/// `ItemIdentifierType` requirement under Swift 6.
nonisolated private enum MonthGridItem: Hashable, Sendable {
    case blank(month: Date, index: Int)
    case day(Date)
}

@MainActor
final class MonthScopeViewController: UIViewController, CalendarScopeViewController {

    // MARK: - Section / item identity

    private typealias Item = MonthGridItem

    // MARK: - CalendarScopeViewController

    let kind: CalendarScopeKind = .month
    weak var scopeDelegate: CalendarScopeDelegate?

    // MARK: - Dependencies

    private let store: CalendarStore
    private let adapter: CalendarDataAdapter
    private let modelContext: ModelContext
    private var theme: CalendarTheme

    /// Shared direction/velocity prefetch planner — computes an ahead-of-visibility
    /// month buffer routed through the same `syncMonth` path as `willDisplay`.
    private let prefetchCoordinator: PrefetchCoordinator

    // MARK: - Infinite-scroll window

    /// The sliding window of month-start anchors (one per section). Seeded around
    /// the centered month; grown/trimmed on scroll-settle only.
    private var window = InfiniteSectionWindow(step: .month)

    /// Per-day event chips (title + resolved GROUP color) for every windowed month,
    /// keyed by `startOfDay`. Drives both the day grid's title chips and its
    /// event-indicator dots, colored by group. Refreshed on every `revision` change
    /// (and incrementally as months sync).
    private var chipsByDay: [Date: [MonthDayChip]] = [:]

    /// The month the scope considers "centered" — drives Jump-to-Today and the
    /// edge-growth decision. Updated on scroll-settle.
    private var centeredMonth: Date

    /// Guards programmatic scrolls from being treated as user settles.
    private var isProgrammaticallyScrolling = false

    /// The month grid's content density (design-spec §4). Defaults to the bundle
    /// default (Stacked: color-tinted backgrounds, up to 3 tasks, "+N more") and is
    /// switched live by the self-contained ``densityControl`` (Compact / Stacked /
    /// Details) via ``handleDensityChange`` — no shared-file wiring needed.
    private var density: MonthDensity = .stacked

    /// The three densities in the segmented control's display order. Index parity
    /// with ``densityControl`` segments — the map from a selected index back to a
    /// `MonthDensity` and vice-versa.
    private static let densityOrder: [MonthDensity] = [.compact, .stacked, .details]

    /// Whether the user has scrolled the grid since it appeared (or since the last
    /// Today recenter). Drives the progressive Today button: a scrolled grid
    /// recenters on tap; an un-scrolled grid zooms one level into today. Reset to
    /// `false` after a recenter so a subsequent tap zooms.
    private var hasScrolled = false

    /// Coalesces `store.revision`-driven reloads: the store can bump `revision`
    /// several times in quick succession (e.g. as multiple months finish syncing
    /// during a fling), and each reload re-fetches + reconfigures. Debouncing to a
    /// single trailing reload per burst keeps the fetch off the hot scroll path,
    /// fixing the main-thread stall this scope owned.
    private var reloadWorkItem: DispatchWorkItem?

    /// The debounce interval for revision-driven reloads — long enough to swallow a
    /// burst of sync completions, short enough to feel immediate.
    private static let reloadDebounce: TimeInterval = 0.12

    /// A small buffer of months rebuilt on each side of the visible range so a
    /// nudge-scroll into an adjacent month already has its chips, without paying to
    /// re-fetch the whole (±6-month) window on every revision.
    private static let chipFetchBufferMonths = 1

    /// A center request that arrived before the collection view had a non-zero
    /// size (e.g. the zoom controller centering a freshly-mounted scope on the
    /// same runloop it's added). `scrollToItem` silently no-ops on a zero-sized
    /// collection view, so we stash the target and re-apply it once
    /// `viewDidLayoutSubviews` reports real bounds — otherwise the scope lands on
    /// the oldest seeded month instead of today/the focused month.
    private var pendingCenter: (month: Date, animated: Bool)?

    // MARK: - Views

    private let jumpToToday = DayJumpToTodayButton()

    /// The self-contained density switcher (design-spec §4: a right-aligned control
    /// above the pinned weekday legend). A plain `UISegmentedControl` living in this
    /// scope's own view — Compact / Stacked / Details — so all three densities are
    /// reachable without touching any shared file. Its selection drives
    /// ``handleDensityChange``.
    private lazy var densityControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [
            String(
                localized: "calendar.month.density.compact",
                defaultValue: "Compact",
                comment: "Month grid density: colored dots only"
            ),
            String(
                localized: "calendar.month.density.stacked",
                defaultValue: "Stacked",
                comment: "Month grid density: up to 3 tinted task chips"
            ),
            String(
                localized: "calendar.month.density.details",
                defaultValue: "Details",
                comment: "Month grid density: up to 2 timed task chips"
            ),
        ])
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = Self.densityOrder.firstIndex(of: density) ?? 1
        control.addTarget(self, action: #selector(handleDensityChange), for: .valueChanged)
        return control
    }()

    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: MonthLayout.make())
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.showsVerticalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .never
        view.delegate = self
        view.isPrefetchingEnabled = true
        view.prefetchDataSource = self
        view.register(
            MonthDayGridCell.self,
            forCellWithReuseIdentifier: MonthDayGridCell.reuseIdentifier
        )
        view.register(
            MonthTitleHeaderView.self,
            forSupplementaryViewOfKind: MonthLayout.monthTitleKind,
            withReuseIdentifier: MonthTitleHeaderView.reuseIdentifier
        )
        view.register(
            MonthWeekdayHeaderView.self,
            forSupplementaryViewOfKind: MonthLayout.weekdayHeaderKind,
            withReuseIdentifier: MonthWeekdayHeaderView.reuseIdentifier
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
    ///     its `revision` and rebuilds `chipsByDay` on change.
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
        self.centeredMonth = CalendarMath.startOfMonth(store.selectedDate)
        super.init(nibName: nil, bundle: nil)
        window.seed(around: centeredMonth)
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

        // One-time reactive registration: rebuild titles + reconfigure on change.
        // Debounced so a burst of sync-completion revision bumps collapses into a
        // single trailing reload instead of stalling the main thread mid-scroll.
        adapter.observeRevision { [weak self] in self?.scheduleReload() }

        applySnapshot(animated: false)
        reload()
        // Defer the initial center until the collection view has real bounds —
        // `viewDidLoad` runs before layout, so an immediate scroll would no-op.
        requestCenter(on: centeredMonth, animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Drain a center request that was queued before the collection view had a
        // non-zero size, now that layout has given it real bounds.
        guard let pending = pendingCenter, collectionView.bounds.width > 0 else { return }
        pendingCenter = nil
        scrollToMonth(pending.month, animated: pending.animated)
    }

    // MARK: - Setup

    private func setUpViews() {
        view.backgroundColor = theme.background

        jumpToToday.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        view.addSubview(densityControl)
        view.addSubview(jumpToToday)

        NSLayoutConstraint.activate([
            // Density switcher: a right-aligned row above the pinned weekday legend
            // (design-spec §4). Lives in this scope's own safe area, so the grid
            // starts just below it.
            densityControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Spacing.xs),
            densityControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -MonthLayout.horizontalInset),

            collectionView.topAnchor.constraint(equalTo: densityControl.bottomAnchor, constant: Spacing.xs),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            jumpToToday.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Spacing.xl),
            jumpToToday.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Spacing.xxl),
        ])
    }

    /// Switches the grid's content density from the segmented control, then repaints
    /// every day cell against the new density. Fully self-contained: no shared-file
    /// wiring — the selection maps through ``densityOrder`` to a `MonthDensity`, is
    /// stored, and the visible cells are reconfigured in place (the debounced
    /// revision path is untouched, so this is an instant, local repaint).
    @objc private func handleDensityChange() {
        let index = densityControl.selectedSegmentIndex
        guard Self.densityOrder.indices.contains(index) else { return }
        let next = Self.densityOrder[index]
        guard next != density else { return }
        density = next
        reconfigureVisible()
    }

    private func wireJumpToToday() {
        jumpToToday.action = { [weak self] in self?.handleJumpToToday() }
        // The month overview keeps the pill always visible with a progressive
        // action (recenter when off the current month, else zoom one level in).
        jumpToToday.setVisible(true, animated: false)
    }

    // MARK: - Data source

    /// Builds the diffable data source: each item is a blank or a day cell; the
    /// two supplementary kinds are the per-section title and the pinned legend.
    private func makeDataSource() -> UICollectionViewDiffableDataSource<Date, Item> {
        let source = UICollectionViewDiffableDataSource<Date, Item>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: MonthDayGridCell.reuseIdentifier, for: indexPath
            )
            guard let self, let dayCell = cell as? MonthDayGridCell else { return cell }
            self.configure(dayCell, with: item)
            return dayCell
        }

        source.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            self?.supplementaryView(in: collectionView, kind: kind, at: indexPath)
        }
        return source
    }

    /// Configures a day cell (or renders a blank as an empty cell).
    private func configure(_ cell: MonthDayGridCell, with item: Item) {
        switch item {
        case .blank:
            cell.configure(
                number: "", isToday: false, isSelected: false,
                chips: [], density: density, theme: theme
            )
            cell.isUserInteractionEnabled = false
            cell.isAccessibilityElement = false
        case let .day(date):
            let key = CalendarMath.startOfDay(date)
            cell.configure(
                number: MonthGridModel.model(for: date).days.first { $0.date == key }?.number
                    ?? date.formatted(.dateTime.day()),
                isToday: CalendarMath.isToday(date),
                isSelected: key == CalendarMath.startOfDay(store.selectedDate),
                chips: chipsByDay[key] ?? [],
                density: density,
                theme: theme
            )
            cell.isUserInteractionEnabled = true
        }
    }

    /// Builds a supplementary view for the given kind.
    private func supplementaryView(
        in collectionView: UICollectionView,
        kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView? {
        switch kind {
        case MonthLayout.monthTitleKind:
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: MonthTitleHeaderView.reuseIdentifier,
                for: indexPath
            )
            guard let titleHeader = header as? MonthTitleHeaderView,
                  let month = month(forSection: indexPath.section) else { return header }
            titleHeader.configure(title: heading(for: month), isCurrent: isCurrentMonth(month), theme: theme)
            return titleHeader

        case MonthLayout.weekdayHeaderKind:
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: MonthWeekdayHeaderView.reuseIdentifier,
                for: indexPath
            )
            (header as? MonthWeekdayHeaderView)?.configure(theme: theme)
            return header

        default:
            return nil
        }
    }

    /// Applies a snapshot built from the current window. Wrapped in
    /// `performWithoutAnimation` so prepend growth never animates a content shift.
    private func applySnapshot(animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Date, Item>()
        for month in window.anchors {
            snapshot.appendSections([month])
            snapshot.appendItems(items(for: month), toSection: month)
        }
        if animated {
            dataSource.apply(snapshot, animatingDifferences: true)
        } else {
            UIView.performWithoutAnimation {
                dataSource.apply(snapshot, animatingDifferences: false)
            }
        }
    }

    /// The grid items for a month: leading blanks then each day, padded to a full
    /// six-row (42-cell) grid so every section is the same height.
    private func items(for month: Date) -> [Item] {
        let blanks = CalendarMath.leadingBlankCount(forMonth: month)
        let days = CalendarMath.daysInMonth(month)
        var result: [Item] = (0..<blanks).map { Item.blank(month: month, index: $0) }
        result.append(contentsOf: days.map { Item.day($0) })
        // Pad to a fixed 6-row grid (7 * 6 = 42) so the section height is constant.
        let total = MonthLayout.weekRowCount * 7
        if result.count < total {
            let trailingStart = blanks + days.count
            result.append(contentsOf: (trailingStart..<total).map { Item.blank(month: month, index: $0) })
        }
        return result
    }

    // MARK: - Data

    /// Schedules a debounced reload on the main queue, cancelling any pending one.
    /// The store bumps `revision` once per month-sync completion; a fling that
    /// syncs several months would otherwise fire several full re-fetches back to
    /// back. Coalescing to a single trailing reload keeps that work off the hot
    /// scroll path — the fix for the month freeze.
    private func scheduleReload() {
        reloadWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.reload() }
        reloadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reloadDebounce, execute: workItem)
    }

    /// Re-runs the windowed fetch across the visible range, rebuilds the per-day
    /// chip map, and reconfigures the visible cells. Bound (debounced) to
    /// `store.revision` via the adapter and called after a section sync / growth.
    private func reload() {
        rebuildTitles()
        reconfigureVisible()
    }

    /// Rebuilds `chipsByDay` from a fetch spanning only the currently-visible
    /// months (± a one-month buffer), not the whole ±6-month window. Merges the
    /// fresh range into the existing map so months scrolled off-screen keep their
    /// already-built chips until evicted — this narrows the per-revision fetch from
    /// ~180+ days to ~90, the other half of the freeze fix.
    private func rebuildTitles() {
        guard let range = chipFetchRange() else { return }
        let byDay = adapter.occurrencesByDay(from: range.from, to: range.to)
        var chips = chipsByDay
        // Clear the fetched range first so days that lost all occurrences don't
        // retain stale chips, then repopulate from the fresh result.
        chips = chips.filter { $0.key < range.from || $0.key >= range.to }
        for (day, occurrences) in byDay {
            chips[day] = occurrences.map { occurrence in
                MonthDayChip(
                    title: occurrence.title,
                    time: timeLabel(for: occurrence),
                    isRecurring: occurrence.isRecurring,
                    color: CalendarColor.effective(
                        taskToken: occurrence.colorToken,
                        groupToken: occurrence.groupColorToken
                    )
                )
            }
        }
        chipsByDay = chips
    }

    /// The `[from, to)` fetch range covering the visible months plus a one-month
    /// buffer on each side. Falls back to the centered month (± buffer) before the
    /// collection view has realized any cells (e.g. the very first reload).
    private func chipFetchRange() -> (from: Date, to: Date)? {
        let buffer = Self.chipFetchBufferMonths
        let visibleSections = Set(collectionView.indexPathsForVisibleItems.map { $0.section })
        let months: [Date]
        if visibleSections.isEmpty {
            months = [centeredMonth]
        } else {
            months = visibleSections.compactMap { month(forSection: $0) }
        }
        guard let earliest = months.min(), let latest = months.max() else { return nil }
        let fromMonth = monthOffset(-buffer, from: earliest)
        let toMonth = monthOffset(buffer, from: latest)
        let (from, _) = CalendarMath.monthBounds(fromMonth)
        let (_, to) = CalendarMath.monthBounds(toMonth)
        return (from, to)
    }

    /// The month anchor `offset` months from `month` (negative = earlier). A local
    /// helper so this scope needn't touch the shared `CalendarMath`; falls back to
    /// `month` if the calendar can't advance (never expected).
    private func monthOffset(_ offset: Int, from month: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: offset, to: month) ?? month
    }

    /// A month day-chip's mono time label: the localized all-day label for all-day
    /// occurrences, else a fixed `HH:mm` (24-hour) start — only surfaced by the
    /// Details density, but computed once here so the chip stays render-only.
    private func timeLabel(for occurrence: OccurrenceVM) -> String {
        if occurrence.isAllDay { return String(localized: "newEvent.allDay") }
        return Self.chipTimeFormatter.string(from: occurrence.startAt)
    }

    /// Fixed 24-hour `HH:mm` formatter for Details-density chip time lines (design:
    /// mono `HH:MM`). Uses a POSIX locale so the pattern stays 24-hour regardless of
    /// the device's 12/24-hour setting, matching the design's mono time.
    private static let chipTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// Reconfigures the currently-visible items in place (no reload flash), so a
    /// data change repaints titles/highlights without rebuilding the snapshot.
    private func reconfigureVisible() {
        var snapshot = dataSource.snapshot()
        let visibleItems = collectionView.indexPathsForVisibleItems.compactMap {
            dataSource.itemIdentifier(for: $0)
        }
        guard !visibleItems.isEmpty else { return }
        snapshot.reconfigureItems(visibleItems)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Per-section sync (THE BUG FIX)

    /// Syncs a single month's occurrences. Idempotent and cheap — the store
    /// early-returns on its durable `WindowSyncMeta` memo while fresh (TTL-gated) —
    /// so it is safe to call for every
    /// visible and prefetched month. Driven from `willDisplay` and `prefetchItemsAt`
    /// so coverage is independent of scroll speed (no centered-±1 heuristic). When
    /// the sync completes the store bumps `revision`, re-driving `reload()`.
    private func syncMonth(_ month: Date) {
        Task { await store.ensureMonthSynced(CalendarMath.startOfMonth(month), context: modelContext) }
    }

    // MARK: - Prefetch (ahead-of-visibility buffer)

    /// Computes the coordinator's direction/velocity-aware month buffer for the
    /// current leading visible month and dispatches `syncMonth` for each member.
    /// Routed through the SAME idempotent `syncMonth` path as `willDisplay`/prefetch,
    /// so it only *optimizes* the timing — it never replaces the correctness floor.
    private func dispatchMonthPrefetchBuffer() {
        guard let leading = leadingVisibleMonth() else { return }
        let months = prefetchCoordinator.computePrefetchMonths(
            leadingMonth: leading,
            windowAnchors: window.anchors
        )
        for month in months { syncMonth(month) }
    }

    /// The month anchor at the leading edge of the viewport in the current scroll
    /// direction — the section the scroll is moving toward. Falls back to the
    /// centered month when no edge item resolves.
    private func leadingVisibleMonth() -> Date? {
        let visibleSections = Set(collectionView.indexPathsForVisibleItems.map { $0.section })
        guard !visibleSections.isEmpty else { return centeredMonth }
        // Forward (down) → highest visible section; backward (up) → lowest.
        let section = prefetchCoordinator.direction.isBackward()
            ? visibleSections.min()
            : visibleSections.max()
        guard let section else { return centeredMonth }
        return month(forSection: section)
    }

    // MARK: - Window growth (scroll-settle only)

    /// On settle, recompute the centered month, grow the window if the centered
    /// section nears an edge, and correct `contentOffset` on prepend so the
    /// viewport doesn't jump. Never called mid-fling, so a fast flick can't run the
    /// window away.
    private func handleScrollSettled() {
        guard let centered = centeredMonthFromViewport() else { return }
        centeredMonth = centered
        jumpToToday.setVisible(true, animated: true)

        guard let index = window.index(of: centered) else {
            // Not held (shouldn't happen post-settle) — still rebuild for the new
            // viewport so already-synced months that scrolled in show their chips.
            reload()
            return
        }

        if window.isNearLeadingEdge(of: index) {
            growLeading()
        } else if window.isNearTrailingEdge(of: index) {
            growTrailing()
        } else {
            // No window growth needed, but the visible range moved — rebuild chips
            // for the newly-revealed months. `ensureMonthSynced` early-returns for
            // fresh months (no revision bump), so this settle-time reload is the
            // only thing that populates chips when scrolling within synced data.
            reload()
        }
    }

    /// Prepends older months and corrects `contentOffset` by the prepended height
    /// so the viewport stays visually fixed. Measures after the diffable apply
    /// commits (synchronously, inside `performWithoutAnimation`).
    private func growLeading() {
        let added = window.prepend()
        guard !added.isEmpty else { return }
        let trimmed = window.trimTrailing()
        evictWindowsAndRows(anchors: trimmed)

        // Correct the offset by the height of the newly-prepended sections so the
        // content under the user's eye doesn't jump. Every section is a fixed
        // height (`MonthLayout.sectionHeight`), so the shift is exact.
        let shift = CGFloat(added.count) * MonthLayout.sectionHeight
        let priorOffset = collectionView.contentOffset
        applySnapshot(animated: false)
        // Apply the correction synchronously after the snapshot commits its new
        // content size, before the next frame paints.
        collectionView.setContentOffset(
            CGPoint(x: priorOffset.x, y: priorOffset.y + shift),
            animated: false
        )
        // Sync the newly-revealed older months (each is idempotent).
        for month in added { syncMonth(month) }
        reload()
    }

    /// Appends newer months and trims the far (oldest) edge. No offset correction
    /// needed — growth below the viewport doesn't move what's on screen.
    private func growTrailing() {
        let added = window.append()
        guard !added.isEmpty else { return }
        let trimmed = window.trimLeading()
        evictWindowsAndRows(anchors: trimmed)
        applySnapshot(animated: false)
        for month in added { syncMonth(month) }
        reload()
    }

    // MARK: - Eviction

    /// Atomically evicts the durable `WindowSyncMeta` memo *and* the persisted
    /// `TaskItem` rows for each trimmed month, so the on-device cache stays bounded
    /// alongside the in-memory section window. Deleting the meta and its rows in one
    /// `context.save()` keeps them from drifting: a re-scroll into an evicted month
    /// finds no meta (reads stale) and re-fetches, rather than trusting orphaned
    /// rows or a memo that vouches for absent data.
    private func evictWindowsAndRows(anchors: [Date]) {
        guard !anchors.isEmpty else { return }
        store.evictMonthWindows(anchors, context: modelContext)
    }

    // MARK: - Centered-month resolution

    /// The month whose section contains the vertical center of the viewport.
    private func centeredMonthFromViewport() -> Date? {
        let midPoint = CGPoint(
            x: collectionView.bounds.midX,
            y: collectionView.contentOffset.y + collectionView.bounds.midY
        )
        guard let indexPath = collectionView.indexPathForItem(at: midPoint)
            ?? nearestIndexPath(to: midPoint) else { return centeredMonth }
        return month(forSection: indexPath.section)
    }

    /// Falls back to the closest visible item when the midpoint lands in a gap
    /// (e.g. over the header strip), so `centeredMonth` always resolves.
    private func nearestIndexPath(to point: CGPoint) -> IndexPath? {
        collectionView.indexPathsForVisibleItems
            .min { lhs, rhs in
                let lhsY = collectionView.layoutAttributesForItem(at: lhs)?.center.y ?? .greatestFiniteMagnitude
                let rhsY = collectionView.layoutAttributesForItem(at: rhs)?.center.y ?? .greatestFiniteMagnitude
                return abs(lhsY - point.y) < abs(rhsY - point.y)
            }
    }

    // MARK: - Section ↔ month mapping

    /// The month anchor backing `section`, or nil when out of range.
    private func month(forSection section: Int) -> Date? {
        guard window.anchors.indices.contains(section) else { return nil }
        return window.anchors[section]
    }

    // MARK: - Headings

    /// "May" within the current year; "May 2027" elsewhere — matching `MonthPage`.
    private func heading(for month: Date) -> String {
        let model = MonthGridModel.model(for: month)
        let currentYear = Calendar.current.component(.year, from: .now)
        return model.year == currentYear ? model.nameWide : model.nameWideWithYear
    }

    /// Whether `month`'s section is the calendar's *current* month — drives the
    /// olive present-moment header treatment (impl-plan B2). Compared on the month
    /// start-anchor so any day within the month resolves the same section.
    private func isCurrentMonth(_ month: Date) -> Bool {
        CalendarMath.startOfMonth(month) == CalendarMath.startOfMonth(.now)
    }

    // MARK: - Selection / Jump-to-Today

    /// Progressive "Today", gated on whether the user has scrolled since the grid
    /// appeared (or since the last recenter):
    /// - **Scrolled** (now or earlier this session): scroll today's month back into
    ///   view and reset `hasScrolled`, so the very next tap zooms.
    /// - **Not scrolled**: ask the container to zoom one level into today's per-day
    ///   view via `scopeDidRequestToday`.
    private func handleJumpToToday() {
        if hasScrolled {
            scrollToCurrentMonth()
            hasScrolled = false
        } else {
            scopeDelegate?.scopeDidRequestToday(self)
        }
    }

    /// Brings the current month back into the window (extending it if the user has
    /// scrolled far away) and centers on it.
    private func scrollToCurrentMonth() {
        let currentMonth = CalendarMath.startOfMonth(.now)
        if !window.contains(currentMonth) {
            window.seed(around: currentMonth)
            applySnapshot(animated: false)
            reload()
        }
        centeredMonth = currentMonth
        requestCenter(on: currentMonth, animated: true)
        syncMonth(currentMonth)
    }

    /// Centers on `month` if the collection view already has real bounds; else
    /// queues the request for the next `viewDidLayoutSubviews`. The single funnel
    /// that makes centering robust to layout timing — both the initial center and
    /// a cross-scope zoom land correctly whether or not the view has laid out yet.
    private func requestCenter(on month: Date, animated: Bool) {
        guard collectionView.bounds.width > 0 else {
            pendingCenter = (month, animated)
            return
        }
        scrollToMonth(month, animated: animated)
    }

    /// Centers the scope on `month`'s section without animating a layout shift
    /// when not requested.
    private func scrollToMonth(_ month: Date, animated: Bool) {
        guard let section = window.index(of: CalendarMath.startOfMonth(month)),
              collectionView.numberOfSections > section,
              collectionView.numberOfItems(inSection: section) > 0 else { return }
        isProgrammaticallyScrolling = true
        let target = IndexPath(item: 0, section: section)
        collectionView.scrollToItem(at: target, at: .top, animated: animated)
        DispatchQueue.main.async { [weak self] in self?.isProgrammaticallyScrolling = false }
    }

    // MARK: - CalendarScopeViewController conformance

    /// Re-styles the whole scope (background, pill, visible cells + supplementaries).
    func apply(theme: CalendarTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        applyTheme()
    }

    private func applyTheme() {
        view.backgroundColor = theme.background
        jumpToToday.apply(theme: theme)
        applyDensityControlTheme()
        for case let cell as MonthDayGridCell in collectionView.visibleCells {
            cell.apply(theme: theme)
        }
        // Re-style the supplementaries (title + pinned legend) in place.
        for kind in [MonthLayout.monthTitleKind, MonthLayout.weekdayHeaderKind] {
            for indexPath in collectionView.indexPathsForVisibleSupplementaryElements(ofKind: kind) {
                let view = collectionView.supplementaryView(forElementKind: kind, at: indexPath)
                if let title = view as? MonthTitleHeaderView, let month = month(forSection: indexPath.section) {
                    title.configure(title: heading(for: month), isCurrent: isCurrentMonth(month), theme: theme)
                } else if let legend = view as? MonthWeekdayHeaderView {
                    legend.configure(theme: theme)
                }
            }
        }
    }

    /// Tints the density switcher to the active theme: a sunken track, the surface
    /// as the selected-segment fill, and the label ink split primary/secondary so
    /// it reads as a quiet chrome control rather than an accent (design-spec §4:
    /// `--fill` track, `body sans 13/500`).
    private func applyDensityControlTheme() {
        densityControl.backgroundColor = theme.surfaceSunken
        densityControl.selectedSegmentTintColor = theme.surface
        densityControl.setTitleTextAttributes(
            [.foregroundColor: theme.textSecondary, .font: theme.label], for: .normal
        )
        densityControl.setTitleTextAttributes(
            [.foregroundColor: theme.textPrimary, .font: theme.label], for: .selected
        )
    }

    /// Enables/disables the scope's scrolling for the duration of a zoom transition
    /// so the pinch/pan don't fight.
    func setScrollEnabled(_ isEnabled: Bool) {
        collectionView.isScrollEnabled = isEnabled
    }

    /// Centers the scope on `unit`'s month. Used after a cross-scope zoom or a
    /// Today jump. Extends the window first if the month isn't currently held.
    func center(on unit: Date, animated: Bool) {
        let month = CalendarMath.startOfMonth(unit)
        if !window.contains(month) {
            window.seed(around: month)
            applySnapshot(animated: false)
            reload()
        }
        centeredMonth = month
        requestCenter(on: month, animated: animated)
        syncMonth(month)
    }

    /// The frame of `unit`'s day cell, converted into `coordinateSpace`, or nil
    /// when that cell isn't currently realized. The zoom controller anchors the
    /// month → day cross-scale on this rect.
    func anchorFrame(forUnit unit: Date, in coordinateSpace: UICoordinateSpace) -> CGRect? {
        let day = CalendarMath.startOfDay(unit)
        guard let indexPath = dataSource.indexPath(for: .day(day)),
              let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
            return nil
        }
        return collectionView.convert(attributes.frame, to: coordinateSpace)
    }

    /// The day whose cell contains `point` (expressed in `coordinateSpace`), or nil
    /// when no day cell is hit — used to pick the anchor cell under a pinch's start.
    func unit(at point: CGPoint, in coordinateSpace: UICoordinateSpace) -> Date? {
        let localPoint = coordinateSpace.convert(point, to: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: localPoint),
              let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        if case let .day(date) = item { return CalendarMath.startOfDay(date) }
        return nil
    }
}

// MARK: - Collection view delegate

extension MonthScopeViewController: UICollectionViewDelegate {

    /// Tapping a day asks the container to zoom into the day scope anchored on that
    /// cell. Blanks are non-interactive, so only real days reach here.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath),
              case let .day(date) = item,
              let attributes = collectionView.layoutAttributesForItem(at: indexPath) else { return }
        let day = CalendarMath.startOfDay(date)
        store.selectedDate = day
        // Report the tapped cell's frame in the container's coordinate space so the
        // zoom controller can anchor the zoom-in on it.
        let container = scopeDelegate as? UIViewController
        let space: UICoordinateSpace = container?.view ?? view
        let frame = collectionView.convert(attributes.frame, to: space)
        scopeDelegate?.scope(self, didSelectUnit: day, cellFrame: frame)
    }

    /// Per-section self-sync as a month becomes visible — half of the bug fix. The
    /// section's month syncs itself; `ensureMonthSynced` early-returns on cache.
    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let month = month(forSection: indexPath.section) else { return }
        syncMonth(month)
    }

    // MARK: Scroll tracking (prefetch)

    /// Feeds the coordinator each offset sample so it can derive direction +
    /// velocity and (debounced) dispatch the ahead-of-visibility month buffer.
    /// Skips programmatic scrolls so a centering animation doesn't pollute the
    /// estimate.
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === collectionView, !isProgrammaticallyScrolling else { return }
        prefetchCoordinator.track(offset: scrollView.contentOffset, axis: .vertical) { [weak self] in
            self?.dispatchMonthPrefetchBuffer()
        }
    }

    /// A fresh user drag starts: drop stale velocity/direction history and record
    /// that the user has scrolled — flipping the Today button from zoom-in to
    /// recenter (see ``handleJumpToToday``). This fires only for genuine finger
    /// drags, so a programmatic centering (which never begins dragging) can't trip
    /// the flag.
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
        prefetchCoordinator.settleNow { [weak self] in self?.dispatchMonthPrefetchBuffer() }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView === collectionView, !decelerate else { return }
        handleScrollSettled()
        prefetchCoordinator.settleNow { [weak self] in self?.dispatchMonthPrefetchBuffer() }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }
        isProgrammaticallyScrolling = false
    }
}

// MARK: - Prefetching (THE BUG FIX — prefetch path)

extension MonthScopeViewController: UICollectionViewDataSourcePrefetching {

    /// The other half of the bug fix: months sync as soon as their cells are
    /// *prefetched* — ahead of becoming visible — so even a fast fling that
    /// skips `willDisplay` for intermediate months still triggers their sync.
    /// `ensureMonthSynced` early-returns on cache, so the redundant calls are free.
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let months = Set(indexPaths.compactMap { month(forSection: $0.section) })
        for month in months { syncMonth(month) }
    }
}
