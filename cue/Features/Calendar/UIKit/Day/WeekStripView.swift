//
//  WeekStripView.swift
//  cue
//

import SwiftData
import UIKit

/// One locale-week page in the strip. `nonisolated` (the module defaults to
/// `MainActor` isolation, so we opt this value type out) so its `Hashable`
/// conformance is `Sendable` — the diffable data source's section identifier
/// requires a `Sendable` `Hashable`.
private nonisolated struct WeekStripWeekGroup: Hashable, Sendable {
    let startDate: Date
    let dates: [Date]
}

/// A diffable item — one day tile, identified by its `startOfDay`. `nonisolated`
/// for the same `Sendable`-`Hashable` reason as ``WeekStripWeekGroup``.
private nonisolated struct WeekStripDayItem: Hashable, Sendable {
    let date: Date
}

/// Horizontal week strip pinned above the day pager — a **strictly derived**
/// presentation slaved to one source of truth: the day pager's `contentOffset.x`.
///
/// The strip's own `UICollectionView` is a passive backdrop of locale-week pages
/// (a diffable data source of ``WeekDayTileCell``). It never runs its own
/// scroll animation off date-math during a gesture. A single Liquid-Glass
/// "pill" (`UIVisualEffectView` + `UIGlassEffect`, iOS 26) lives above the
/// collection and is positioned every frame by ONE deterministic geometry
/// function of the pager's live fractional position.
///
/// The owner (``DayScopeViewController``) drives the strip from the pager's
/// `scrollViewDidScroll` by calling ``syncToPager(continuousPageIndex:)`` with
/// the raw fractional page index over the pager's `pageDates` space. The strip
/// translates that single value into both a pill frame and a week-page content
/// offset — so the pill and the visible week advance in lockstep and can never
/// desync. Crossing a week boundary slides the strip's own collection by exactly
/// the same continuous fraction, never via a competing animated `scrollToItem`.
///
/// Selection is reported through ``onSelectDate``; programmatic selection (tap,
/// settle, jump-to-today, external) routes through ``commitSelection(date:animated:)``.
@MainActor
final class WeekStripView: UIView {

    /// Fired when the user taps a day tile. The owner sets `store.selectedDate`
    /// and pages the day pager to match.
    var onSelectDate: ((Date) -> Void)?

    // MARK: - Pill treatment toggle

    /// Design-pass toggle: `true` ships the iOS 26 Liquid Glass pill (warm-tinted
    /// toward `theme.primary`); `false` ships a solid `theme.primary` fill. The
    /// pill stays a `UIVisualEffectView` in both modes, so the per-frame geometry
    /// path is identical — flipping this is genuinely one line.
    ///
    /// DESIGN CALL (Kraft & Ink on WHITE): shipped `false`. On the old kraft-tan
    /// canvas an espresso-tinted glass pill nestled into the warm paper; on pure
    /// white the same translucent brown wash reads muddy and *floaty* over the
    /// crisp white tiles — precisely the glassmorphism this identity rejects
    /// ("letterpress, not float"). A solid espresso pill with cream day text is
    /// crisper, higher-contrast, and reads as a deliberate printed mark. The glass
    /// path is kept intact (not deleted) so flipping this back to `true` is one line.
    private static let usesLiquidGlass = false

    // MARK: - Model

    private typealias WeekGroup = WeekStripWeekGroup
    private typealias DayItem = WeekStripDayItem

    private static let daysPerGroup = 7
    /// ±12 weeks (~±84 days) of locale-aligned weeks around today's week.
    private static let groupRange = -12...12

    private let calendar = Calendar.current
    private let store: CalendarStore
    private let groups: [WeekGroup]

    /// `startOfDay(today)` captured once at init — the strip's continuous-day
    /// origin (so `dayOffsetFromToday = continuousPageIndex - todayPageIndex`).
    private let todayStart: Date
    /// The pager's `pageDates` index of today, given once at init — lets the strip
    /// map a continuous pager index into a continuous day offset without ever
    /// holding the pager's `pageDates` array.
    private let todayPageIndex: Int

    /// The committed selected day — drives tile restyle + accessibility only,
    /// never per-frame pill geometry (that is a pure function of the pager).
    private var selectedDate: Date
    private var theme: CalendarTheme?

    /// Per-day task counts keyed by `startOfDay`, drawn as a small badge on each
    /// tile. Empty until ``loadCounts(for:context:)`` populates it.
    private var dailyCounts: [Date: Int] = [:]

    /// CPU-only no-op guard for the per-frame pill write. Recomputed from the
    /// input each call — pure cache, never authoritative state that can drift.
    private var lastPillOriginX: CGFloat?
    private var lastWeekContentOffsetX: CGFloat?

    // MARK: - Spring constants (programmatic selection only)

    private static let pillSpringDuration: TimeInterval = 0.28
    private static let pillSpringDamping: CGFloat = 0.86

    // MARK: - Views

    /// The single moving selection pill — Liquid Glass (or a solid fill via the
    /// toggle). Lives ABOVE the collection, non-interactive.
    private let pill = UIVisualEffectView(effect: nil)

    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.isPagingEnabled = false
        // The strip is purely a slaved backdrop: the user never scrolls it
        // directly. Its horizontal offset is set imperatively from the pager.
        view.isScrollEnabled = false
        view.decelerationRate = .fast
        view.delegate = self
        view.register(WeekDayTileCell.self, forCellWithReuseIdentifier: WeekDayTileCell.reuseIdentifier)
        view.contentInsetAdjustmentBehavior = .never
        return view
    }()

    private lazy var dataSource = makeDataSource()

    // MARK: - Init

    /// - Parameters:
    ///   - store: the calendar store, used to fetch + cache daily counts.
    ///   - selectedDate: the initially-selected day (the store's `selectedDate`
    ///     at construction).
    ///   - todayPageIndex: the pager's `pageDates` index of today — the strip's
    ///     mapping origin from a continuous pager index to a continuous day offset.
    init(store: CalendarStore, selectedDate: Date, todayPageIndex: Int) {
        self.store = store
        self.selectedDate = CalendarMath.startOfDay(selectedDate)
        self.todayStart = CalendarMath.startOfDay(.now)
        self.todayPageIndex = todayPageIndex
        self.groups = Self.buildGroups()
        super.init(frame: .zero)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Builds the view tree, applies the initial diffable snapshot, and adds the
    /// pill above the collection.
    private func setUp() {
        addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 80),
        ])

        pill.layer.cornerRadius = Radius.small
        pill.layer.cornerCurve = .continuous
        pill.layer.masksToBounds = true
        pill.clipsToBounds = true
        pill.isUserInteractionEnabled = false
        pill.isHidden = true
        addSubview(pill)

        applyInitialSnapshot()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        // BOOT: land on the selected day's week once we have a window + real bounds.
        // The strip is one contiguous `25 * pageWidth` horizontal section now, so
        // this imperatively sets `contentOffset.x = groupIndex(selectedDate) *
        // pageWidth` (today's/selected week) — it no longer relies on the removed
        // orthogonal scroll-to-section to reveal the right week.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.layoutIfNeeded()
            self.snapStripToWeek(containing: self.selectedDate, animated: false)
            self.snapPill(toDay: self.selectedDate, animated: false)
            self.assertGeometryEquivalenceOnce()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Keep the strip page and pill placed after bounds changes (orientation,
        // first layout). Both are pure functions of `selectedDate` here.
        guard collectionView.bounds.width > 0 else { return }
        snapStripToWeek(containing: selectedDate, animated: false)
        snapPill(toDay: selectedDate, animated: false)
    }

    // MARK: - Public API (FROZEN: apply(theme:), selectedWeekRange, loadCounts)

    /// Re-styles the pill + every realized tile in place. KEEP this signature —
    /// `DayScopeViewController.applyTheme()` calls it. All colors/metrics come
    /// from the passed ``CalendarTheme`` tokens.
    func apply(theme: CalendarTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        applyPillTreatment(theme: theme)
        reconfigureVisibleTiles()
        // Place the pill now that we have a theme (it was hidden pre-theme).
        if collectionView.bounds.width > 0 {
            snapPill(toDay: selectedDate, animated: false)
        }
    }

    /// The locale-week range `[weekStart, weekStart+6]` containing the currently
    /// selected day — the owner's anchor for ``loadCounts(for:context:)``.
    var selectedWeekRange: ClosedRange<Date> {
        weekRange(containing: selectedDate)
    }

    /// Fetches + caches daily task counts for `weekRange` and reconfigures the
    /// visible tiles' badges in place via a diffable reconfigure — never a
    /// `reloadData()` and never a fresh snapshot mid-gesture.
    func loadCounts(for weekRange: ClosedRange<Date>, context: ModelContext) async {
        await store.ensureCountsSynced(weekRange: weekRange, context: context)
        dailyCounts = store.dayCountsCache
        reconfigureVisibleTiles()
    }

    // MARK: - Public API (clean coupling — replaces the five-flag scaffold)

    /// THE single per-frame driving path. Called from the pager's
    /// `scrollViewDidScroll` with the raw fractional page index over the pager's
    /// `pageDates` space (e.g. `42.0` == selected day, `42.6` == 60% dragged
    /// toward the next day). Both the pill x and the strip's own content offset
    /// are pure functions of this one value, so they advance in lockstep.
    func syncToPager(continuousPageIndex: Double) {
        guard theme != nil, collectionView.bounds.width > 0 else { return }
        let dayOffset = continuousPageIndex - Double(todayPageIndex)
        applyGeometry(forContinuousDayOffset: dayOffset, animated: false)
    }

    /// Programmatic selection commit (settle, tap, jump-to-today, external). Updates
    /// the stored selected day, restyles tiles, pages the strip to the day's week
    /// (animated only when requested — never mid-gesture), and springs the pill to
    /// the exact tile. Idempotent: a settle that didn't move is a no-op move.
    ///
    /// Settle-path fight guard: after a drag settles the pager sits on an integer
    /// page, so the strip + pill are ALREADY at the exact target geometry from the
    /// last `syncToPager` frame. Re-running an animated move there re-springs from
    /// current-to-same-place and fights the live per-frame writes for one frame. So
    /// we resolve the final geometry first and, when the pill is already essentially
    /// there (settle, or any no-op commit), apply it IMPERATIVELY regardless of the
    /// requested `animated`. The spring is reserved for genuine discrete jumps
    /// (tap / jump-to-today / center) where the pill actually travels a distance.
    func commitSelection(date: Date, animated: Bool) {
        let normalized = CalendarMath.startOfDay(date)
        let dayChanged = normalized != selectedDate
        selectedDate = normalized
        if dayChanged { reconfigureVisibleTiles() }
        guard collectionView.bounds.width > 0 else { return }
        let alreadySettled = isPillAlreadyAt(day: normalized)
        let shouldAnimate = animated && !alreadySettled
        snapStripToWeek(containing: normalized, animated: shouldAnimate)
        snapPill(toDay: normalized, animated: shouldAnimate)
    }

    /// True when the pill is already sitting on `day`'s exact tile (within sub-pixel
    /// tolerance) — i.e. the live per-frame path already landed it there, as on a
    /// drag settle. Lets `commitSelection` skip the redundant animated re-move that
    /// would otherwise fight the last `syncToPager` write for a frame. Pure read of
    /// the cached pill origin against the closed-form target.
    private func isPillAlreadyAt(day date: Date) -> Bool {
        guard let lastPillOriginX else { return false }
        let dayOffset = Double(calendar.dateComponents([.day], from: todayStart, to: CalendarMath.startOfDay(date)).day ?? 0)
        guard let geometry = stripScreenGeometry(forContinuousDayOffset: dayOffset) else { return false }
        return abs(lastPillOriginX - geometry.pillScreenX) < 0.5
    }

    // MARK: - Diffable data source

    /// Section-per-`WeekGroup`, item-per-day. The section structure is preserved
    /// so `.groupPaging` keeps one full-width week per page.
    private func makeDataSource() -> UICollectionViewDiffableDataSource<WeekGroup, DayItem> {
        UICollectionViewDiffableDataSource<WeekGroup, DayItem>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: WeekDayTileCell.reuseIdentifier, for: indexPath
            )
            guard let self, let tile = cell as? WeekDayTileCell, let theme = self.theme else {
                return cell
            }
            self.configure(tile, with: item.date, theme: theme)
            return cell
        }
    }

    /// Applies the one and only full snapshot (at init) — every week page and its
    /// seven days. Counts/selection/theme later mutate via reconfigure only.
    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<WeekGroup, DayItem>()
        snapshot.appendSections(groups)
        for group in groups {
            snapshot.appendItems(group.dates.map { DayItem(date: $0) }, toSection: group)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    /// Reconfigures the currently-visible tiles in place (selected recolor, count
    /// badge, today dot) — never a fresh snapshot, never `reloadData()`.
    private func reconfigureVisibleTiles() {
        guard theme != nil else { return }
        var snapshot = dataSource.snapshot()
        let visibleItems = collectionView.indexPathsForVisibleItems.compactMap {
            dataSource.itemIdentifier(for: $0)
        }
        guard !visibleItems.isEmpty else { return }
        snapshot.reconfigureItems(visibleItems)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    /// Binds a tile to a date + the current state. Reuses `WeekDayTileCell.configure`.
    private func configure(_ tile: WeekDayTileCell, with date: Date, theme: CalendarTheme) {
        tile.configure(
            date: date,
            count: dailyCounts[CalendarMath.startOfDay(date)],
            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
            isToday: calendar.isDateInToday(date),
            showMonthLabel: isOutsideCurrentWindow(date),
            theme: theme
        )
    }

    // MARK: - Pill treatment (Liquid Glass / solid toggle)

    /// Sets the pill's fill from the theme — Liquid Glass warm-tinted toward
    /// `theme.primary`, or a solid `theme.primary` fill when the toggle is off.
    private func applyPillTreatment(theme: CalendarTheme) {
        pill.layer.cornerRadius = Radius.small
        if Self.usesLiquidGlass {
            let effect = UIGlassEffect(style: .regular)
            effect.tintColor = theme.primary
            effect.isInteractive = false
            pill.effect = effect
            pill.contentView.backgroundColor = .clear
        } else {
            pill.effect = nil
            pill.contentView.backgroundColor = theme.primary
        }
    }

    // MARK: - Unified screen geometry (ONE function drives pill + strip page)

    /// The pill's on-screen x (in the strip's own, non-scrolled coordinate space)
    /// and the strip collection's content offset, for a given continuous day
    /// offset. Both are derived from the SAME `frac` (the day's continuous column
    /// within its rendered week page), so they share one screen-space velocity and
    /// can never counter-move:
    ///
    /// - Within a week (`frac` ∈ 0...6): the strip page is FROZEN on the rendered
    ///   week and only the pill slides tile-to-tile. (Sub-week drags must not
    ///   scroll the whole week sideways.)
    /// - Across a boundary (`frac` ∈ 6...7, let `t = frac - 6`): the strip page
    ///   slides forward by exactly `t` pages while the pill rides the leading edge
    ///   of the incoming week — wrapping column 6 → 0 in lockstep on the same
    ///   frames as the page slide. At the integer endpoints the pill lands exactly
    ///   on the real Sunday (t=0) and next Monday (t=1) tiles.
    private struct StripScreenGeometry {
        let pillScreenX: CGFloat
        let stripContentOffsetX: CGFloat
    }

    /// Computes the unified geometry, or nil before bounds/groups are ready.
    private func stripScreenGeometry(forContinuousDayOffset dayOffset: Double) -> StripScreenGeometry? {
        let pageWidth = collectionView.bounds.width
        guard pageWidth > 0, let tileWidth = tileWidth(), let firstGroupStart = groups.first?.startDate else {
            return nil
        }
        let daysFirstToToday = Double(calendar.dateComponents([.day], from: firstGroupStart, to: todayStart).day ?? 0)
        let continuousDay = daysFirstToToday + dayOffset
        let lastWeekIndex = Double(groups.count - 1)

        // The rendered-page index is the WHOLE week (floored), clamped to the
        // built window — so the strip never advances for a sub-week drag.
        let rawWeekIndex = floor(continuousDay / Double(Self.daysPerGroup))
        let weekIndex = min(max(0, rawWeekIndex), lastWeekIndex)
        let frac = continuousDay - weekIndex * Double(Self.daysPerGroup)
        let pitch = tileWidth + Spacing.xs

        let maxOffset = max(0, collectionView.contentSize.width - pageWidth)
        let lastColumn = Double(Self.daysPerGroup - 1)

        // Within the week: page frozen, pill slides across the 7-up grid.
        guard frac > lastColumn, weekIndex < lastWeekIndex else {
            let pillScreenX = Spacing.md + CGFloat(min(frac, lastColumn)) * pitch
            let stripContentOffsetX = min(max(0, CGFloat(weekIndex) * pageWidth), maxOffset)
            return StripScreenGeometry(pillScreenX: pillScreenX, stripContentOffsetX: stripContentOffsetX)
        }

        // Boundary band (Sunday → next Monday): slide one page by `t` and ride the
        // pill from Sunday's screen slot to next Monday's, both as functions of `t`.
        let crossing = frac - lastColumn // ∈ (0, 1]
        let stripContentOffsetX = min(max(0, CGFloat(weekIndex + crossing) * pageWidth), maxOffset)
        // Sunday's tile (col 6 of the outgoing page) drifts left as the page scrolls.
        let sundayScreenX = Spacing.md + lastColumn * pitch - crossing * Double(pageWidth)
        // Next Monday's tile (col 0 of the incoming page) enters from the right.
        let mondayScreenX = Spacing.md + (1 - crossing) * Double(pageWidth)
        let pillScreenX = (1 - crossing) * sundayScreenX + crossing * mondayScreenX
        return StripScreenGeometry(pillScreenX: CGFloat(pillScreenX), stripContentOffsetX: stripContentOffsetX)
    }

    /// THE single per-frame driver. Writes the strip's content offset and the
    /// pill's frame from one unified geometry so they advance in lockstep. The
    /// strip offset is set imperatively (never `scrollToItem`) so no animation
    /// competes with the finger.
    private func applyGeometry(forContinuousDayOffset dayOffset: Double, animated: Bool) {
        guard let geometry = stripScreenGeometry(forContinuousDayOffset: dayOffset) else {
            pill.isHidden = true
            return
        }
        // Strip page first, so the pill's screen x (computed in the same frame
        // against this offset) lands correctly relative to the scrolled content.
        if lastWeekContentOffsetX == nil || abs((lastWeekContentOffsetX ?? 0) - geometry.stripContentOffsetX) >= 0.5 {
            lastWeekContentOffsetX = geometry.stripContentOffsetX
            collectionView.contentOffset = CGPoint(x: geometry.stripContentOffsetX, y: 0)
        }

        guard let tileWidth = tileWidth() else { return }
        let frame = CGRect(x: geometry.pillScreenX, y: 2, width: tileWidth, height: max(bounds.height - 4, 0))
        // CPU-only guard: skip the geometry write when the pill hasn't visibly moved.
        if !animated, let last = lastPillOriginX, abs(last - frame.minX) < 0.5 {
            return
        }
        lastPillOriginX = frame.minX
        pill.isHidden = false
        setPillFrame(frame, animated: animated)
    }

    /// Snaps the pill to a discrete day's exact tile column (programmatic only),
    /// animated via the spring when requested. Goes through the same unified
    /// geometry as the per-frame path, so a settle/tap lands pixel-identical to
    /// where the drag left the pill.
    private func snapPill(toDay date: Date, animated: Bool) {
        let dayOffset = Double(calendar.dateComponents([.day], from: todayStart, to: CalendarMath.startOfDay(date)).day ?? 0)
        applyGeometry(forContinuousDayOffset: dayOffset, animated: animated)
    }

    /// Writes the pill frame, with an optional spring (programmatic selection only;
    /// never during `scrollViewDidScroll`).
    private func setPillFrame(_ frame: CGRect, animated: Bool) {
        guard animated else {
            pill.frame = frame
            return
        }
        UIView.animate(
            withDuration: Self.pillSpringDuration,
            delay: 0,
            usingSpringWithDamping: Self.pillSpringDamping,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: { self.pill.frame = frame }
        )
    }

    /// Snaps the strip to the integer week page containing `date` (programmatic).
    /// Imperative offset set; `animated` wraps it in a UIView animation since we
    /// are NOT in a gesture here (gesture-time forbids animated strip moves).
    private func snapStripToWeek(containing date: Date, animated: Bool) {
        let pageWidth = collectionView.bounds.width
        guard pageWidth > 0 else { return }
        guard let groupIndex = groupIndex(containing: date) else { return }
        let maxOffset = max(0, collectionView.contentSize.width - pageWidth)
        let targetX = min(CGFloat(groupIndex) * pageWidth, maxOffset)
        lastWeekContentOffsetX = targetX
        let apply = { self.collectionView.contentOffset = CGPoint(x: targetX, y: 0) }
        guard animated else {
            apply()
            return
        }
        UIView.animate(
            withDuration: Self.pillSpringDuration,
            delay: 0,
            usingSpringWithDamping: Self.pillSpringDamping,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: apply
        )
    }

    // MARK: - Layout

    /// ONE contiguous horizontal strip: each `WeekGroup` is a section exactly
    /// `pageWidth` wide, and with the outer collection scrolling horizontally and
    /// NO orthogonal behavior the 25 sections concatenate along x into a single
    /// `25 * pageWidth` content width. That is what makes the imperative
    /// `contentOffset.x` writes (the per-frame geometry driver) actually move the
    /// strip; the old `.groupPaging` wrapped each week in its own nested scroller,
    /// pinning `contentSize.width ≈ pageWidth` so every non-zero target clamped to 0.
    ///
    /// Each section is exactly `pageWidth` wide: the group is the ABSOLUTE
    /// `7*tileWidth + 6*xs` (NOT `fractionalWidth(1.0)`, which would resolve to the
    /// full container width and then stack the `md` insets on top — see the group
    /// note below), and the section's leading/trailing `md` insets bring it to
    /// `md + (7*tileWidth + 6*xs) + md == pageWidth`. Each tile is the ABSOLUTE
    /// `tileWidth` so the grid is provably the uniform 7-up grid the closed form
    /// assumes: leading inset `md`, 7 items of `tileWidth`, 6 inter-item gaps of
    /// `xs`, trailing inset `md` (`tileWidth = (pageWidth - 2*md - 6*xs)/7`, matching
    /// `tileWidth()`). This is what makes the 25 sections tile to a true
    /// `25 * pageWidth` strip on EVERY device width, so the `section * pageWidth`
    /// content-offset writes and the closed-form pill x land on the right day.
    private func makeLayout() -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .horizontal
        let daysPerGroup = Self.daysPerGroup
        return UICollectionViewCompositionalLayout(
            sectionProvider: { _, layoutEnvironment in
                let pageWidth = layoutEnvironment.container.effectiveContentSize.width
                // Derive the tile width identically to `tileWidth()` so the closed
                // form is exact; fall back to a fractional split before bounds exist.
                let available = pageWidth - Spacing.md * 2 - Spacing.xs * CGFloat(daysPerGroup - 1)
                let tileWidth = available > 0
                    ? available / CGFloat(daysPerGroup)
                    : pageWidth / CGFloat(daysPerGroup)
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .absolute(tileWidth),
                    heightDimension: .fractionalHeight(1.0)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                // The group spans exactly the seven tiles + six gaps — i.e.
                // `pageWidth - 2*md`. It must NOT be `.fractionalWidth(1.0)`: that
                // resolves to the FULL container width (pageWidth), and the section's
                // leading/trailing `md` insets then stack ON TOP, making each section
                // `pageWidth + 2*md` wide. The sections would drift right by
                // `section * 2*md`, so the `section * pageWidth` content-offset writes
                // (and the closed-form pill x) land on the wrong day for every
                // non-boot week. An absolute `7*tileWidth + 6*xs` makes
                // `group + leading md + trailing md == pageWidth` exactly, so the 25
                // sections tile to a true `25 * pageWidth` strip on every device width.
                let groupWidth = tileWidth * CGFloat(daysPerGroup)
                    + Spacing.xs * CGFloat(daysPerGroup - 1)
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .absolute(groupWidth),
                    heightDimension: .fractionalHeight(1.0)
                )
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: groupSize, repeatingSubitem: item, count: daysPerGroup
                )
                group.interItemSpacing = .fixed(Spacing.xs)
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md
                )
                // NO orthogonalScrollingBehavior: sections tile contiguously along x.
                return section
            },
            configuration: configuration
        )
    }

    /// Width of a single tile, derived from the strip's content width (full width
    /// minus the section's leading/trailing insets and the six inter-item gaps).
    private func tileWidth() -> CGFloat? {
        let width = bounds.width
        guard width > 0 else { return nil }
        let insets = Spacing.md * 2
        let gaps = Spacing.xs * CGFloat(Self.daysPerGroup - 1)
        let available = width - insets - gaps
        guard available > 0 else { return nil }
        return available / CGFloat(Self.daysPerGroup)
    }

    /// Boot-time assertion that the closed form matches the real layout geometry,
    /// so the per-frame fast path is provably correct. Debug-only.
    ///
    /// TWO checks — the second is what catches the orthogonal-paging class of bug
    /// the old assert silently passed:
    ///
    /// 1. **Selected tile, screen space** (offset 0): the on-screen (converted)
    ///    closed-form column-x equals the realized tile's `minX`. This is the single
    ///    configuration where local-X == closed form, so it alone is NOT sufficient.
    /// 2. **A NON-zero week, content space** (week +1): the closed-form ABSOLUTE
    ///    content-x — `weekIndex * pageWidth + md + column*(tileWidth+xs)` — equals
    ///    the realized tile's `layoutAttributes.frame.minX` (raw, un-converted, i.e.
    ///    in the collection's content coordinates). Under the old `.groupPaging`
    ///    layout every section started at content-x 0 (its own orthogonal scroller),
    ///    so a week +1 tile's `minX` was ~`md + column*pitch`, NOT
    ///    `pageWidth + md + column*pitch` — this assert would have fired. With the
    ///    contiguous strip it holds, proving the 25 weeks tile to `25 * pageWidth`.
    private func assertGeometryEquivalenceOnce() {
        #if DEBUG
        guard let selectedSection = groupIndex(containing: selectedDate) else { return }
        guard let tileWidth = tileWidth() else { return }
        let pageWidth = collectionView.bounds.width
        let pitch = tileWidth + Spacing.xs

        // Check 1 — selected tile, screen (converted) space at boot offset.
        let column = columnInWeek(of: selectedDate)
        let indexPath = IndexPath(item: column, section: selectedSection)
        guard let attrs = collectionView.layoutAttributesForItem(at: indexPath) else { return }
        let realRect = collectionView.convert(attrs.frame, to: self)
        let closedFormScreenX = Spacing.md + CGFloat(column) * pitch
        assert(
            abs(realRect.minX - closedFormScreenX) < 1.0,
            "WeekStripView: closed-form pill x (\(closedFormScreenX)) diverged from layoutAttributes minX (\(realRect.minX)); layout is no longer a uniform 7-up grid — switch the per-frame path to read layoutAttributes."
        )

        // Check 2 — a NON-zero week (selected week + 1, when one exists), CONTENT
        // space. This is the one the per-week orthogonal-paging defect fails.
        let otherSection = selectedSection + 1 <= groups.count - 1 ? selectedSection + 1 : selectedSection - 1
        guard otherSection >= 0, otherSection != selectedSection else { return }
        let otherColumn = 3 // a mid-week column; any column works
        let otherIndexPath = IndexPath(item: otherColumn, section: otherSection)
        guard let otherAttrs = collectionView.layoutAttributesForItem(at: otherIndexPath) else { return }
        let closedFormContentX = CGFloat(otherSection) * pageWidth + Spacing.md + CGFloat(otherColumn) * pitch
        assert(
            abs(otherAttrs.frame.minX - closedFormContentX) < 1.0,
            "WeekStripView: closed-form CONTENT x (\(closedFormContentX)) for week section \(otherSection) diverged from real layoutAttributes minX (\(otherAttrs.frame.minX)); the weeks are NOT a contiguous 25*pageWidth strip (e.g. orthogonalScrollingBehavior is back, pinning contentSize.width ≈ pageWidth) — the imperative contentOffset.x writes will clamp and the pill will sit on the wrong day for any non-boot week."
        )
        #endif
    }

    // MARK: - Week math

    /// The 0...6 column of `date` within its locale week (first weekday = column 0).
    private func columnInWeek(of date: Date) -> Int {
        let weekStart = weekStart(for: date)
        let day = CalendarMath.startOfDay(date)
        let offset = calendar.dateComponents([.day], from: weekStart, to: day).day ?? 0
        return min(max(0, offset), Self.daysPerGroup - 1)
    }

    /// The locale-week start (first weekday) for the week containing `date`.
    private func weekStart(for date: Date) -> Date {
        let day = CalendarMath.startOfDay(date)
        let weekday = calendar.component(.weekday, from: day)
        let delta = (weekday - calendar.firstWeekday + Self.daysPerGroup) % Self.daysPerGroup
        return calendar.date(byAdding: .day, value: -delta, to: day) ?? day
    }

    /// The closed `[weekStart, weekStart+6]` range of the week containing `date`.
    private func weekRange(containing date: Date) -> ClosedRange<Date> {
        let start = weekStart(for: date)
        let end = calendar.date(byAdding: .day, value: Self.daysPerGroup - 1, to: start) ?? start
        return start...end
    }

    /// The `groups` index whose week contains `date`, or nil if outside the window.
    private func groupIndex(containing date: Date) -> Int? {
        groups.firstIndex { group in
            group.dates.contains { calendar.isDate($0, inSameDayAs: date) }
        }
    }

    /// Days more than 3 days from today get a month label, matching the SwiftUI strip.
    private func isOutsideCurrentWindow(_ date: Date) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents(
            [.day], from: today, to: calendar.startOfDay(for: date)
        ).day ?? 0
        return abs(days) > 3
    }

    // MARK: - Group building

    /// The full ±12 locale-week window, ascending, built once. Each group starts
    /// on the locale's first weekday so tiles read M–S / S–S per locale and the
    /// selected day stays put inside its real week, never re-centered.
    private static func buildGroups() -> [WeekGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let delta = (weekday - calendar.firstWeekday + daysPerGroup) % daysPerGroup
        guard let thisWeekStart = calendar.date(byAdding: .day, value: -delta, to: today) else { return [] }
        return groupRange.compactMap { weekOffset in
            makeGroup(weekStart: thisWeekStart, weekOffset: weekOffset, calendar: calendar)
        }
    }

    private static func makeGroup(weekStart: Date, weekOffset: Int, calendar: Calendar) -> WeekGroup? {
        guard let start = calendar.date(byAdding: .day, value: weekOffset * daysPerGroup, to: weekStart) else {
            return nil
        }
        let dates = (0..<daysPerGroup).compactMap { index in
            calendar.date(byAdding: .day, value: index, to: start)
        }
        guard dates.count == daysPerGroup else { return nil }
        return WeekGroup(startDate: start, dates: dates)
    }
}

// MARK: - UICollectionViewDelegate (tap-to-select)

extension WeekStripView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        onSelectDate?(item.date)
    }
}
