//
//  DayAgendaCell.swift
//  cue
//

import UIKit

/// The `.list`-mode agenda row — the UIKit port of `CueEventCard`: a Kraft & Ink
/// paper sheet with an espresso spine, a Fraunces title (strikethrough when
/// done), a monospaced "ledger" time range, optional notes, and — for tasks —
/// the wax-seal completion toggle. Letterpress depth (1pt border + a hard 1pt
/// warm value-cut) rather than a soft float, matching `Depth.letterpress`.
///
/// The cell stays *dumb*: it renders an ``OccurrenceVM`` and reports `onToggle` /
/// `onSelect` through closures the owning view controller sets.
final class DayAgendaCell: UICollectionViewCell {

    static let reuseIdentifier = "DayAgendaCell"

    // MARK: - Callbacks

    /// Fired when the wax seal is tapped — routed to the store's completion toggle.
    var onToggle: ((OccurrenceVM) -> Void)?
    /// Fired when the card body is tapped — open task detail.
    var onSelect: ((OccurrenceVM) -> Void)?

    // MARK: - Subviews

    private let card = UIView()
    private let spine = UIView()
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
        card.layer.cornerRadius = Radius.small
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        // Hard, blur-free value-cut (radius 0, y:1) — the letterpress signature.
        card.layer.shadowRadius = 0
        card.layer.shadowOffset = CGSize(width: 0, height: 1)
        card.layer.shadowOpacity = 1
        contentView.addSubview(card)

        spine.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(spine)

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
        card.addSubview(bodyTapTarget)
        card.addSubview(textStack)

        sealButton.translatesAutoresizingMaskIntoConstraints = false
        sealButton.addTarget(self, action: #selector(handleToggle), for: .touchUpInside)
        card.addSubview(sealButton)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            spine.topAnchor.constraint(equalTo: card.topAnchor),
            spine.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            spine.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            spine.widthAnchor.constraint(equalToConstant: 4),

            bodyTapTarget.topAnchor.constraint(equalTo: card.topAnchor),
            bodyTapTarget.leadingAnchor.constraint(equalTo: spine.trailingAnchor),
            bodyTapTarget.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            bodyTapTarget.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: Spacing.md),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Spacing.md),
            textStack.leadingAnchor.constraint(equalTo: spine.trailingAnchor, constant: Spacing.md),

            sealButton.leadingAnchor.constraint(
                greaterThanOrEqualTo: textStack.trailingAnchor, constant: Spacing.sm
            ),
            sealButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Spacing.md),
            sealButton.topAnchor.constraint(equalTo: card.topAnchor, constant: Spacing.sm),
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
        bodyTapTarget.accessibilityTraits = .button
        card.alpha = event.isCompleted ? 0.62 : 1
    }

    private func applyTheme() {
        guard let theme, let event else { return }
        card.backgroundColor = theme.surface
        card.layer.borderColor = theme.border.cgColor
        card.layer.shadowColor = theme.textPrimary.withAlphaComponent(0.06).cgColor
        // The spine carries the row's state: olive (`success`) once the task is
        // sealed-done — a positive earthy "completed" mark — and espresso
        // (structural) while it's still open. Keeps olive presence in the agenda
        // without spending the rationed terracotta, which stays the seal's alone.
        spine.backgroundColor = event.isCompleted ? theme.success : theme.primary

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

    /// Renders the wax-seal toggle: a filled clay seal with a cream check when
    /// stamped, an empty bordered "seal-well" when not. A flat UIKit stand-in for
    /// the SwiftUI ``WaxSeal`` shape, keeping the same color roles + check glyph.
    private func applySeal() {
        guard let theme, let event else { return }
        sealButton.layer.cornerRadius = 17
        sealButton.layer.borderWidth = event.isCompleted ? 0 : 1.5
        sealButton.layer.borderColor = theme.border.cgColor
        if event.isCompleted {
            sealButton.backgroundColor = theme.secondary
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
    private static func timeRange(for event: OccurrenceVM) -> String {
        let start = event.startAt.formatted(date: .omitted, time: .shortened)
        let end = event.endAt.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}
