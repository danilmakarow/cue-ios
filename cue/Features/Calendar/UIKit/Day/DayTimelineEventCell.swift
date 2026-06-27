//
//  DayTimelineEventCell.swift
//  cue
//

import UIKit

/// A single event block on the day timeline — the CUE — Clean port of the spec's
/// flat timeline task block: a WHITE (`surface`) rounded card lifted by a 1px
/// border + soft floating shadow, with a 3px GROUP-colored left rail (resolved via
/// ``CalendarColor``), an ink (`textPrimary`) title, optional strikethrough +
/// fade when completed, and — for tasks — a compact completion toggle.
///
/// This replaces the old solid-clay-fill block: on the white CUE canvas the day
/// timeline reads as a stack of crisp cards whose colored rail names the GROUP,
/// matching `Calendar Day.dc.html` (and the Today hero), not a wall of clay.
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

    /// The 3px group-colored rail down the leading edge.
    private let rail = UIView()
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
        layer.cornerRadius = Radius.card
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        // Soft floating shadow lifts the card off the white timeline (params filled
        // per-theme in `applyTheme`). The card is NOT clipped so the shadow shows;
        // the rail's own corners are rounded to the card radius instead.
        clipsToBounds = false

        rail.translatesAutoresizingMaskIntoConstraints = false
        rail.layer.cornerRadius = 1.5
        rail.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        rail.isUserInteractionEnabled = false
        addSubview(rail)

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
            rail.topAnchor.constraint(equalTo: topAnchor),
            rail.bottomAnchor.constraint(equalTo: bottomAnchor),
            rail.leadingAnchor.constraint(equalTo: leadingAnchor),
            rail.widthAnchor.constraint(equalToConstant: 3),

            bodyTapTarget.topAnchor.constraint(equalTo: topAnchor),
            bodyTapTarget.leadingAnchor.constraint(equalTo: leadingAnchor),
            bodyTapTarget.trailingAnchor.constraint(equalTo: trailingAnchor),
            bodyTapTarget.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: Spacing.xs),
            titleLabel.leadingAnchor.constraint(equalTo: rail.trailingAnchor, constant: Spacing.sm),

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
        // A done block fades but keeps its group rail (the spec's `opacity:0.62`).
        alpha = event.isCompleted ? 0.62 : 1.0
    }

    private func applyTheme() {
        guard let theme, let event else { return }
        // CUE — Clean: a white card with a hairline border + soft floating shadow,
        // and a GROUP-colored rail — not a solid clay fill.
        backgroundColor = theme.surface
        layer.borderColor = theme.border.cgColor
        layer.shadowColor = theme.textPrimary.cgColor
        layer.shadowRadius = theme.restShadowRadius
        layer.shadowOffset = theme.restShadowOffset
        layer.shadowOpacity = theme.restShadowOpacity
        rail.backgroundColor = CalendarColor.rail(for: event, theme: theme)
        // The completion toggle is a quiet ink mark on the white card; it flips to
        // olive (`success`) when filled, never clay.
        toggleButton.tintColor = event.isCompleted ? theme.success : theme.textSecondary

        // Ink title with strikethrough + secondary ink when completed.
        let attributes: [NSAttributedString.Key: Any] = [
            .font: theme.bodyEmphasis,
            .foregroundColor: event.isCompleted ? theme.textSecondary : theme.textPrimary,
            .strikethroughStyle: event.isCompleted ? NSUnderlineStyle.single.rawValue : 0,
            .strikethroughColor: theme.textSecondary,
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
