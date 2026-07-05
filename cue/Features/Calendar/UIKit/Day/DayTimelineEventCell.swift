//
//  DayTimelineEventCell.swift
//  cue
//

import UIKit

/// A single event block on the day timeline — the CUE — Clean port of the spec's
/// timeline task block. It composes the shared ``DayTaskCardView`` (rounded card,
/// 1pt border, soft floating shadow, `clipsToBounds = false`, plus a task-colored
/// full-height line down the card's LEFT edge, clipped to the rounded corners), and
/// fills the card's ``DayTaskCardView/contentView`` with its own content: an ink title,
/// a faint mono DURATION pinned top-right (effective color @0.62), an optional
/// description, and optional strikethrough + fade when completed.
///
/// The effective task color (task ?? group ?? gray, resolved via ``CalendarColor``)
/// is the rail color; a very light tint of it fills the card.
///
/// **Smart content** (the key rule): the block's height maps to the event's
/// duration (via ``DayTimelineLayout``), so a short event is a short tile. This
/// cell makes the content smart *within* that rendered height:
/// - `descAvail = renderedHeight − 27`; `descLines = clamp(floor(descAvail/16), 0, 5)`.
/// - the description shows ONLY when it exists AND `descLines ≥ 1` — otherwise it
///   is shed (title always survives, single-line with ellipsis).
/// - when only a partial title line fits (title-only and the container is
///   shorter than one full title line), a bottom fade mask fades the text out
///   rather than hard-clipping it.
///
/// This fixes the bug where a full 2-line description spilled past a short tile
/// after the event had ended.
///
/// The cell stays *dumb*: it renders an ``OccurrenceVM`` and reports the
/// `onSelect` intent through a closure the owning view controller sets. (`onToggle`
/// is retained on the type so callers compile unchanged, but the block no longer
/// hosts a toggle — completion is toggled from the agenda/detail surfaces.)
final class DayTimelineEventCell: UIView {

    // MARK: - Callbacks

    /// Retained for caller compatibility; the timeline block no longer hosts an
    /// in-block toggle (completion is conveyed by strikethrough + fade), so this
    /// is never fired from here.
    var onToggle: ((OccurrenceVM) -> Void)?
    /// Fired when the card body is tapped — open task detail.
    var onSelect: ((OccurrenceVM) -> Void)?

    // MARK: - Layout constants

    /// Vertical + horizontal content insets inside the card. The card adds the rail
    /// width to the LEADING inset internally, so the text clears the left rail.
    private static let contentTop: CGFloat = 5
    private static let contentBottom: CGFloat = 5
    private static let contentLeading: CGFloat = Spacing.sm
    private static let contentTrailing: CGFloat = Spacing.sm
    /// Per-line height budget used by the smart-content descLines formula.
    private static let descLineHeight: CGFloat = 16
    /// Fixed overhead (title row + paddings) subtracted before dividing the
    /// remaining height into description lines.
    private static let descOverhead: CGFloat = 27
    private static let maxDescLines: Int = 5

    // MARK: - Subviews

    /// The shared floating card chrome + trailing color rail. The timeline block's
    /// text lives inside its ``DayTaskCardView/contentView``.
    private let card = DayTaskCardView()
    /// Holds title + duration + description; carries the bottom fade mask when the
    /// tile is title-only and cramped. Sits inside `card.contentView`.
    private let contentContainer = UIView()
    private let titleLabel = UILabel()
    /// Faint mono DURATION (e.g. "1h", "45m") pinned top-right on the title's
    /// baseline, in the effective color at 0.62 opacity.
    private let durationLabel = UILabel()
    /// Optional description (the occurrence's notes), shed before the title when
    /// the tile is too short.
    private let descriptionLabel = UILabel()
    private let bodyTapTarget = UIControl()
    /// The bottom fade mask applied to `contentContainer` when title-only + cramped.
    private let fadeMaskLayer = CAGradientLayer()

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
        // The shared card fills this cell's bounds (the cell is framed by
        // `DayTimelineDayView`); it renders all chrome + the trailing rail.
        card.translatesAutoresizingMaskIntoConstraints = false
        // Dense timeline insets (top/bottom 5, leading/trailing `Spacing.sm`);
        // the card adds the rail width to the leading inset internally.
        card.contentInsets = UIEdgeInsets(
            top: Self.contentTop, left: Self.contentLeading,
            bottom: Self.contentBottom, right: Self.contentTrailing
        )
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        // Full-card tap target: a direct subview of the cell (framed to full
        // bounds in `layoutSubviews`) so the whole tile — including the rail strip
        // and insets — opens task detail, matching the pre-refactor behavior.
        bodyTapTarget.addTarget(self, action: #selector(handleSelect), for: .touchUpInside)
        addSubview(bodyTapTarget)

        contentContainer.isUserInteractionEnabled = false
        // The container is clipped so a description that is longer than its
        // allotted lines hard-clips at the container edge (the fade mask then
        // softens the title-only cramped case).
        contentContainer.clipsToBounds = true
        card.contentView.addSubview(contentContainer)

        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentContainer.addSubview(titleLabel)

        durationLabel.numberOfLines = 1
        durationLabel.textAlignment = .right
        durationLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        durationLabel.setContentHuggingPriority(.required, for: .horizontal)
        contentContainer.addSubview(durationLabel)

        descriptionLabel.numberOfLines = 0
        descriptionLabel.lineBreakMode = .byTruncatingTail
        contentContainer.addSubview(descriptionLabel)

        // Bottom fade: opaque from 0 → ~36%, fading to transparent by ~95%.
        fadeMaskLayer.colors = [
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.clear.cgColor,
        ]
        fadeMaskLayer.locations = [0, 0.36, 0.95]
        fadeMaskLayer.startPoint = CGPoint(x: 0.5, y: 0)
        fadeMaskLayer.endPoint = CGPoint(x: 0.5, y: 1)
    }

    // MARK: - Configuration

    /// Binds the cell to `event` and styles it with `theme`. Idempotent — safe to
    /// call on reuse.
    func configure(with event: OccurrenceVM, theme: CalendarTheme) {
        self.event = event
        self.theme = theme
        applyContent()
        applyTheme()
        setNeedsLayout()
    }

    /// Re-styles the cell with a (possibly new) theme without changing its event.
    func apply(theme: CalendarTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        applyTheme()
        setNeedsLayout()
    }

    private func applyContent() {
        guard let event else { return }
        bodyTapTarget.accessibilityLabel = event.title
        bodyTapTarget.accessibilityIdentifier = "day.event.card"
        bodyTapTarget.accessibilityTraits = .button
        // A done block fades but keeps its rail (the spec's `opacity:0.62`).
        alpha = event.isCompleted ? 0.62 : 1.0
    }

    private func applyTheme() {
        guard let theme, let event else { return }
        let effectiveColor = CalendarColor.rail(for: event, theme: theme)
        // Fill: a VERY LIGHT shade of the effective color — flatten it onto white
        // at alpha 0.10, computed locally (never a hardcoded hex). The shared card
        // paints the fill + border + shadow + trailing rail.
        let fillColor = Self.tint(effectiveColor, onto: theme.surface, alpha: 0.10)
        card.applyChrome(theme: theme, fillColor: fillColor, railColor: effectiveColor)

        // Ink title: the timeline block title is 13px SEMIBOLD (heavier than the
        // 13px-medium `theme.label`) for clear emphasis against the description.
        // Set `font` too (not just the attributed run) so `titleLabel.font`
        // reports the right metrics for the baseline math in `layoutSubviews`.
        titleLabel.font = Self.semibold(theme.label)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.semibold(theme.label),
            .foregroundColor: event.isCompleted ? theme.textSecondary : theme.textPrimary,
            .strikethroughStyle: event.isCompleted ? NSUnderlineStyle.single.rawValue : 0,
            .strikethroughColor: theme.textSecondary,
        ]
        titleLabel.attributedText = NSAttributedString(string: event.title, attributes: attributes)

        // Faint mono DURATION in the effective color @0.62, pinned to the title.
        durationLabel.font = theme.codeSmall
        durationLabel.textColor = effectiveColor.withAlphaComponent(0.62)
        durationLabel.text = Self.durationText(for: event)

        // Description in secondary ink; visibility/line-count decided in layout.
        descriptionLabel.font = theme.caption
        descriptionLabel.textColor = theme.textSecondary
        descriptionLabel.text = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Layout (smart content)

    override func layoutSubviews() {
        super.layoutSubviews()
        let renderedHeight = bounds.height
        // The shared card owns the chrome/shadow/rail and frames its `contentView`
        // (inset past the trailing rail) in its own layout pass. Settle the card's
        // own layout first so `contentView.bounds` is FINAL for this pass (the cell
        // is framed by its parent, so the card's Auto Layout may not have run yet),
        // then lay the text out relative to that content region.
        card.layoutIfNeeded()
        let contentContainerBounds = card.contentView.bounds
        let contentWidth = contentContainerBounds.width

        // The tap target covers the FULL tile (rail + insets); the text container
        // fills the card's inset content region.
        bodyTapTarget.frame = bounds
        let containerHeight = contentContainerBounds.height
        contentContainer.frame = contentContainerBounds

        // Smart content: decide description lines from the RENDERED height.
        let descAvailable = renderedHeight - Self.descOverhead
        let rawDescLines = descAvailable > 0 ? Int((descAvailable / Self.descLineHeight).rounded(.down)) : 0
        let descLines = min(max(rawDescLines, 0), Self.maxDescLines)
        let hasNotes = !(descriptionLabel.text ?? "").isEmpty
        let showDescription = hasNotes && descLines >= 1

        // Title row: [title (flex) | duration (hugs)] on a shared baseline.
        let durationSize = durationLabel.intrinsicContentSize
        let durationWidth = min(durationSize.width, contentWidth)
        let titleHeight = titleLabel.intrinsicContentSize.height
        let titleWidth = max(contentWidth - durationWidth - Spacing.xs, 0)
        titleLabel.frame = CGRect(x: 0, y: 0, width: titleWidth, height: titleHeight)
        durationLabel.frame = CGRect(
            x: contentWidth - durationWidth,
            y: max(titleLabel.font.ascender - durationLabel.font.ascender, 0),
            width: durationWidth,
            height: durationSize.height
        )

        // Description under the title row, clamped to the computed line count.
        descriptionLabel.isHidden = !showDescription
        if showDescription {
            descriptionLabel.numberOfLines = descLines
            let descY = titleHeight + 3
            let descHeight = max(containerHeight - descY, 0)
            descriptionLabel.frame = CGRect(x: 0, y: descY, width: contentWidth, height: descHeight)
        }

        // Bottom fade mask when the title-only content is actually CLIPPED by a
        // short tile — fade the last (partial) line out toward the bottom edge
        // rather than hard-clipping it. Driven by REAL GEOMETRY, not a magic
        // height constant: `ceil(lineHeight)` is the height one full title line
        // needs; when `containerHeight` is shorter than that, the line is clipped
        // → fade. The layout floors the shortest tiles to ~18pt (see
        // ``DayTimelineLayout/minimumEventHeight``), so 15–30 min tiles are
        // genuinely cramped and this branch fires.
        let titleLineHeight = ceil(titleLabel.font.lineHeight)
        let contentClipped = !showDescription && containerHeight < titleLineHeight
        if contentClipped {
            // Match the mask to the CONTENT bounds so the fade tracks the actual
            // clipped area (updated here every layout pass alongside the frame).
            fadeMaskLayer.frame = contentContainer.bounds
            contentContainer.layer.mask = fadeMaskLayer
        } else {
            contentContainer.layer.mask = nil
        }
    }

    // MARK: - Color helpers

    /// Flattens `color` onto `base` at `alpha` — the "very light tint" of a task
    /// color used for the tile fill (equivalent to painting `color@alpha` over an
    /// opaque `base`). Computed locally so no shared color file is touched.
    private static func tint(_ color: UIColor, onto base: UIColor, alpha: CGFloat) -> UIColor {
        var foregroundRed: CGFloat = 0, foregroundGreen: CGFloat = 0, foregroundBlue: CGFloat = 0, foregroundAlpha: CGFloat = 0
        var baseRed: CGFloat = 0, baseGreen: CGFloat = 0, baseBlue: CGFloat = 0, baseAlpha: CGFloat = 0
        guard
            color.getRed(&foregroundRed, green: &foregroundGreen, blue: &foregroundBlue, alpha: &foregroundAlpha),
            base.getRed(&baseRed, green: &baseGreen, blue: &baseBlue, alpha: &baseAlpha)
        else {
            return base
        }
        let mix = { (foreground: CGFloat, background: CGFloat) -> CGFloat in
            foreground * alpha + background * (1 - alpha)
        }
        return UIColor(
            red: mix(foregroundRed, baseRed),
            green: mix(foregroundGreen, baseGreen),
            blue: mix(foregroundBlue, baseBlue),
            alpha: 1
        )
    }

    /// Returns a semibold-weight variant of `font`, preserving its point size and
    /// Dynamic Type scaling. Used to render the 13px-semibold timeline block title
    /// without adding a new role to the frozen `CalendarTheme`.
    private static func semibold(_ font: UIFont) -> UIFont {
        let descriptor = font.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold]
        ])
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    /// Compact duration label for the block's top-right ("1h", "45m", "1h 30m");
    /// all-day reads as the all-day label rather than a clock duration.
    private static func durationText(for event: OccurrenceVM) -> String {
        if event.isAllDay {
            return String(localized: "newEvent.allDay")
        }
        let totalMinutes = max(0, Int(event.endAt.timeIntervalSince(event.startAt) / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 {
            return String(
                format: String(localized: "calendar.duration.hoursMinutes", defaultValue: "%dh %dm"),
                hours, minutes
            )
        }
        if hours > 0 {
            return String(format: String(localized: "calendar.duration.hours", defaultValue: "%dh"), hours)
        }
        return String(format: String(localized: "calendar.duration.minutes", defaultValue: "%dm"), minutes)
    }

    // MARK: - Actions

    @objc private func handleSelect() {
        guard let event else { return }
        onSelect?(event)
    }
}
