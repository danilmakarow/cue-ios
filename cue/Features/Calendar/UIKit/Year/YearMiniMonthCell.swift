//
//  YearMiniMonthCell.swift
//  cue
//

import UIKit

/// Miniature month inside the year grid: the abbreviated month name above a tiny
/// 7-column day-number grid — the UIKit port of the SwiftUI `YearMonthCell` +
/// `MiniMonthGrid`, matching its layout (a left-aligned label over a compact
/// numbers grid). **Dot-free by design**: the year scope shows no event density,
/// exactly like the old `YearMonthCell`.
///
/// The day numbers are drawn in a single `draw(_:)` pass (one ``MiniMonthGridView``)
/// rather than ~37 laid-out labels, because a year section realizes twelve of
/// these at once mid-scroll — the same performance reason the SwiftUI version used
/// a `Canvas`. All strings arrive pre-formatted from ``MonthGridModel``.
///
/// Named `YearMiniMonthCell` (not `YearMonthCell`) so it coexists with the
/// still-present SwiftUI `YearMonthCell` until Integration removes the old surface
/// — the file-system-synchronized target requires distinct file names.
///
/// Deliberately *dumb*: the owning ``YearScopeViewController`` configures it with
/// the month's ``MonthGridModel``, the today key (when today falls in this month),
/// and the theme. It does no date math, no formatting, and no store access.
final class YearMiniMonthCell: UICollectionViewCell {

    static let reuseIdentifier = "YearMiniMonthCell"

    // MARK: - Views

    private let nameLabel = UILabel()
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
    /// name and the day-number mini-grid.
    private func setUp() {
        contentView.clipsToBounds = true

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.setContentHuggingPriority(.required, for: .vertical)

        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(nameLabel)
        stack.addArrangedSubview(gridView)
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
    /// day-number cells; `todayKey` is today's `startOfDay` when today falls in
    /// this month (else nil), which both tints today's number and flags the title
    /// as the current month.
    func configure(model: MonthGridModel, todayKey: Date?, theme: CalendarTheme) {
        self.theme = theme
        isCurrentMonth = todayKey != nil
        nameLabel.text = model.nameAbbreviated
        applyNameStyle(theme: theme)
        gridView.configure(
            model: model,
            todayKey: todayKey,
            dayColor: theme.textSecondary,
            todayColor: theme.success,
            font: theme.codeSmall
        )
        applyAccessibility(name: model.nameAbbreviated)
    }

    /// Re-styles the cell in place when only the theme changed (no content change).
    func apply(theme: CalendarTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        applyNameStyle(theme: theme)
        gridView.restyle(
            dayColor: theme.textSecondary,
            todayColor: theme.success,
            font: theme.codeSmall
        )
    }

    // MARK: - Styling

    /// Tints the month name `accentText` for the current month, else `textPrimary`
    /// — matching the SwiftUI `YearMonthCell` title tint.
    private func applyNameStyle(theme: CalendarTheme) {
        nameLabel.font = theme.label
        nameLabel.textColor = isCurrentMonth ? theme.accentText : theme.textPrimary
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

// MARK: - Mini-month grid

/// A compact 7-column day-number grid drawn in a single Core Graphics pass — the
/// UIKit port of the SwiftUI `MiniMonthGrid`'s `Canvas`. One view (and one draw
/// pass) regardless of the month's length, so a year section realizing twelve
/// mini-months stays cheap mid-scroll.
///
/// Theme colours and the day font arrive as values (rather than read live) so the
/// draw pass is self-contained, mirroring why the SwiftUI `Canvas` took resolved
/// colours rather than reading `@Environment`.
final class MiniMonthGridView: UIView {

    /// Height of one mini-grid row, matching the SwiftUI `MiniMonthGrid.rowHeight`.
    private static let rowHeight: CGFloat = 11
    /// Always reserve six rows so every mini-month is the same height regardless of
    /// its real row count — keeps the year sections uniform.
    private static let fixedRowCount = 6

    private var cells: [MonthGridModel.Day?] = []
    private var leadingBlankCount = 0
    private var todayKey: Date?
    private var dayColor: UIColor = .label
    private var todayColor: UIColor = .tintColor
    private var dayFont: UIFont = .monospacedDigitSystemFont(ofSize: 8, weight: .regular)

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

    /// Binds the grid to a month's cells and redraws.
    func configure(
        model: MonthGridModel,
        todayKey: Date?,
        dayColor: UIColor,
        todayColor: UIColor,
        font: UIFont
    ) {
        cells = model.cells
        leadingBlankCount = model.leadingBlankCount
        self.todayKey = todayKey
        self.dayColor = dayColor
        self.todayColor = todayColor
        // Shrink the configured font to the mini-grid's tiny size while keeping its
        // Dynamic-Type scaling and monospaced digits.
        dayFont = font.withSize(8)
        setNeedsDisplay()
    }

    /// Re-applies colours/font on a theme change without rebinding the month.
    func restyle(dayColor: UIColor, todayColor: UIColor, font: UIFont) {
        self.dayColor = dayColor
        self.todayColor = todayColor
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
            let center = CGPoint(
                x: (CGFloat(column) + 0.5) * columnWidth,
                y: (CGFloat(row) + 0.5) * Self.rowHeight
            )
            draw(number: day.number, at: center, isToday: day.date == todayKey)
        }
    }

    /// Draws one centered day number with the appropriate tint. TODAY additionally
    /// gets a thin stroked ring so it stays visible in the dense mini-grid, where a
    /// colour change alone is too subtle to spot mid-scroll.
    private func draw(number: String, at center: CGPoint, isToday: Bool) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: dayFont,
            .foregroundColor: isToday ? todayColor : dayColor,
        ]
        let text = number as NSString
        let size = text.size(withAttributes: attributes)
        if isToday {
            let ringRadius = max(size.width, size.height) / 2 + 1.5
            let ring = UIBezierPath(
                arcCenter: center,
                radius: ringRadius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            ring.lineWidth = 0.75
            todayColor.setStroke()
            ring.stroke()
        }
        let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        text.draw(at: origin, withAttributes: attributes)
    }
}

// MARK: - Year-title supplementary

/// The per-section year title (e.g. "2026") drawn as a large serif heading over
/// a short clay accent underline — the UIKit port of the SwiftUI `YearPage` title block.
/// Configured by the owning ``YearScopeViewController`` with the pre-formatted year
/// string and theme.
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

    /// Sets the year heading text and theme (serif `displayL` title over a clay
    /// `secondary` underline capsule).
    func configure(title: String, theme: CalendarTheme) {
        self.theme = theme
        titleLabel.text = title
        titleLabel.font = theme.displayL
        titleLabel.textColor = theme.textPrimary
        underline.backgroundColor = theme.secondary
        underline.layer.cornerRadius = 1
    }
}
