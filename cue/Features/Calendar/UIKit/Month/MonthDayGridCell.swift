//
//  MonthDayGridCell.swift
//  cue
//

import UIKit

/// One day in the month grid: the day number with a today/selected highlight and
/// the day's event titles listed beneath it, capped with a "+N" overflow row —
/// the UIKit port of the SwiftUI `MonthDayCell`, matching its layout (a leading
/// 24×24 number chip over a left-aligned title list).
///
/// Named `MonthDayGridCell` (not `MonthDayCell`) so it coexists with the
/// still-present SwiftUI `MonthDayCell` until Integration removes the old surface —
/// the file-system-synchronized target requires distinct file names.
///
/// Deliberately *dumb*: the owning ``MonthScopeViewController`` configures it with
/// the day number, the today/selected flags, the day's titles, and the theme. It
/// does no date math, no formatting, and no store access. It renders constantly
/// while the month list scrolls, so the configure path stays allocation-light.
final class MonthDayGridCell: UICollectionViewCell {

    static let reuseIdentifier = "MonthDayGridCell"

    /// Most title chips shown before the rest collapse into a "+N" row. Mirrors
    /// the old `MonthDayCell.maxVisibleTitles`.
    private static let maxVisibleTitles = 3

    // MARK: - Views

    /// Most event-indicator dots shown before the rest collapse — caps the row at a
    /// width the narrow day cell can hold without clipping.
    private static let maxIndicatorDots = 4
    /// The diameter of one event-indicator dot.
    private static let indicatorDotSize: CGFloat = 5

    private let numberLabel = UILabel()
    private let numberBackground = UIView()
    private let indicatorStack = UIStackView()
    private let titleStack = UIStackView()
    private let overflowLabel = UILabel()
    private let contentStack = UIStackView()

    /// Reusable title-chip labels, grown lazily and hidden when unused so the cell
    /// avoids per-configure allocation while scrolling.
    private var titleChips: [PaddedLabel] = []

    /// Reusable indicator-dot views, grown lazily and hidden when unused so the
    /// cell avoids per-configure allocation while scrolling.
    private var indicatorDots: [UIView] = []

    private var theme: CalendarTheme?

    /// Remembers the day's highlight state so a theme-only restyle can re-apply the
    /// TODAY/SELECTED chip with the new theme's colours (mirrors how
    /// ``YearMiniMonthCell`` keeps `isCurrentMonth` for its restyle path).
    private var highlightIsToday = false
    private var highlightIsSelected = false

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Builds the static view tree: a top-aligned vertical stack of the number
    /// chip, the title chips, and the overflow row.
    private func setUp() {
        contentView.clipsToBounds = true

        numberLabel.textAlignment = .center
        numberLabel.translatesAutoresizingMaskIntoConstraints = false

        numberBackground.translatesAutoresizingMaskIntoConstraints = false
        numberBackground.addSubview(numberLabel)
        // The number chip is a fixed 24×24 circle, left-aligned in its row.
        let numberRow = UIView()
        numberRow.translatesAutoresizingMaskIntoConstraints = false
        numberRow.addSubview(numberBackground)

        indicatorStack.axis = .horizontal
        indicatorStack.alignment = .center
        indicatorStack.spacing = Spacing.xxs
        indicatorStack.isHidden = true

        titleStack.axis = .vertical
        titleStack.alignment = .fill
        titleStack.spacing = Spacing.xxs

        overflowLabel.isHidden = true

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = Spacing.xxs
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(numberRow)
        contentStack.addArrangedSubview(indicatorStack)
        contentStack.addArrangedSubview(titleStack)
        contentStack.addArrangedSubview(overflowLabel)
        contentView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            numberBackground.widthAnchor.constraint(equalToConstant: 24),
            numberBackground.heightAnchor.constraint(equalToConstant: 24),
            numberBackground.leadingAnchor.constraint(equalTo: numberRow.leadingAnchor),
            numberBackground.topAnchor.constraint(equalTo: numberRow.topAnchor),
            numberBackground.bottomAnchor.constraint(equalTo: numberRow.bottomAnchor),
            numberRow.heightAnchor.constraint(equalToConstant: 24),

            numberLabel.centerXAnchor.constraint(equalTo: numberBackground.centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: numberBackground.centerYAnchor),

            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        numberBackground.layer.cornerRadius = numberBackground.bounds.height / 2
    }

    // MARK: - Configuration

    /// Binds the cell to a day. `number` arrives pre-formatted; `isToday` /
    /// `isSelected` drive the chip highlight; `titles` are listed beneath, capped
    /// with a "+N" overflow row.
    func configure(
        number: String,
        isToday: Bool,
        isSelected: Bool,
        indicatorCount: Int,
        titles: [String],
        theme: CalendarTheme
    ) {
        self.theme = theme
        highlightIsToday = isToday
        highlightIsSelected = isSelected
        numberLabel.text = number
        numberLabel.font = theme.codeSmall

        applyDayHighlight(isToday: isToday, isSelected: isSelected, theme: theme)
        applyIndicators(indicatorCount, theme: theme)
        applyTitles(titles, theme: theme)
        applyAccessibility(number: number, isToday: isToday, titles: titles)
    }

    /// Re-styles the cell in place when only the theme changed (no content change).
    func apply(theme: CalendarTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        numberLabel.font = theme.codeSmall
        applyDayHighlight(isToday: highlightIsToday, isSelected: highlightIsSelected, theme: theme)
        overflowLabel.font = theme.codeSmall
        for chip in titleChips where !chip.isHidden {
            chip.font = theme.caption
            chip.textColor = theme.textPrimary
            chip.backgroundColor = theme.surfaceSunken
        }
        for dot in indicatorDots where !dot.isHidden {
            dot.backgroundColor = theme.primary
        }
    }

    // MARK: - Number chip

    private func applyDayHighlight(isToday: Bool, isSelected: Bool, theme: CalendarTheme) {
        if isToday {
            // TODAY is the calendar's semantic accent moment: a clean filled olive
            // (`success`) chip with white (`onAccent`) on it — no border (the fill
            // carries it). Per the CUE — Clean selection rule, today/done = OLIVE.
            // It reads unmistakably more prominent than, and a different hue from,
            // the neutral-gray bordered SELECTED chip, so the accent stays the TODAY
            // hero and is never splashed on every selected cell.
            numberBackground.backgroundColor = theme.success
            numberBackground.layer.borderWidth = 0
            numberLabel.textColor = theme.onAccent
        } else if isSelected {
            // SELECTED is a quiet neutral sunken-gray chip ringed by the functional
            // border, so it is findable on white without spending a semantic accent.
            // Today, when also selected, keeps its olive fill above (today wins).
            numberBackground.backgroundColor = theme.surfaceSunken
            numberBackground.layer.borderWidth = 1
            numberBackground.layer.borderColor = theme.border.cgColor
            numberLabel.textColor = theme.textPrimary
        } else {
            numberBackground.backgroundColor = .clear
            numberBackground.layer.borderWidth = 0
            numberLabel.textColor = theme.textPrimary
        }
    }

    // MARK: - Indicators

    /// Shows up to ``maxIndicatorDots`` event-indicator dots for the day, hiding the
    /// whole row when the day has no events. The dot pool is reused across
    /// configures so scrolling stays allocation-light.
    private func applyIndicators(_ count: Int, theme: CalendarTheme) {
        guard count > 0 else {
            indicatorStack.isHidden = true
            for dot in indicatorDots { dot.isHidden = true }
            return
        }
        let visible = min(count, Self.maxIndicatorDots)
        ensureDotCount(visible, theme: theme)
        for (index, dot) in indicatorDots.enumerated() {
            dot.isHidden = index >= visible
            if index < visible { dot.backgroundColor = theme.primary }
        }
        indicatorStack.isHidden = false
    }

    /// Grows the pool of reusable indicator dots to at least `count`, styling any
    /// newly created ones. Existing dots are reused across configures.
    private func ensureDotCount(_ count: Int, theme: CalendarTheme) {
        while indicatorDots.count < count {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = theme.primary
            dot.layer.cornerRadius = Self.indicatorDotSize / 2
            dot.layer.masksToBounds = true
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: Self.indicatorDotSize),
                dot.heightAnchor.constraint(equalToConstant: Self.indicatorDotSize),
            ])
            indicatorDots.append(dot)
            indicatorStack.addArrangedSubview(dot)
        }
    }

    // MARK: - Titles

    private func applyTitles(_ titles: [String], theme: CalendarTheme) {
        let visible = Array(titles.prefix(Self.maxVisibleTitles))
        ensureChipCount(visible.count, theme: theme)

        for (index, chip) in titleChips.enumerated() {
            if index < visible.count {
                chip.text = visible[index]
                chip.isHidden = false
            } else {
                chip.isHidden = true
            }
        }

        let overflow = titles.count - Self.maxVisibleTitles
        if overflow > 0 {
            overflowLabel.text = "+\(overflow)"
            overflowLabel.font = theme.codeSmall
            overflowLabel.textColor = theme.textSecondary
            overflowLabel.isHidden = false
        } else {
            overflowLabel.isHidden = true
        }
    }

    /// Grows the pool of reusable title chips to at least `count`, styling any
    /// newly created ones. Existing chips are reused across configures.
    private func ensureChipCount(_ count: Int, theme: CalendarTheme) {
        while titleChips.count < count {
            let chip = PaddedLabel()
            chip.font = theme.caption
            chip.textColor = theme.textPrimary
            chip.backgroundColor = theme.surfaceSunken
            chip.layer.cornerRadius = Radius.tight
            chip.layer.masksToBounds = true
            chip.lineBreakMode = .byTruncatingTail
            titleChips.append(chip)
            titleStack.addArrangedSubview(chip)
        }
    }

    // MARK: - Accessibility

    private func applyAccessibility(number: String, isToday: Bool, titles: [String]) {
        isAccessibilityElement = true
        accessibilityTraits = .button
        var label = number
        if isToday { label += ", " + String(localized: "calendar.chrome.today") }
        if !titles.isEmpty { label += ", " + titles.joined(separator: ", ") }
        accessibilityLabel = label
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        for chip in titleChips { chip.isHidden = true }
        for dot in indicatorDots { dot.isHidden = true }
        indicatorStack.isHidden = true
        overflowLabel.isHidden = true
        numberBackground.backgroundColor = .clear
        numberBackground.layer.borderWidth = 0
        highlightIsToday = false
        highlightIsSelected = false
    }
}

// MARK: - Padded label

/// A `UILabel` with symmetric horizontal/vertical content insets — used for the
/// month-grid title chips so they read as small filled pills (matching the old
/// SwiftUI chip's 3pt/1pt padding).
final class PaddedLabel: UILabel {
    private let insets = UIEdgeInsets(top: 1, left: 3, bottom: 1, right: 3)

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        return CGSize(
            width: base.width + insets.left + insets.right,
            height: base.height + insets.top + insets.bottom
        )
    }
}

// MARK: - Month-title supplementary

/// The per-section month-title header (e.g. "May" / "May 2027"). Configured by the
/// owning ``MonthScopeViewController`` with the pre-formatted heading and theme.
final class MonthTitleHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "MonthTitleHeaderView"

    private let titleLabel = UILabel()
    private var theme: CalendarTheme?

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Spacing.sm),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Sets the heading text and theme.
    func configure(title: String, theme: CalendarTheme) {
        self.theme = theme
        titleLabel.text = title
        titleLabel.font = theme.titleL
        titleLabel.textColor = theme.textPrimary
    }
}

// MARK: - Weekday legend supplementary

/// The scope-wide weekday-symbol legend (e.g. "M T W T F S S"), pinned to the top
/// of the visible bounds. Opaque-backed (`theme.surfaceSunken` + a hairline rule)
/// so scrolling month content never shows through the pinned row, reproducing the
/// SwiftUI `weekdayHeader`.
final class MonthWeekdayHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "MonthWeekdayHeaderView"

    private let stack = UIStackView()
    private let separator = UIView()
    private var symbolLabels: [UILabel] = []
    private var theme: CalendarTheme?

    override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: MonthLayout.horizontalInset),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -MonthLayout.horizontalInset),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])

        buildSymbols()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Builds the seven locale-ordered weekday-symbol labels once.
    private func buildSymbols() {
        for symbol in CalendarMath.orderedWeekdaySymbols() {
            let label = UILabel()
            label.text = symbol.uppercased()
            label.textAlignment = .center
            symbolLabels.append(label)
            stack.addArrangedSubview(label)
        }
    }

    /// Applies the opaque background, hairline rule, and symbol typography.
    func configure(theme: CalendarTheme) {
        self.theme = theme
        backgroundColor = theme.surfaceSunken
        separator.backgroundColor = theme.separator
        for label in symbolLabels {
            label.font = theme.codeSmall
            label.textColor = theme.textSecondary
        }
    }
}
