//
//  DayTimelineEventCell.swift
//  cue
//

import UIKit

/// A single event block on the day timeline — the UIKit port of
/// `DayScheduleView.eventCard`: an espresso (`theme.primary`) rounded block with
/// a cream title, optional strikethrough when completed, a faded look once done,
/// and — for tasks — a compact cream completion toggle (the timeline's terse
/// stand-in for the list mode's wax seal).
///
/// The cell stays *dumb*: it renders an ``OccurrenceVM`` and reports two intents
/// (`onToggle`, `onSelect`) through closures the owning view controller sets. It
/// holds no store reference and performs no data work.
final class DayTimelineEventCell: UIView {

    // MARK: - Callbacks

    /// Fired when the completion toggle is tapped. Only present for tasks
    /// (`requiresCompletion`). The VC routes this to
    /// `store.toggleCompletion(occurrenceKey:context:)`.
    var onToggle: ((OccurrenceVM) -> Void)?
    /// Fired when the card body (not the toggle) is tapped — open task detail.
    var onSelect: ((OccurrenceVM) -> Void)?

    // MARK: - Subviews

    private let titleLabel = UILabel()
    private let toggleButton = UIButton(type: .system)
    private let bodyTapTarget = UIControl()

    private var event: OccurrenceVM?
    private var theme: CalendarTheme?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Builds the static view hierarchy once. Per-event content + theme are
    /// applied later in ``configure(with:theme:)`` / ``apply(theme:)``.
    private func setUp() {
        layer.cornerRadius = Radius.small
        layer.cornerCurve = .continuous
        clipsToBounds = true

        bodyTapTarget.translatesAutoresizingMaskIntoConstraints = false
        bodyTapTarget.addTarget(self, action: #selector(handleSelect), for: .touchUpInside)
        addSubview(bodyTapTarget)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 2
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        toggleButton.addTarget(self, action: #selector(handleToggle), for: .touchUpInside)
        addSubview(toggleButton)

        NSLayoutConstraint.activate([
            bodyTapTarget.topAnchor.constraint(equalTo: topAnchor),
            bodyTapTarget.leadingAnchor.constraint(equalTo: leadingAnchor),
            bodyTapTarget.trailingAnchor.constraint(equalTo: trailingAnchor),
            bodyTapTarget.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: Spacing.xs),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Spacing.sm),

            toggleButton.topAnchor.constraint(equalTo: topAnchor, constant: Spacing.xs),
            toggleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Spacing.sm),
            toggleButton.leadingAnchor.constraint(
                greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: Spacing.sm
            ),
            toggleButton.widthAnchor.constraint(equalToConstant: 22),
            toggleButton.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    // MARK: - Configuration

    /// Binds the cell to `event` and styles it with `theme`. Idempotent — safe to
    /// call on reuse.
    func configure(with event: OccurrenceVM, theme: CalendarTheme) {
        self.event = event
        self.theme = theme
        applyContent()
        applyTheme()
    }

    /// Re-styles the cell with a (possibly new) theme without changing its event.
    func apply(theme: CalendarTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        applyTheme()
    }

    private func applyContent() {
        guard let event else { return }
        toggleButton.isHidden = !event.requiresCompletion
        let symbol = event.isCompleted ? "checkmark.circle.fill" : "circle"
        toggleButton.setImage(
            UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)),
            for: .normal
        )
        toggleButton.accessibilityLabel = String(
            localized: event.isCompleted ? "task.toggle.markNotDone" : "task.toggle.markDone"
        )
        bodyTapTarget.accessibilityLabel = event.title
        bodyTapTarget.accessibilityTraits = .button
        alpha = event.isCompleted ? 0.45 : 1.0
    }

    private func applyTheme() {
        guard let theme, let event else { return }
        backgroundColor = theme.primary
        toggleButton.tintColor = theme.onAccent

        // Title with strikethrough when completed (matches the SwiftUI card).
        let attributes: [NSAttributedString.Key: Any] = [
            .font: theme.label,
            .foregroundColor: theme.onAccent,
            .strikethroughStyle: event.isCompleted ? NSUnderlineStyle.single.rawValue : 0,
            .strikethroughColor: theme.onAccent,
        ]
        titleLabel.attributedText = NSAttributedString(string: event.title, attributes: attributes)
    }

    // MARK: - Actions

    @objc private func handleToggle() {
        guard let event else { return }
        onToggle?(event)
    }

    @objc private func handleSelect() {
        guard let event else { return }
        onSelect?(event)
    }
}
