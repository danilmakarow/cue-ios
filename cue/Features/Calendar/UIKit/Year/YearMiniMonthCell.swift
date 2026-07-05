//
//  YearMiniMonthCell.swift
//  cue
//

import UIKit

/// Miniature month inside the year grid: the abbreviated month name above a tiny
/// 7-column day-number **heatmap** grid — the UIKit port of the CUE — Clean
/// `MiniMonth` design. Each day cell is tinted by that day's task load on a clay
/// opacity ramp (see ``MiniMonthHeatmap``); the today cell overrides its heatmap
/// fill with an inset olive ring and olive number, and the current-month
/// abbreviation turns olive.
///
/// The day numbers + heatmap tints are drawn in a single `draw(_:)` pass (one
/// ``MiniMonthGridView``) rather than ~37 laid-out subviews, because a year
/// section realizes twelve of these at once mid-scroll — the same performance
/// reason the SwiftUI version used a `Canvas`. All strings arrive pre-formatted
/// from ``MonthGridModel`` and the per-day counts arrive resolved from the owning
/// scope, so the cell does no date math, no formatting, and no store access.
///
/// Named `YearMiniMonthCell` (not `YearMonthCell`) so it coexists with the
/// still-present SwiftUI `YearMonthCell` until Integration removes the old surface
/// — the file-system-synchronized target requires distinct file names.
final class YearMiniMonthCell: UICollectionViewCell {

    static let reuseIdentifier = "YearMiniMonthCell"

    // MARK: - Views

    private let nameLabel = UILabel()
    private let weekdayHeader = MiniMonthWeekdayHeaderView()
    private let gridView = MiniMonthGridView()
    private let stack = UIStackView()

    private var theme: CalendarTheme?
    /// True when today falls in the configured month — drives the title tint.
    private var isCurrentMonth = false

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Builds the static view tree: a top-aligned vertical stack of the month
    /// name, the `M T W T F S S` weekday header, and the day-number heatmap
    /// mini-grid.
    private func setUp() {
        contentView.clipsToBounds = true

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.setContentHuggingPriority(.required, for: .vertical)

        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(nameLabel)
        stack.addArrangedSubview(weekdayHeader)
        stack.addArrangedSubview(gridView)
        // Tighten the gap between the weekday header and the day grid (the design's
        // header sits close above the grid), while keeping the name→header gap.
        stack.setCustomSpacing(Spacing.xxs, after: weekdayHeader)
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.sm),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.sm),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.sm),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -Spacing.sm),
        ])
    }

    // MARK: - Configuration

    /// Binds the cell to one month. `model` supplies the pre-formatted name and
    /// day-number cells; `countsByDay` supplies the per-day task load keyed by
    /// `startOfDay` (absent ⇒ 0) that drives the heatmap tint; `todayKey` is
    /// today's `startOfDay` when today falls in this month (else nil), which both
    /// applies the today inset-ring override and flags the title as the current
    /// month (olive).
    func configure(
        model: MonthGridModel,
        countsByDay: [Date: Int],
        todayKey: Date?,
        theme: CalendarTheme
    ) {
        self.theme = theme
        isCurrentMonth = todayKey != nil
        nameLabel.text = model.nameAbbreviated
        applyNameStyle(theme: theme)
        weekdayHeader.configure(theme: theme)
        gridView.configure(
            model: model,
            countsByDay: countsByDay,
            todayKey: todayKey,
            colors: MiniMonthHeatmap.Colors(theme: theme),
            font: theme.codeSmall
        )
        applyAccessibility(name: model.nameAbbreviated)
    }

    /// Re-styles the cell in place when only the theme changed (no content change).
    func apply(theme: CalendarTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        applyNameStyle(theme: theme)
        weekdayHeader.configure(theme: theme)
        gridView.restyle(colors: MiniMonthHeatmap.Colors(theme: theme), font: theme.codeSmall)
    }

    // MARK: - Styling

    /// The month name turns success olive for the current month (CUE — Clean),
    /// else `textPrimary` — mirroring the design's olive current-month abbreviation.
    private func applyNameStyle(theme: CalendarTheme) {
        nameLabel.font = theme.label
        nameLabel.textColor = isCurrentMonth ? theme.success : theme.textPrimary
    }

    // MARK: - Accessibility

    private func applyAccessibility(name: String) {
        isAccessibilityElement = true
        accessibilityTraits = .button
        var label = name
        if isCurrentMonth { label += ", " + String(localized: "calendar.chrome.today") }
        accessibilityLabel = label
    }
}

// MARK: - Mini-month weekday header

/// The `M T W T F S S` weekday-symbol header row above a mini-month's day grid —
/// the UIKit port of the CUE — Clean `MiniMonth` weekday header (body sans
/// 10/600/0.3, `--text-tertiary`). Seven locale-ordered, equally-spaced centered
/// labels so each sits over its day column.
///
/// Kept as a light `UIStackView`-backed view (no `draw(_:)`) because it is static
/// per month and cheap; the perf-sensitive part (the day numbers + heatmap tints)
/// stays in the single-pass ``MiniMonthGridView``.
final class MiniMonthWeekdayHeaderView: UIView {

    /// Design's `--text-tertiary` `#9C9893`, computed locally since ``CalendarTheme``
    /// exposes no tertiary token (mirrors the same local fallback in Month cells).
    private static let tertiary = UIColor(
        red: 0x9C / 255, green: 0x98 / 255, blue: 0x93 / 255, alpha: 1
    )

    private let stack = UIStackView()
    private var symbolLabels: [UILabel] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        setContentHuggingPriority(.required, for: .vertical)

        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        buildSymbols()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Builds the seven locale-ordered weekday-symbol labels once (identity is
    /// stable per locale; the labels are only re-styled on theme change).
    private func buildSymbols() {
        for symbol in CalendarMath.orderedWeekdaySymbols() {
            let label = UILabel()
            label.text = symbol.uppercased()
            label.textAlignment = .center
            symbolLabels.append(label)
            stack.addArrangedSubview(label)
        }
    }

    /// Applies the design's weekday typography: system-sans semibold shrunk to the
    /// mini-month's 10pt header size (kept Dynamic-Type-scaled via the theme's
    /// `bodyEmphasis` token), tinted `--text-tertiary`.
    func configure(theme: CalendarTheme) {
        let font = theme.bodyEmphasis.withSize(10)
        for label in symbolLabels {
            label.font = font
            label.textColor = Self.tertiary
        }
    }
}

// MARK: - Heatmap ramp

/// The near-black opacity ramp that tints a mini-month day cell by its task load,
/// per the CUE — Clean `Calendar Year` heatmap spec. Kept as a small value type so
/// the tier math is testable and shared by the grid draw pass. (Clay retired as the
/// brand color — the load ramp is now a neutral near-black intensity: light gray at
/// low tiers → near-black at high tiers.)
///
/// Tiers (daily count → near-black opacity):
/// - `0` → transparent (no fill),
/// - `1–2` → surface-sunken (`#F0EEEB`),
/// - `3–4` → ink at 0.22,
/// - `5–6` → ink at 0.45,
/// - `7+` → ink at 0.72.
///
/// The day-number text flips to white (`onAccent`) at tier ≥ 3 (count ≥ 5),
/// where the ink wash is dark enough to need the light-on-dark contrast.
enum MiniMonthHeatmap {

    /// Near-black `#1A1A1A` in rgb — the neutral load-intensity ramp (clay retired).
    private static let inkRed: CGFloat = 26 / 255
    private static let inkGreen: CGFloat = 26 / 255
    private static let inkBlue: CGFloat = 26 / 255

    /// Resolved colours the draw pass needs, derived once per theme so the pass is
    /// self-contained (mirroring why the SwiftUI `Canvas` took resolved colours).
    struct Colors: Equatable {
        let dayText: UIColor
        let onAccentText: UIColor
        let today: UIColor
        let surfaceSunken: UIColor

        init(theme: CalendarTheme) {
            dayText = theme.textPrimary
            onAccentText = theme.onAccent
            today = theme.success
            surfaceSunken = theme.surfaceSunken
        }
    }

    /// The fill colour for a day with `count` tasks, or nil for count 0
    /// (transparent). `surfaceSunken` is passed rather than hard-coded so the tint
    /// tracks the active theme's neutral fill. Tier boundaries per CUE — Clean
    /// `Calendar Year` §5: `1–2` neutral, `3–4` → 0.22, `5–6` → 0.45, `7+` → 0.72.
    static func fill(for count: Int, surfaceSunken: UIColor) -> UIColor? {
        switch count {
        case ..<1: return nil
        case 1...2: return surfaceSunken
        case 3...4: return ink(alpha: 0.22)
        case 5...6: return ink(alpha: 0.45)
        default: return ink(alpha: 0.72)
        }
    }

    /// True when a day's `count` places it in a dark-enough tier (≥ 3, i.e.
    /// count ≥ 5 where the ink wash reaches 0.45+) that its number should render
    /// white for contrast.
    static func usesLightText(for count: Int) -> Bool {
        count >= 5
    }

    /// Near-black `#1A1A1A` at the given alpha — the neutral load-intensity ramp.
    private static func ink(alpha: CGFloat) -> UIColor {
        UIColor(red: inkRed, green: inkGreen, blue: inkBlue, alpha: alpha)
    }
}

// MARK: - Mini-month grid

/// A compact 7-column day-number **heatmap** grid drawn in a single Core Graphics
/// pass — the UIKit port of the CUE — Clean `MiniMonth` day grid. One view (and one
/// draw pass) regardless of the month's length, so a year section realizing twelve
/// mini-months stays cheap mid-scroll.
///
/// Each real day paints a rounded tile tinted by its task load (``MiniMonthHeatmap``)
/// with the day number centered on top; the today cell overrides its heatmap fill
/// with an inset olive ring and an olive number.
///
/// Theme colours, the per-day counts, and the day font arrive as values (rather
/// than read live) so the draw pass is self-contained, mirroring why the SwiftUI
/// `Canvas` took resolved colours rather than reading `@Environment`.
final class MiniMonthGridView: UIView {

    /// Height of one mini-grid row, matching the CUE — Clean mini-month day cell.
    private static let rowHeight: CGFloat = 13
    /// Always reserve six rows so every mini-month is the same height regardless of
    /// its real row count — keeps the year sections uniform.
    private static let fixedRowCount = 6
    /// Corner radius of a day heatmap tile.
    private static let tileCornerRadius: CGFloat = 3
    /// Inset of a heatmap tile inside its column/row cell, so adjacent tiles have a
    /// small gap (mirrors the design's `gap:3px` day grid).
    private static let tileInset: CGFloat = 1.5
    /// Width of the today inset ring stroke.
    private static let todayRingWidth: CGFloat = 1.5

    private var cells: [MonthGridModel.Day?] = []
    private var counts: [Date: Int] = [:]
    private var todayKey: Date?
    private var colors = FallbackColors.value
    private var dayFont: UIFont = .monospacedDigitSystemFont(ofSize: 8, weight: .regular)

    /// Safe defaults before the first `configure` (e.g. a reused cell pre-bind).
    private enum FallbackColors {
        static let value = ResolvedColors(
            dayText: .label,
            onAccentText: .white,
            today: .tintColor,
            surfaceSunken: .secondarySystemFill
        )
    }

    /// The colour set the draw pass reads — a flattened copy of
    /// ``MiniMonthHeatmap/Colors`` so this view has no coupling to the theme type
    /// beyond the value it's handed.
    private struct ResolvedColors: Equatable {
        let dayText: UIColor
        let onAccentText: UIColor
        let today: UIColor
        let surfaceSunken: UIColor
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: CGFloat(Self.fixedRowCount) * Self.rowHeight)
    }

    /// Binds the grid to a month's cells + per-day counts and redraws.
    func configure(
        model: MonthGridModel,
        countsByDay: [Date: Int],
        todayKey: Date?,
        colors: MiniMonthHeatmap.Colors,
        font: UIFont
    ) {
        cells = model.cells
        counts = countsByDay
        self.todayKey = todayKey
        self.colors = ResolvedColors(
            dayText: colors.dayText,
            onAccentText: colors.onAccentText,
            today: colors.today,
            surfaceSunken: colors.surfaceSunken
        )
        // Shrink the configured font to the mini-grid's tiny size while keeping its
        // Dynamic-Type scaling and monospaced digits.
        dayFont = font.withSize(8)
        setNeedsDisplay()
    }

    /// Re-applies colours/font on a theme change without rebinding the month.
    func restyle(colors: MiniMonthHeatmap.Colors, font: UIFont) {
        self.colors = ResolvedColors(
            dayText: colors.dayText,
            onAccentText: colors.onAccentText,
            today: colors.today,
            surfaceSunken: colors.surfaceSunken
        )
        dayFont = font.withSize(8)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard !cells.isEmpty else { return }
        let columnWidth = bounds.width / 7
        for (index, cell) in cells.enumerated() {
            guard let day = cell else { continue }
            let column = index % 7
            let row = index / 7
            let cellRect = CGRect(
                x: CGFloat(column) * columnWidth,
                y: CGFloat(row) * Self.rowHeight,
                width: columnWidth,
                height: Self.rowHeight
            )
            let count = counts[day.date] ?? 0
            draw(day: day, in: cellRect, count: count, isToday: day.date == todayKey)
        }
    }

    /// Draws one day: a heatmap-tinted rounded tile (or the today inset ring
    /// override) with the centered day number on top.
    private func draw(day: MonthGridModel.Day, in cellRect: CGRect, count: Int, isToday: Bool) {
        let tileRect = cellRect.insetBy(dx: Self.tileInset, dy: Self.tileInset)

        if isToday {
            drawTodayRing(in: tileRect)
        } else if let fill = MiniMonthHeatmap.fill(for: count, surfaceSunken: colors.surfaceSunken) {
            let tile = UIBezierPath(roundedRect: tileRect, cornerRadius: Self.tileCornerRadius)
            fill.setFill()
            tile.fill()
        }

        let textColor = numberColor(count: count, isToday: isToday)
        draw(number: day.number, centeredIn: cellRect, color: textColor)
    }

    /// Draws the today cell's inset olive ring, overriding any heatmap fill (per
    /// the CUE — Clean `box-shadow: inset 0 0 0 1.5px --success`).
    private func drawTodayRing(in tileRect: CGRect) {
        let inset = Self.todayRingWidth / 2
        let ringRect = tileRect.insetBy(dx: inset, dy: inset)
        let ring = UIBezierPath(roundedRect: ringRect, cornerRadius: Self.tileCornerRadius - inset)
        ring.lineWidth = Self.todayRingWidth
        colors.today.setStroke()
        ring.stroke()
    }

    /// The day-number colour: olive for today, white for a dark heatmap tier
    /// (count ≥ 5), else the neutral day text.
    private func numberColor(count: Int, isToday: Bool) -> UIColor {
        if isToday { return colors.today }
        return MiniMonthHeatmap.usesLightText(for: count) ? colors.onAccentText : colors.dayText
    }

    /// Draws a day number centered in `cellRect`.
    private func draw(number: String, centeredIn cellRect: CGRect, color: UIColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: dayFont,
            .foregroundColor: color,
        ]
        let text = number as NSString
        let size = text.size(withAttributes: attributes)
        let origin = CGPoint(
            x: cellRect.midX - size.width / 2,
            y: cellRect.midY - size.height / 2
        )
        text.draw(at: origin, withAttributes: attributes)
    }
}

// MARK: - Year-title supplementary

/// The per-section year title (e.g. "2026") drawn as a large system-sans heading
/// over a short accent underline — matching the CUE — Clean `Calendar Year` design,
/// where the large in-scroll year heading uses the body (system-sans) face at
/// 34/600 (serif is reserved for the tiny top inline-nav title only).
///
/// The current year is emphasised in success olive (heading + underline); off-years
/// use `textPrimary` text over a clay `secondary` underline. Configured by the
/// owning ``YearScopeViewController`` with the pre-formatted year string, the
/// current-year flag, and theme.
final class YearTitleHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "YearTitleHeaderView"

    private let titleLabel = UILabel()
    private let underline = UIView()
    private var theme: CalendarTheme?

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        underline.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        addSubview(underline)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: YearLayout.horizontalInset),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -YearLayout.horizontalInset),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),

            underline.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            underline.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Spacing.xs),
            underline.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Spacing.sm),
            underline.widthAnchor.constraint(equalToConstant: 44),
            underline.heightAnchor.constraint(equalToConstant: 2),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Sets the year heading text, current-year flag, and theme. The heading uses
    /// the system-sans `titleLSans` face scaled up to the design's 34pt display size
    /// (serif is reserved for the inline-nav title only). When `isCurrentYear`, the
    /// heading and underline are tinted success olive; otherwise the heading is
    /// `textPrimary` over a clay `secondary` underline capsule.
    func configure(title: String, isCurrentYear: Bool, theme: CalendarTheme) {
        self.theme = theme
        titleLabel.text = title
        // System-sans (SF Pro) semibold at the design's 34pt display size, derived
        // from the theme's sans display token so Dynamic-Type scaling is preserved.
        titleLabel.font = theme.titleLSans.withSize(34)
        titleLabel.textColor = isCurrentYear ? theme.success : theme.textPrimary
        underline.backgroundColor = isCurrentYear ? theme.success : theme.secondary
        underline.layer.cornerRadius = 1
    }
}
