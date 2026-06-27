//
//  DayPageCell.swift
//  cue
//

import UIKit

/// One full-width page in the horizontal day pager. Renders a single day in the
/// store's current ``CalendarViewMode`` — a vertically-scrolling hour timeline
/// (`.timeline`) or an agenda list of paper cards (`.list`) — under a Fraunces
/// section heading with a clay rule, matching `TimelineDayPage` / `ListDayPage`.
///
/// The cell is *dumb*: the owning ``DayScopeViewController`` binds it with the
/// day, its pre-bucketed events, the mode, the theme, and the two intent
/// closures (`onToggle`, `onSelect`). It performs no data work and holds no store.
final class DayPageCell: UICollectionViewCell {

    static let reuseIdentifier = "DayPageCell"

    // MARK: - Callbacks

    var onToggle: ((OccurrenceVM) -> Void)?
    var onSelect: ((OccurrenceVM) -> Void)?

    // MARK: - Header

    private let headingLabel = UILabel()
    private let headingRule = UIView()

    // MARK: - Timeline mode

    private let timelineScroll = UIScrollView()
    private let timelineContent = DayTimelineDayView()

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

        timelineScroll.translatesAutoresizingMaskIntoConstraints = false
        timelineScroll.showsVerticalScrollIndicator = false
        timelineScroll.alwaysBounceVertical = true
        timelineContent.translatesAutoresizingMaskIntoConstraints = false
        timelineScroll.addSubview(timelineContent)
        timelineContent.onToggle = { [weak self] event in self?.onToggle?(event) }
        timelineContent.onSelect = { [weak self] event in self?.onSelect?(event) }
        contentView.addSubview(timelineScroll)

        contentView.addSubview(listCollection)
        setUpEmptyState()

        NSLayoutConstraint.activate([
            headingLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.sm),
            headingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.lg),
            headingLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -Spacing.lg),

            headingRule.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: Spacing.xs),
            headingRule.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.lg),
            headingRule.widthAnchor.constraint(equalToConstant: 44),
            headingRule.heightAnchor.constraint(equalToConstant: 2),

            timelineScroll.topAnchor.constraint(equalTo: headingRule.bottomAnchor, constant: Spacing.md),
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
        emptyStateIcon.image = UIImage(systemName: "circle.dashed")
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
            emptyStateStack.centerXAnchor.constraint(equalTo: listCollection.centerXAnchor),
            emptyStateStack.centerYAnchor.constraint(equalTo: listCollection.centerYAnchor),
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
        sortedListEvents = []
    }

    // MARK: - Configuration

    /// Binds the page to a day, its events, the active mode, and a theme.
    func configure(date: Date, events: [OccurrenceVM], mode: CalendarViewMode, theme: CalendarTheme) {
        self.date = date
        self.events = events
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
        // Re-feed the timeline so its block colors refresh.
        if mode == .timeline {
            timelineContent.configure(events: events, date: date, theme: theme)
        } else {
            listCollection.reloadData()
        }
    }

    private func applyTheme() {
        guard let theme else { return }
        headingLabel.font = theme.titleL
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
        timelineScroll.isHidden = !isTimeline
        listCollection.isHidden = isTimeline

        if isTimeline {
            emptyStateStack.isHidden = true
            timelineContent.configure(events: events, date: date, theme: theme)
            setNeedsLayout()
            layoutIfNeeded()
            applyInitialTimelineScrollIfNeeded()
        } else {
            emptyStateStack.isHidden = !events.isEmpty
            listCollection.reloadData()
        }
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
            if isToday { return String(localized: "calendar.timeline.heading.today") }
            let formatted = date.formatted(.dateTime.weekday().day().month(.abbreviated))
            return String(format: String(localized: "calendar.timeline.heading.other"), formatted)
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
