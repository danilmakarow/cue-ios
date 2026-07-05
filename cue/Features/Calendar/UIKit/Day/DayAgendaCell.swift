//
//  DayAgendaCell.swift
//  cue
//

import UIKit

/// The `.list`-mode agenda row — the UIKit port of `CueEventCard`. It composes the
/// shared ``DayTaskCardView`` (clean white card, 1pt hairline border, soft floating
/// shadow, plus a task-colored full-height line down the card's LEFT edge, clipped
/// to the rounded corners) and fills its ``DayTaskCardView/contentView`` with a serif
/// title (strikethrough when done), a monospaced "ledger" time range, optional
/// notes, and — for tasks — the olive completion check.
///
/// The rail names the row's GROUP (via ``CalendarColor``, clay `primary` fallback)
/// while open and flips to olive (`success`) once done, matching the Day/Today spec
/// rails — a full-height LEFT border line.
///
/// The cell stays *dumb*: it renders an ``OccurrenceVM`` and reports `onToggle` /
/// `onSelect` through closures the owning view controller sets.
final class DayAgendaCell: UICollectionViewCell {

    static let reuseIdentifier = "DayAgendaCell"

    // MARK: - Callbacks

    /// Fired when the done-check is tapped — routed to the store's completion toggle.
    var onToggle: ((OccurrenceVM) -> Void)?
    /// Fired when the card body is tapped — open task detail.
    var onSelect: ((OccurrenceVM) -> Void)?

    // MARK: - Subviews

    /// The shared floating card chrome + trailing color rail; the row's text +
    /// seal live inside its ``DayTaskCardView/contentView``.
    private let card = DayTaskCardView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let notesLabel = UILabel()
    private let textStack = UIStackView()
    private let sealButton = UIButton(type: .system)
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

    /// Builds the static hierarchy once; content + theme applied per-bind.
    private func setUp() {
        card.translatesAutoresizingMaskIntoConstraints = false
        // Roomy agenda insets on all sides (matches the old `Spacing.md` card
        // padding); the card adds the rail width to the leading inset internally.
        card.contentInsets = UIEdgeInsets(
            top: Spacing.md, left: Spacing.md, bottom: Spacing.md, right: Spacing.md
        )
        contentView.addSubview(card)

        titleLabel.numberOfLines = 0
        timeLabel.numberOfLines = 1
        notesLabel.numberOfLines = 3

        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = Spacing.xs
        textStack.alignment = .leading
        textStack.isUserInteractionEnabled = false
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(timeLabel)
        textStack.addArrangedSubview(notesLabel)

        bodyTapTarget.translatesAutoresizingMaskIntoConstraints = false
        bodyTapTarget.addTarget(self, action: #selector(handleSelect), for: .touchUpInside)
        card.contentView.addSubview(bodyTapTarget)
        card.contentView.addSubview(textStack)

        sealButton.translatesAutoresizingMaskIntoConstraints = false
        sealButton.addTarget(self, action: #selector(handleToggle), for: .touchUpInside)
        card.contentView.addSubview(sealButton)

        let content = card.contentView
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // The tap target + text fill the card's (already inset) content region.
            bodyTapTarget.topAnchor.constraint(equalTo: content.topAnchor),
            bodyTapTarget.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            bodyTapTarget.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            bodyTapTarget.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            textStack.topAnchor.constraint(equalTo: content.topAnchor),
            textStack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            textStack.leadingAnchor.constraint(equalTo: content.leadingAnchor),

            sealButton.leadingAnchor.constraint(
                greaterThanOrEqualTo: textStack.trailingAnchor, constant: Spacing.sm
            ),
            sealButton.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            // The seal rides `Spacing.xs` above the text top — preserving the old
            // layout's 4pt-higher nudge (seal was `card.top + Spacing.sm`, text was
            // `card.top + Spacing.md`) now that both hang off the inset content top.
            sealButton.topAnchor.constraint(equalTo: content.topAnchor, constant: -Spacing.xs),
            sealButton.widthAnchor.constraint(equalToConstant: 34),
            sealButton.heightAnchor.constraint(equalToConstant: 34),
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        event = nil
        onToggle = nil
        onSelect = nil
    }

    // MARK: - Configuration

    /// Binds the cell to `event` and styles it with `theme`.
    func configure(with event: OccurrenceVM, theme: CalendarTheme) {
        self.event = event
        self.theme = theme
        applyContent()
        applyTheme()
    }

    /// Re-styles with a (possibly new) theme without changing the event.
    func apply(theme: CalendarTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        applyTheme()
    }

    private func applyContent() {
        guard let event else { return }
        timeLabel.text = Self.timeRange(for: event)
        sealButton.isHidden = !event.requiresCompletion
        sealButton.accessibilityLabel = String(
            localized: event.isCompleted ? "task.toggle.markNotDone" : "task.toggle.markDone"
        )

        let trimmedNotes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedNotes, !trimmedNotes.isEmpty {
            notesLabel.text = trimmedNotes
            notesLabel.isHidden = false
        } else {
            notesLabel.text = nil
            notesLabel.isHidden = true
        }

        bodyTapTarget.accessibilityLabel = event.title
        bodyTapTarget.accessibilityIdentifier = "day.event.card"
        bodyTapTarget.accessibilityTraits = .button
        card.alpha = event.isCompleted ? 0.62 : 1
    }

    private func applyTheme() {
        guard let theme, let event else { return }
        // The rail names the row's GROUP (resolved via `CalendarColor`, falling
        // back to clay `primary` when the group is uncolored) while the task is
        // open, and flips to olive (`success`) once done — the positive earthy
        // "completed" mark, matching the Day/Today specs' group-colored rails.
        let railColor = event.isCompleted
            ? theme.success
            : CalendarColor.rail(for: event, theme: theme)
        // Clean white card fill (the agenda row is not tinted like the timeline
        // block); the shared card paints fill + border + soft floating shadow.
        card.applyChrome(theme: theme, fillColor: theme.surface, railColor: railColor)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: theme.titleM,
            .foregroundColor: theme.textPrimary,
            .strikethroughStyle: event.isCompleted ? NSUnderlineStyle.single.rawValue : 0,
        ]
        titleLabel.attributedText = NSAttributedString(string: event.title, attributes: titleAttributes)

        timeLabel.font = theme.code
        timeLabel.textColor = theme.textSecondary
        notesLabel.font = theme.callout
        notesLabel.textColor = theme.textSecondary

        applySeal()
    }

    /// Renders the completion toggle: a filled olive circle with a white check
    /// when done (the CUE — Clean `OliveCheck` done-marker), an empty bordered
    /// well when not. A flat UIKit stand-in for the SwiftUI done marker, keeping
    /// the same color roles + check glyph (done = OLIVE `success`, never clay).
    private func applySeal() {
        guard let theme, let event else { return }
        sealButton.layer.cornerRadius = 17
        sealButton.layer.borderWidth = event.isCompleted ? 0 : 1.5
        sealButton.layer.borderColor = theme.border.cgColor
        if event.isCompleted {
            sealButton.backgroundColor = theme.success
            sealButton.tintColor = theme.onAccent
            sealButton.setImage(
                UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)),
                for: .normal
            )
        } else {
            sealButton.backgroundColor = .clear
            sealButton.tintColor = .clear
            sealButton.setImage(nil, for: .normal)
        }
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

    // MARK: - Formatting

    /// Localized "9:00 AM – 10:30 AM" style range, matching `CueEventCard.timeString`.
    /// All-day occurrences read as the "all-day" label rather than a midnight range.
    private static func timeRange(for event: OccurrenceVM) -> String {
        if event.isAllDay {
            return String(localized: "newEvent.allDay")
        }
        let start = event.startAt.formatted(date: .omitted, time: .shortened)
        let end = event.endAt.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}
