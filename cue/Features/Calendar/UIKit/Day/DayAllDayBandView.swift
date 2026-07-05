//
//  DayAllDayBandView.swift
//  cue
//

import UIKit

/// The ALL-DAY band shown ABOVE the day timeline (spec §3 "ALL-DAY"). All-day
/// occurrences have no meaningful intra-day placement, so instead of pinning them
/// at their midnight start on the timeline (the old bug), they are pulled out
/// into this band: an `ALL-DAY` eyebrow over a column of white cards, each with a
/// 3px EFFECTIVE-colored left rail (clipped to the card's rounded-left corners)
/// and a 2-line-clamped title.
///
/// The band self-sizes: ``intrinsicContentSize`` reflects the eyebrow + the
/// stacked cards, so the owning ``DayPageCell`` can lay it out above the timeline
/// scroll and hide it (zero height) when the day has no all-day items.
final class DayAllDayBandView: UIView {

    // MARK: - Callback

    /// Fired when an all-day card is tapped — open task detail.
    var onSelect: ((OccurrenceVM) -> Void)?

    // MARK: - Layout constants

    private static let eyebrowToCards: CGFloat = Spacing.sm
    private static let interCardSpacing: CGFloat = Spacing.sm
    private static let cardMinHeight: CGFloat = 30

    // MARK: - Subviews

    private let eyebrowLabel = UILabel()
    private let stack = UIStackView()

    private var events: [OccurrenceVM] = []
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

    private func setUp() {
        eyebrowLabel.text = String(localized: "calendar.allDay.eyebrow", defaultValue: "All-day").uppercased()
        eyebrowLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(eyebrowLabel)

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = Self.interCardSpacing
        stack.alignment = .fill
        addSubview(stack)

        NSLayoutConstraint.activate([
            eyebrowLabel.topAnchor.constraint(equalTo: topAnchor),
            eyebrowLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            eyebrowLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),

            stack.topAnchor.constraint(equalTo: eyebrowLabel.bottomAnchor, constant: Self.eyebrowToCards),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Configuration

    /// Binds the band to the day's all-day occurrences + theme. Rebuilds the card
    /// stack. When `events` is empty the band collapses to zero height (the owner
    /// hides it entirely).
    func configure(events: [OccurrenceVM], theme: CalendarTheme) {
        self.events = events
        self.theme = theme
        applyTheme()
        rebuildCards()
    }

    /// Re-styles the band + cards without changing the events.
    func apply(theme: CalendarTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        applyTheme()
        rebuildCards()
    }

    /// True when there are all-day events to show (the owner uses this to size the
    /// band's presence in the page layout).
    var hasContent: Bool { !events.isEmpty }

    private func applyTheme() {
        guard let theme else { return }
        eyebrowLabel.font = theme.codeSmall
        eyebrowLabel.textColor = theme.textSecondary
    }

    private func rebuildCards() {
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        guard let theme else { return }
        for event in events {
            let card = DayAllDayCardView()
            card.configure(with: event, theme: theme)
            card.onSelect = { [weak self] event in self?.onSelect?(event) }
            NSLayoutConstraint.activate([
                card.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.cardMinHeight),
            ])
            stack.addArrangedSubview(card)
        }
    }
}

/// One all-day card in the ``DayAllDayBandView``: a white card lifted by a 1px
/// border + soft floating shadow, with a 3px effective-colored left rail clipped
/// to the card's rounded-left corners and a 2-line-clamped title.
final class DayAllDayCardView: UIControl {

    var onSelect: ((OccurrenceVM) -> Void)?

    private static let railWidth: CGFloat = 3

    private let rail = UIView()
    private let titleLabel = UILabel()
    private var event: OccurrenceVM?
    private var theme: CalendarTheme?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = Radius.card
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        clipsToBounds = false
        addTarget(self, action: #selector(handleSelect), for: .touchUpInside)

        rail.translatesAutoresizingMaskIntoConstraints = false
        rail.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        rail.layer.cornerCurve = .continuous
        rail.isUserInteractionEnabled = false
        addSubview(rail)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            rail.leadingAnchor.constraint(equalTo: leadingAnchor),
            rail.topAnchor.constraint(equalTo: topAnchor),
            rail.bottomAnchor.constraint(equalTo: bottomAnchor),
            rail.widthAnchor.constraint(equalToConstant: Self.railWidth),

            // Content padding per spec: 4.5px top/bottom, 12px trailing, 15px
            // leading (12 past the 3px rail).
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4.5),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4.5),
            titleLabel.leadingAnchor.constraint(equalTo: rail.trailingAnchor, constant: Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Spacing.md),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rail.layer.cornerRadius = min(Radius.card, bounds.height / 2)
        // Explicit shadow path (rounded rect matching the card) to avoid the
        // offscreen render pass a path-less soft shadow would incur.
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: Radius.card).cgPath
    }

    func configure(with event: OccurrenceVM, theme: CalendarTheme) {
        self.event = event
        self.theme = theme
        let effectiveColor = CalendarColor.rail(for: event, theme: theme)
        backgroundColor = theme.surface
        layer.borderColor = theme.border.cgColor
        layer.shadowColor = theme.textPrimary.cgColor
        layer.shadowRadius = theme.restShadowRadius
        layer.shadowOffset = theme.restShadowOffset
        layer.shadowOpacity = theme.restShadowOpacity
        rail.backgroundColor = effectiveColor

        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.semibold(theme.caption),
            .foregroundColor: event.isCompleted ? theme.textSecondary : theme.textPrimary,
            .strikethroughStyle: event.isCompleted ? NSUnderlineStyle.single.rawValue : 0,
            .strikethroughColor: theme.textSecondary,
        ]
        titleLabel.attributedText = NSAttributedString(string: event.title, attributes: attributes)
        alpha = event.isCompleted ? 0.62 : 1.0

        accessibilityLabel = event.title
        accessibilityIdentifier = "day.event.card"
        accessibilityTraits = .button
        isAccessibilityElement = true
    }

    /// A semibold variant of `font` for the 14/600 all-day title, preserving the
    /// role's point size + Dynamic Type scaling.
    private static func semibold(_ font: UIFont) -> UIFont {
        let descriptor = font.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold]
        ])
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    @objc private func handleSelect() {
        guard let event else { return }
        onSelect?(event)
    }
}
