//
//  DayPageCell.swift
//  cue
//

import UIKit

/// One full-width page in the horizontal day pager. Renders a single day in the
/// store's current ``CalendarViewMode`` — a vertically-scrolling hour timeline
/// (`.timeline`) or an agenda list of clean cards (`.list`) — under a serif
/// section heading with a clay rule, matching `TimelineDayPage` / `ListDayPage`.
///
/// The cell is *dumb*: the owning ``DayScopeViewController`` binds it with the
/// day, its pre-bucketed events, the mode, the theme, and the two intent
/// closures (`onToggle`, `onSelect`). It performs no data work and holds no store.
final class DayPageCell: UICollectionViewCell {

    static let reuseIdentifier = "DayPageCell"

    /// Bottom clearance added to the timeline scroll so the final tile can scroll
    /// clear of the floating (Liquid Glass) tab bar and stay fully reachable. The
    /// tab bar sits ~21pt off the bottom at ~64pt tall; ~132pt matches the design's
    /// day-body `padding-bottom: 132px`. This is IN ADDITION to the ~30-min tail the
    /// timeline content already carries (see ``DayTimelineLayout``'s `tailPadding`).
    private static let timelineBottomClearance: CGFloat = 132

    // MARK: - Callbacks

    var onToggle: ((OccurrenceVM) -> Void)?
    var onSelect: ((OccurrenceVM) -> Void)?

    // MARK: - Header

    private let headingLabel = UILabel()
    private let headingRule = UIView()

    // MARK: - Timeline mode

    /// The ALL-DAY band shown above the timeline scroll (spec §3). Present in the
    /// hierarchy always; collapsed (hidden + zero-height constraint) when the day
    /// has no all-day events.
    private let allDayBand = DayAllDayBandView()
    private let timelineScroll = UIScrollView()
    private let timelineContent = DayTimelineDayView()

    /// Timeline-scroll top constraints, toggled by whether the all-day band has
    /// content: below the band (with content) vs directly below the heading rule.
    private var timelineTopBelowBand: NSLayoutConstraint?
    private var timelineTopBelowRule: NSLayoutConstraint?
    /// All-day band top constraint (below the heading rule).
    private var allDayBandTop: NSLayoutConstraint?

    // MARK: - List mode

    private lazy var listCollection: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: makeListLayout())
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.register(DayAgendaCell.self, forCellWithReuseIdentifier: DayAgendaCell.reuseIdentifier)
        return view
    }()

    private let emptyStateLabel = UILabel()
    private let emptyStateIcon = UIImageView()
    private let emptyStateStack = UIStackView()

    // MARK: - State

    private var date = Date()
    private var events: [OccurrenceVM] = []
    /// The day's TIMED occurrences (all-day pulled out into `allDayBand`), fed to
    /// the timeline so all-day items no longer render at their midnight start.
    private var timedEvents: [OccurrenceVM] = []
    /// The day's ALL-DAY occurrences, rendered in `allDayBand` above the timeline.
    private var allDayEvents: [OccurrenceVM] = []
    private var sortedListEvents: [OccurrenceVM] = []
    private var mode: CalendarViewMode = .timeline
    private var theme: CalendarTheme?
    private var didInitialTimelineScroll = false

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        headingLabel.numberOfLines = 1
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        headingRule.translatesAutoresizingMaskIntoConstraints = false
        headingRule.layer.cornerRadius = 1
        contentView.addSubview(headingLabel)
        contentView.addSubview(headingRule)

        allDayBand.translatesAutoresizingMaskIntoConstraints = false
        allDayBand.onSelect = { [weak self] event in self?.onSelect?(event) }
        contentView.addSubview(allDayBand)

        timelineScroll.translatesAutoresizingMaskIntoConstraints = false
        timelineScroll.showsVerticalScrollIndicator = false
        timelineScroll.alwaysBounceVertical = true
        // Deterministic bottom clearance for the floating tab bar: the page ignores
        // the bottom safe area (it extends behind the bar), so drive the clearance
        // explicitly and stop the system layering its own adjustment on top.
        timelineScroll.contentInsetAdjustmentBehavior = .never
        timelineScroll.contentInset.bottom = Self.timelineBottomClearance
        timelineScroll.verticalScrollIndicatorInsets.bottom = Self.timelineBottomClearance
        timelineContent.translatesAutoresizingMaskIntoConstraints = false
        timelineScroll.addSubview(timelineContent)
        timelineContent.onToggle = { [weak self] event in self?.onToggle?(event) }
        timelineContent.onSelect = { [weak self] event in self?.onSelect?(event) }
        contentView.addSubview(timelineScroll)

        contentView.addSubview(listCollection)
        setUpEmptyState()

        let allDayBandTop = allDayBand.topAnchor.constraint(equalTo: headingRule.bottomAnchor, constant: Spacing.md)
        self.allDayBandTop = allDayBandTop
        // Two toggled timeline-scroll top constraints: below the all-day band when
        // it has content, else directly below the heading rule (band collapsed).
        let timelineTopBelowBand = timelineScroll.topAnchor.constraint(
            equalTo: allDayBand.bottomAnchor, constant: Spacing.md
        )
        let timelineTopBelowRule = timelineScroll.topAnchor.constraint(
            equalTo: headingRule.bottomAnchor, constant: Spacing.md
        )
        self.timelineTopBelowBand = timelineTopBelowBand
        self.timelineTopBelowRule = timelineTopBelowRule

        NSLayoutConstraint.activate([
            headingLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.sm),
            headingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.lg),
            headingLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -Spacing.lg),

            headingRule.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: Spacing.xs),
            headingRule.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.lg),
            headingRule.widthAnchor.constraint(equalToConstant: 44),
            headingRule.heightAnchor.constraint(equalToConstant: 2),

            allDayBandTop,
            allDayBand.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.lg),
            allDayBand.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.lg),

            timelineTopBelowRule,
            timelineScroll.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            timelineScroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            timelineScroll.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            timelineContent.topAnchor.constraint(equalTo: timelineScroll.contentLayoutGuide.topAnchor),
            timelineContent.bottomAnchor.constraint(equalTo: timelineScroll.contentLayoutGuide.bottomAnchor),
            timelineContent.leadingAnchor.constraint(equalTo: timelineScroll.frameLayoutGuide.leadingAnchor, constant: Spacing.lg),
            timelineContent.trailingAnchor.constraint(equalTo: timelineScroll.frameLayoutGuide.trailingAnchor, constant: -Spacing.lg),

            listCollection.topAnchor.constraint(equalTo: headingRule.bottomAnchor, constant: Spacing.md),
            listCollection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            listCollection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            listCollection.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    private func setUpEmptyState() {
        emptyStateIcon.image = UIImage(systemName: "calendar")
        emptyStateIcon.contentMode = .scaleAspectFit
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.textAlignment = .center
        emptyStateStack.translatesAutoresizingMaskIntoConstraints = false
        emptyStateStack.axis = .vertical
        emptyStateStack.alignment = .center
        emptyStateStack.spacing = Spacing.sm
        emptyStateStack.isHidden = true
        emptyStateStack.addArrangedSubview(emptyStateIcon)
        emptyStateStack.addArrangedSubview(emptyStateLabel)
        contentView.addSubview(emptyStateStack)
        NSLayoutConstraint.activate([
            emptyStateStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            // TOP-anchored ~72px below the heading rule (matches the design's
            // padding:72px from the top of the scroll body), not vertically centered.
            emptyStateStack.topAnchor.constraint(equalTo: headingRule.bottomAnchor, constant: 72),
            emptyStateStack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: Spacing.xl),
            emptyStateStack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -Spacing.xl),
            emptyStateIcon.widthAnchor.constraint(equalToConstant: 44),
            emptyStateIcon.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onToggle = nil
        onSelect = nil
        didInitialTimelineScroll = false
        events = []
        timedEvents = []
        allDayEvents = []
        sortedListEvents = []
    }

    // MARK: - Configuration

    /// Binds the page to a day, its events, the active mode, and a theme. Splits
    /// all-day occurrences out of the timeline feed and into the all-day band.
    func configure(date: Date, events: [OccurrenceVM], mode: CalendarViewMode, theme: CalendarTheme) {
        self.date = date
        self.events = events
        self.timedEvents = events.filter { !$0.isAllDay }
        self.allDayEvents = events.filter { $0.isAllDay }
        self.mode = mode
        self.theme = theme
        self.sortedListEvents = Self.sortedForList(events)
        self.didInitialTimelineScroll = false
        applyTheme()
        applyMode()
    }

    /// Enables/disables this page's inner scrolling (timeline scroll + list
    /// scroll), so the container can freeze it during a zoom transition.
    func setInnerScrollEnabled(_ isEnabled: Bool) {
        timelineScroll.isScrollEnabled = isEnabled
        listCollection.isScrollEnabled = isEnabled
    }

    /// Re-styles without changing data/mode.
    func apply(theme: CalendarTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        applyTheme()
        // Re-feed the timeline + all-day band so their block colors refresh.
        if mode == .timeline {
            timelineContent.configure(events: timedEvents, date: date, theme: theme)
            if !allDayEvents.isEmpty { allDayBand.apply(theme: theme) }
        } else {
            listCollection.reloadData()
        }
    }

    private func applyTheme() {
        guard let theme else { return }
        // System-sans title — CUE — Clean keeps IBM Plex Serif for display titles
        // only; this body section heading uses the sans titleL variant.
        headingLabel.font = theme.titleLSans
        headingLabel.textColor = theme.textPrimary
        headingLabel.text = headingText(for: mode)
        headingRule.backgroundColor = theme.secondary

        emptyStateIcon.tintColor = theme.textSecondary
        let emptyText = NSMutableAttributedString(
            string: String(localized: "calendar.list.empty.title"),
            attributes: [.font: theme.titleM, .foregroundColor: theme.textPrimary]
        )
        emptyText.append(NSAttributedString(
            string: "\n" + String(localized: "calendar.list.empty.description"),
            attributes: [.font: theme.callout, .foregroundColor: theme.textSecondary]
        ))
        emptyStateLabel.attributedText = emptyText
    }

    private func applyMode() {
        guard let theme else { return }
        headingLabel.text = headingText(for: mode)
        let isTimeline = mode == .timeline
        let isEmpty = events.isEmpty
        // The all-day band only participates in TIMELINE mode (the list mode shows
        // all-day items as ordinary agenda rows). Toggle its presence + the
        // timeline-scroll top constraint accordingly.
        updateAllDayBand(active: isTimeline, theme: theme)

        // A timeline page is "empty" (clean page, no ruled 24h grid) only when
        // there are NO timed events. All-day-only days still show the band above,
        // so the empty placeholder is suppressed when the band carries content.
        let hasTimed = !timedEvents.isEmpty
        // An empty TODAY still shows the timeline: DayTimelineLayout builds a
        // fill-height 00:00→now / now→24:00 split with the now-mark between them,
        // so keep the scroll visible even with no timed events. A non-today empty
        // day has nothing to render there and falls back to the placeholder.
        let showTimeline = isTimeline && (hasTimed || Calendar.current.isDateInToday(date))
        // The clean-page placeholder is reserved for a truly-empty NON-today day in
        // timeline mode: no timed events and not today (an empty today shows the
        // now-split timeline instead).
        let timelineIsEmpty = isTimeline && !hasTimed && !Calendar.current.isDateInToday(date)
        timelineScroll.isHidden = !showTimeline
        listCollection.isHidden = isTimeline || isEmpty

        if isTimeline {
            // Show the empty placeholder only for a truly-clean non-today empty day
            // (an empty today renders the fill-height now-split timeline instead).
            emptyStateStack.isHidden = !timelineIsEmpty
            timelineContent.configure(events: timedEvents, date: date, theme: theme)
            setNeedsLayout()
            layoutIfNeeded()
            applyInitialTimelineScrollIfNeeded()
        } else {
            emptyStateStack.isHidden = !events.isEmpty
            listCollection.reloadData()
        }
    }

    /// Shows/hides the all-day band and swaps the timeline-scroll top constraint
    /// between "below the band" and "below the heading rule". The band renders only
    /// in timeline mode and only when there are all-day events.
    private func updateAllDayBand(active: Bool, theme: CalendarTheme) {
        let showBand = active && !allDayEvents.isEmpty
        allDayBand.isHidden = !showBand
        if showBand {
            allDayBand.configure(events: allDayEvents, theme: theme)
        }
        timelineTopBelowRule?.isActive = !showBand
        timelineTopBelowBand?.isActive = showBand
        // Collapse the band's top gap when hidden so it claims no vertical space.
        allDayBandTop?.constant = showBand ? Spacing.md : 0
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if mode == .timeline {
            applyInitialTimelineScrollIfNeeded()
        }
    }

    // MARK: - Timeline initial scroll

    /// Centers the current hour (today) or 08:00 (other days) once the timeline
    /// has a real height, mirroring `TimelineDayPage.applyInitialScroll`.
    private func applyInitialTimelineScrollIfNeeded() {
        guard mode == .timeline, !didInitialTimelineScroll else { return }
        let viewportHeight = timelineScroll.bounds.height
        guard viewportHeight > 0 else { return }
        didInitialTimelineScroll = true

        let targetCenter = timelineContent.layout.isToday(date)
            ? timelineContent.layout.y(for: Date())
            : timelineContent.layout.yForHourLine(8)
        let maxOffset = max(0, timelineContent.intrinsicContentSize.height - viewportHeight)
        let offsetY = min(max(0, targetCenter - viewportHeight / 2), maxOffset)
        timelineScroll.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
    }

    // MARK: - Headings

    private func headingText(for mode: CalendarViewMode) -> String {
        let isToday = Calendar.current.isDateInToday(date)
        switch mode {
        case .timeline:
            // Constant "Schedule" heading — the nav bar already carries the date,
            // so the timeline body heading is a stable section label (per spec),
            // not a duplicate date.
            return String(localized: "calendar.timeline.heading", defaultValue: "Schedule")
        case .list:
            if isToday { return String(localized: "calendar.list.heading.today") }
            let formatted = date.formatted(.dateTime.weekday().day().month(.abbreviated))
            return String(format: String(localized: "calendar.list.heading.other"), formatted)
        }
    }

    // MARK: - List sorting

    /// Incomplete tasks chronological; completed sink to the bottom — matches
    /// `ListDayPage.sortedEvents`.
    private static func sortedForList(_ events: [OccurrenceVM]) -> [OccurrenceVM] {
        events.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
            return lhs.startAt < rhs.startAt
        }
    }

    private func makeListLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(80)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = Spacing.sm
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0, leading: Spacing.lg, bottom: Spacing.xxl, trailing: Spacing.lg
        )
        return UICollectionViewCompositionalLayout(section: section)
    }
}

// MARK: - List data source

extension DayPageCell: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sortedListEvents.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: DayAgendaCell.reuseIdentifier, for: indexPath
        )
        guard let agenda = cell as? DayAgendaCell, let theme else { return cell }
        let event = sortedListEvents[indexPath.item]
        agenda.configure(with: event, theme: theme)
        agenda.onToggle = { [weak self] event in self?.onToggle?(event) }
        agenda.onSelect = { [weak self] event in self?.onSelect?(event) }
        return agenda
    }
}
