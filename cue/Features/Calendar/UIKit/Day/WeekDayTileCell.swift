//
//  WeekDayTileCell.swift
//  cue
//

import UIKit

/// One day tile in the week strip — the UIKit port of the old inline
/// `DatePillCell`, extracted so the strip can host a separate sliding selection
/// indicator *behind* the grid (the tile itself never paints a selection fill).
///
/// Each tile stacks a day number, a weekday letter, and a fixed-height bottom
/// slot. The bottom slot now shows, in priority order: up to **3 overlapping
/// colored task bubbles** (each an 18×18 circle with a light tinted fill + the
/// task's first letter in its full-strength color, overlapping) plus a `+N`
/// overflow pill when the day has more than 3 tasks; else — for a day with no
/// bubble data but a plain count — a neutral count badge; else empty.
///
/// TODAY and SELECTED are two independent, visually distinct markers that can
/// both show on the same tile. SELECTED is the strip's sliding olive background
/// FILL pill behind this tile (this tile only recolors text). TODAY is a persistent
/// **fresh-green border** (`theme.todayAccent`) around the whole tile plus a small
/// lowercase "today" caption at the TOP — always visible regardless of events or
/// selection, and deliberately OUTSIDE the mutually-exclusive bottom slot so
/// bubbles/counts can never hide it. A day that is BOTH shows the selected fill
/// UNDER the green today border and caption, cleanly.
final class WeekDayTileCell: UICollectionViewCell {

    static let reuseIdentifier = "WeekDayTileCell"

    // MARK: - Bubble metrics

    private static let bubbleSize: CGFloat = 18
    private static let bubbleOverlap: CGFloat = 10
    private static let bubbleRingWidth: CGFloat = 1.5
    private static let maxBubbles = 3
    /// Blend ratio for the OPAQUE light bubble fill: the effective color flattened
    /// onto the strip background at this ratio, producing a solid lighter shade (NOT
    /// a translucent fill — overlapping translucent circles compounded into muddy
    /// darker patches). The letter is rendered in the SAME color at full strength for
    /// legibility on the tint.
    private static let bubbleFillRatio: CGFloat = 0.20

    // MARK: - Today-marker metrics

    /// Stroke width of the fresh-green border drawn around the whole tile for
    /// today. Distinct in both color and shape from the selected background fill.
    private static let todayBorderWidth: CGFloat = 1.5
    /// Corner radius of the today border's rounded rect — matches the sliding
    /// selection pill's 9px tile radius so the two markers nest concentrically.
    private static let todayBorderCornerRadius: CGFloat = 9
    /// Point size of the small lowercase "today" caption at the top of the tile.
    private static let todayCaptionFontSize: CGFloat = 8

    // MARK: - Subviews

    private let dayNumberLabel = UILabel()
    private let weekdayLabel = UILabel()
    private let countBadge = UILabel()
    /// The small lowercase "today" caption pinned to the TOP of the tile — shown
    /// ONLY for today, in `theme.todayAccent` green, above the number/weekday stack
    /// and independent of the bottom slot so bubbles/counts can never hide it.
    private let todayCaptionLabel = UILabel()
    /// The persistent TODAY marker: a stroked-only rounded rect matching the tile's
    /// corner radius, in the fresh-green `theme.todayAccent`. Drawn as a dedicated
    /// shape layer so the rounding derives from settled bounds and the stroke color
    /// is a real resolved `cgColor` (re-resolved on trait changes) — never a stale
    /// snapshot. Sits at the tile edge, over the selected background fill.
    private let todayBorderLayer = CAShapeLayer()
    /// The today accent color, stored as a UIColor so both the border stroke and the
    /// caption text can be re-resolved against the tile's current `traitCollection`
    /// on trait changes (a `cgColor` handed to the layer is trait-snapshotted and
    /// would otherwise go stale — the classic "renders as the fallback variant" bug).
    private var todayAccentColor: UIColor = .clear
    /// Whether this tile is today's — drives the border + caption visibility, held
    /// so `layoutSubviews` can (re)build the border path only when it is showing.
    private var isToday = false
    /// Hosts the overlapping bubble row + optional `+N` pill; laid out manually.
    private let bubbleContainer = UIView()
    private let stack = UIStackView()
    private var bubbleContainerWidth: NSLayoutConstraint?

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEEE"   // "Mo", "Tu", …
        return formatter
    }()

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
        weekdayLabel.textAlignment = .center
        dayNumberLabel.textAlignment = .center

        // The small "today" caption at the top of the tile — lowercase, tiny, green.
        // Localized with an inline default so the String Catalog isn't hand-edited.
        todayCaptionLabel.textAlignment = .center
        todayCaptionLabel.text = String(localized: "calendar.weekstrip.today", defaultValue: "today")
        todayCaptionLabel.isHidden = true

        countBadge.translatesAutoresizingMaskIntoConstraints = false
        countBadge.textAlignment = .center
        countBadge.layer.cornerCurve = .continuous
        countBadge.clipsToBounds = true

        bubbleContainer.translatesAutoresizingMaskIntoConstraints = false
        bubbleContainer.isUserInteractionEnabled = false

        // Fixed-height bottom slot holds the bubble row / count badge (only one
        // variant visible at a time). The today marker no longer lives here — it is
        // the always-visible green tile border + the top caption, both independent.
        let bottomSlot = UIView()
        bottomSlot.translatesAutoresizingMaskIntoConstraints = false
        bottomSlot.addSubview(countBadge)
        bottomSlot.addSubview(bubbleContainer)
        let bubbleWidth = bubbleContainer.widthAnchor.constraint(equalToConstant: 0)
        bubbleContainerWidth = bubbleWidth
        NSLayoutConstraint.activate([
            bottomSlot.heightAnchor.constraint(equalToConstant: Self.bubbleSize),
            countBadge.centerXAnchor.constraint(equalTo: bottomSlot.centerXAnchor),
            countBadge.centerYAnchor.constraint(equalTo: bottomSlot.centerYAnchor),
            countBadge.heightAnchor.constraint(equalToConstant: 14),
            countBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 14),
            bubbleContainer.centerXAnchor.constraint(equalTo: bottomSlot.centerXAnchor),
            bubbleContainer.centerYAnchor.constraint(equalTo: bottomSlot.centerYAnchor),
            bubbleContainer.heightAnchor.constraint(equalToConstant: Self.bubbleSize),
            bubbleWidth,
        ])

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Spacing.xxs
        stack.isUserInteractionEnabled = false
        // The "today" caption is the first (top) element; it collapses to zero
        // height when hidden (`UIStackView` removes hidden arranged subviews from
        // layout), so a non-today tile keeps the exact number/weekday/slot spacing.
        stack.addArrangedSubview(todayCaptionLabel)
        stack.addArrangedSubview(dayNumberLabel)
        stack.addArrangedSubview(weekdayLabel)
        stack.addArrangedSubview(bottomSlot)
        contentView.addSubview(stack)

        // Stroke-only shape layer for the today border: no fill, ~1.5pt green
        // stroke, hugging the whole tile as a rounded rect matching the pill radius.
        // Hosted on the content view's own layer (NOT a subview) so it sits at the
        // tile edge, over the selected background fill and under the text. Its path +
        // color are (re)computed in `layoutSubviews` / on trait changes.
        todayBorderLayer.fillColor = UIColor.clear.cgColor
        todayBorderLayer.lineWidth = Self.todayBorderWidth
        todayBorderLayer.isHidden = true
        contentView.layer.addSublayer(todayBorderLayer)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Rebuild the today border path from the settled content bounds every pass,
        // so the rounding is never computed from stale/zero geometry. Only when this
        // is today's tile — otherwise the layer stays hidden and pathless.
        guard isToday else {
            todayBorderLayer.path = nil
            return
        }
        let bounds = contentView.bounds
        guard bounds.width > 0, bounds.height > 0 else {
            todayBorderLayer.path = nil
            return
        }
        // Inset by half the stroke so the centered line sits fully INSIDE the bounds
        // (an un-inset centered stroke clips its outer half). The corner radius
        // matches the sliding selection pill so the two markers nest concentrically.
        let strokeInset = Self.todayBorderWidth / 2
        let borderRect = bounds.insetBy(dx: strokeInset, dy: strokeInset)
        // Frame + path in one implicit-animation-free transaction so the border
        // snaps to the new geometry on reuse without a stray cross-fade.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        todayBorderLayer.frame = bounds
        todayBorderLayer.path = UIBezierPath(
            roundedRect: borderRect, cornerRadius: Self.todayBorderCornerRadius
        ).cgPath
        CATransaction.commit()
    }

    /// Re-resolves the today marker's green (border stroke + caption text) against
    /// the tile's CURRENT trait collection whenever traits change, so the `cgColor`
    /// handed to the layer never lingers as a stale (e.g. dark-variant) snapshot.
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        applyResolvedTodayColor()
    }

    /// Pushes ``todayAccentColor``, resolved for the current `traitCollection`, into
    /// the border layer's `strokeColor` and the caption's `textColor`. Centralized
    /// so `configure` and trait changes share one path.
    private func applyResolvedTodayColor() {
        let resolved = todayAccentColor.resolvedColor(with: traitCollection)
        todayBorderLayer.strokeColor = resolved.cgColor
        todayCaptionLabel.textColor = resolved
    }

    // MARK: - Configuration

    /// Binds the tile to a date + state, styling with `theme`. Selection only
    /// recolors text — the selection fill is drawn by the strip's sliding
    /// indicator behind this tile. `bubbles` (when present) render the colored
    /// task-bubble row + `+N` pill; otherwise `count` renders the neutral badge.
    func configure(
        date: Date,
        count: Int?,
        bubbles: WeekDayBubbles?,
        isSelected: Bool,
        isToday: Bool,
        theme: CalendarTheme
    ) {
        // The selected tile sits under a soft olive background-fill pill, so the
        // number stays `textPrimary` (not inverted onto a solid fill).
        dayNumberLabel.text = date.formatted(.dateTime.day())
        dayNumberLabel.font = theme.titleMSans
        dayNumberLabel.textColor = theme.textPrimary

        weekdayLabel.text = Self.weekdayFormatter.string(from: date).uppercased()
        weekdayLabel.font = theme.codeSmall
        weekdayLabel.textColor = theme.textSecondary

        // TODAY = a persistent fresh-green border around the whole tile PLUS a small
        // "today" caption at the top, both independent of the bottom slot and of
        // selection — so a day that is today AND selected AND has events shows the
        // green border, the "today" caption, the selected fill, and its bubbles at
        // once. Store the accent as a UIColor (not a one-shot cgColor) so it resolves
        // against the current traits and renders as real green — not a stale fallback.
        self.isToday = isToday
        todayAccentColor = theme.todayAccent
        todayBorderLayer.isHidden = !isToday
        todayCaptionLabel.isHidden = !isToday
        todayCaptionLabel.font = Self.todayCaptionFont()
        applyResolvedTodayColor()
        // Force a border-path rebuild for the (possibly newly) today tile on reuse.
        setNeedsLayout()

        configureBottomSlot(count: count, bubbles: bubbles, theme: theme)
    }

    /// Resolves the single bottom-slot affordance in priority order: colored task
    /// bubbles (+`+N` pill) → neutral count badge → empty. The today marker is the
    /// tile's green border + top caption (set in ``configure``), never the bottom slot.
    private func configureBottomSlot(
        count: Int?,
        bubbles: WeekDayBubbles?,
        theme: CalendarTheme
    ) {
        countBadge.isHidden = true
        clearBubbles()

        if let bubbles, !bubbles.bubbles.isEmpty {
            bubbleContainer.isHidden = false
            renderBubbles(bubbles, theme: theme)
            return
        }
        bubbleContainer.isHidden = true

        if let count, count > 0 {
            // The per-day count is a neutral ledger badge — secondary ink on a
            // sunken gray chip (fallback when the owner hasn't supplied bubbles).
            countBadge.isHidden = false
            countBadge.text = count < 100 ? " \(count) " : " ••• "
            countBadge.font = theme.codeSmall
            countBadge.layer.cornerRadius = 4
            countBadge.textColor = theme.textSecondary
            countBadge.backgroundColor = theme.surfaceSunken
        }
    }

    // MARK: - Bubbles

    /// Removes any previously-rendered bubble/pill subviews.
    private func clearBubbles() {
        for view in bubbleContainer.subviews { view.removeFromSuperview() }
    }

    /// Builds up to 3 overlapping colored bubbles (each a 14×14 white-ringed circle
    /// with the task's first letter) plus a `+N` overflow pill when the day has
    /// more than 3 tasks, then sizes the container so it centers under the tile.
    private func renderBubbles(_ summary: WeekDayBubbles, theme: CalendarTheme) {
        let shown = Array(summary.bubbles.prefix(Self.maxBubbles))
        let overflow = summary.totalCount - shown.count
        let step = Self.bubbleSize - Self.bubbleOverlap
        var cursorX: CGFloat = 0

        for bubble in shown {
            let view = Self.makeBubble(bubble, theme: theme)
            view.frame = CGRect(x: cursorX, y: 0, width: Self.bubbleSize, height: Self.bubbleSize)
            bubbleContainer.addSubview(view)
            cursorX += step
        }

        var totalWidth = shown.isEmpty ? 0 : cursorX - step + Self.bubbleSize
        if overflow > 0 {
            let pill = Self.makeWeekDayOverflowPill(count: overflow, theme: theme)
            let pillWidth = max(Self.bubbleSize, pill.intrinsicWidth)
            pill.frame = CGRect(x: cursorX, y: 0, width: pillWidth, height: Self.bubbleSize)
            bubbleContainer.addSubview(pill)
            totalWidth = cursorX + pillWidth
        }
        bubbleContainerWidth?.constant = max(totalWidth, 0)
    }

    /// A single 18×18 bubble: an OPAQUE light shade of the task's effective color as
    /// the fill (`effective` flattened onto the strip background at
    /// ``bubbleFillRatio`` — solid, never translucent, so overlapping bubbles never
    /// compound into darker patches), the first letter in the SAME color at FULL
    /// strength (legible on the light fill), and a subtle background ring so overlaps
    /// read cleanly.
    private static func makeBubble(_ bubble: WeekDayBubble, theme: CalendarTheme) -> UIView {
        let effective = CalendarColor.effective(
            taskToken: bubble.colorToken, groupToken: bubble.groupColorToken
        )
        let circle = UIView(frame: CGRect(x: 0, y: 0, width: bubbleSize, height: bubbleSize))
        circle.backgroundColor = lightShade(of: effective, onto: theme.background, ratio: bubbleFillRatio)
        circle.layer.cornerRadius = bubbleSize / 2
        circle.layer.borderWidth = bubbleRingWidth
        // The subtle ring is the strip background (`theme.background`), so overlaps
        // read cleanly on any surface without hardcoding #FFFFFF.
        circle.layer.borderColor = theme.background.cgColor
        circle.isUserInteractionEnabled = false

        let letter = UILabel(frame: circle.bounds)
        letter.text = bubble.letter
        letter.textAlignment = .center
        // Full-strength effective color (not white) — legible on the light tint.
        letter.textColor = effective
        letter.font = Self.bubbleLetterFont(theme: theme)
        letter.adjustsFontSizeToFitWidth = true
        letter.minimumScaleFactor = 0.7
        circle.addSubview(letter)
        return circle
    }

    /// Flattens `color` onto the opaque `base` at `ratio`, returning a SOLID lighter
    /// shade (alpha 1) — equivalent to painting `color@ratio` over an opaque `base`,
    /// but with no residual transparency, so overlapping bubbles never darken where
    /// they cross. Computed locally so no shared color file is touched.
    private static func lightShade(of color: UIColor, onto base: UIColor, ratio: CGFloat) -> UIColor {
        var foregroundRed: CGFloat = 0, foregroundGreen: CGFloat = 0, foregroundBlue: CGFloat = 0, foregroundAlpha: CGFloat = 0
        var baseRed: CGFloat = 0, baseGreen: CGFloat = 0, baseBlue: CGFloat = 0, baseAlpha: CGFloat = 0
        guard
            color.getRed(&foregroundRed, green: &foregroundGreen, blue: &foregroundBlue, alpha: &foregroundAlpha),
            base.getRed(&baseRed, green: &baseGreen, blue: &baseBlue, alpha: &baseAlpha)
        else {
            return base
        }
        let mix = { (foreground: CGFloat, background: CGFloat) -> CGFloat in
            foreground * ratio + background * (1 - ratio)
        }
        return UIColor(
            red: mix(foregroundRed, baseRed),
            green: mix(foregroundGreen, baseGreen),
            blue: mix(foregroundBlue, baseBlue),
            alpha: 1
        )
    }

    /// The `+N` overflow pill: a sunken-gray capsule with a white ring, mono 8
    /// secondary text, tucked under the last bubble.
    private static func makeWeekDayOverflowPill(count: Int, theme: CalendarTheme) -> WeekDayOverflowPill {
        let pill = WeekDayOverflowPill(frame: CGRect(x: 0, y: 0, width: bubbleSize, height: bubbleSize))
        pill.configure(
            text: "+\(count)",
            font: Self.bubbleLetterFont(theme: theme),
            textColor: theme.textSecondary,
            fill: theme.surfaceSunken,
            ringColor: theme.background,
            ringWidth: bubbleRingWidth,
            height: bubbleSize
        )
        return pill
    }

    /// A monospaced ~8pt bold font for the bubble letters / overflow pill, scaled
    /// down from the theme's `codeSmall` mono role so it stays a monospaced glyph.
    private static func bubbleLetterFont(theme: CalendarTheme) -> UIFont {
        let base = theme.codeSmall
        let descriptor = base.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.bold]
        ])
        return UIFont(descriptor: descriptor, size: 8)
    }

    /// A small semibold sans caption font for the "today" label, Dynamic-Type
    /// scaled relative to `.caption2` so it tracks the content-size category yet
    /// stays tiny — the low-key top marker for today's tile. Derives from the system
    /// sans directly (the caption is chrome, not a themed serif/mono role).
    private static func todayCaptionFont() -> UIFont {
        let base = UIFont.systemFont(ofSize: Self.todayCaptionFontSize, weight: .semibold)
        return UIFontMetrics(forTextStyle: .caption2).scaledFont(for: base)
    }
}

/// The `+N` overflow pill for the week-strip bubble row: a pill-shaped capsule
/// that grows horizontally with its label while keeping the bubble height.
final class WeekDayOverflowPill: UIView {

    private let label = UILabel()

    /// The pill's natural width (its label width plus horizontal padding, floored
    /// to the bubble height so a single-digit `+N` stays a circle).
    var intrinsicWidth: CGFloat {
        label.sizeToFit()
        return max(bounds.height, label.bounds.width + 6)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        label.textAlignment = .center
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Styles the pill's text + capsule fill/ring.
    func configure(
        text: String,
        font: UIFont,
        textColor: UIColor,
        fill: UIColor,
        ringColor: UIColor,
        ringWidth: CGFloat,
        height: CGFloat
    ) {
        label.text = text
        label.font = font
        label.textColor = textColor
        backgroundColor = fill
        layer.cornerRadius = height / 2
        layer.borderWidth = ringWidth
        layer.borderColor = ringColor.cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
    }
}
