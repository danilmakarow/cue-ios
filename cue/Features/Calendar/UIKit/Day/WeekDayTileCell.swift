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
/// slot that shows — in priority order — a short month label (for days far from
/// today), a small task-count badge, or the today dot. The selected state only
/// recolors text (the espresso fill is drawn by the strip's indicator), so the
/// number/weekday read correctly once the indicator slides under the tile.
final class WeekDayTileCell: UICollectionViewCell {

    static let reuseIdentifier = "WeekDayTileCell"

    // MARK: - Subviews

    private let dayNumberLabel = UILabel()
    private let weekdayLabel = UILabel()
    private let bottomLabel = UILabel()
    private let countBadge = UILabel()
    private let todayDot = UIView()
    private let stack = UIStackView()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEEE"   // "Mo", "Tu", …
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
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
        bottomLabel.textAlignment = .center

        todayDot.translatesAutoresizingMaskIntoConstraints = false
        todayDot.layer.cornerRadius = 2.5
        NSLayoutConstraint.activate([
            todayDot.widthAnchor.constraint(equalToConstant: 5),
            todayDot.heightAnchor.constraint(equalToConstant: 5),
        ])

        countBadge.translatesAutoresizingMaskIntoConstraints = false
        countBadge.textAlignment = .center
        countBadge.layer.cornerCurve = .continuous
        countBadge.clipsToBounds = true

        // Fixed-height bottom slot holds the month label, the count badge, or the
        // today dot (only one visible at a time).
        let bottomSlot = UIView()
        bottomSlot.translatesAutoresizingMaskIntoConstraints = false
        bottomSlot.addSubview(bottomLabel)
        bottomSlot.addSubview(countBadge)
        bottomSlot.addSubview(todayDot)
        bottomLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bottomSlot.heightAnchor.constraint(equalToConstant: 14),
            bottomLabel.centerXAnchor.constraint(equalTo: bottomSlot.centerXAnchor),
            bottomLabel.centerYAnchor.constraint(equalTo: bottomSlot.centerYAnchor),
            countBadge.centerXAnchor.constraint(equalTo: bottomSlot.centerXAnchor),
            countBadge.centerYAnchor.constraint(equalTo: bottomSlot.centerYAnchor),
            countBadge.heightAnchor.constraint(equalToConstant: 14),
            countBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 14),
            todayDot.centerXAnchor.constraint(equalTo: bottomSlot.centerXAnchor),
            todayDot.centerYAnchor.constraint(equalTo: bottomSlot.centerYAnchor),
        ])

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Spacing.xxs
        stack.isUserInteractionEnabled = false
        stack.addArrangedSubview(dayNumberLabel)
        stack.addArrangedSubview(weekdayLabel)
        stack.addArrangedSubview(bottomSlot)
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    // MARK: - Configuration

    /// Binds the tile to a date + state, styling with `theme`. Selection only
    /// recolors text — the espresso fill is drawn by the strip's sliding
    /// indicator behind this tile. `count` is the day's task-occurrence total
    /// (nil or 0 hides the badge).
    func configure(
        date: Date,
        count: Int?,
        isSelected: Bool,
        isToday: Bool,
        showMonthLabel: Bool,
        theme: CalendarTheme
    ) {
        dayNumberLabel.text = date.formatted(.dateTime.day())
        dayNumberLabel.font = theme.titleM
        dayNumberLabel.textColor = isSelected ? theme.onAccent : theme.textPrimary

        weekdayLabel.text = Self.weekdayFormatter.string(from: date).uppercased()
        weekdayLabel.font = theme.codeSmall
        weekdayLabel.textColor = isSelected
            ? theme.onAccent.withAlphaComponent(0.85)
            : theme.textSecondary

        configureBottomSlot(
            date: date,
            count: count,
            isSelected: isSelected,
            isToday: isToday,
            showMonthLabel: showMonthLabel,
            theme: theme
        )
    }

    /// Resolves the single bottom-slot affordance: month label outside the
    /// window wins, then the task-count badge, then the today dot, else empty.
    private func configureBottomSlot(
        date: Date,
        count: Int?,
        isSelected: Bool,
        isToday: Bool,
        showMonthLabel: Bool,
        theme: CalendarTheme
    ) {
        bottomLabel.isHidden = true
        countBadge.isHidden = true
        todayDot.isHidden = true

        if showMonthLabel {
            bottomLabel.isHidden = false
            bottomLabel.text = Self.monthFormatter.string(from: date).uppercased()
            bottomLabel.font = theme.codeSmall
            bottomLabel.textColor = isSelected
                ? theme.onAccent.withAlphaComponent(0.85)
                : theme.textSecondary.withAlphaComponent(0.7)
            return
        }

        if let count, count > 0 {
            // The per-day count is a neutral ledger badge — espresso ink on a
            // sunken chip — so terracotta stays reserved for the TODAY dot and is
            // never splashed across every day with tasks. On the selected (espresso)
            // tile it inverts to cream-on-cream-wash for contrast.
            countBadge.isHidden = false
            countBadge.text = count < 100 ? " \(count) " : " ••• "
            countBadge.font = theme.codeSmall
            countBadge.layer.cornerRadius = 4
            countBadge.textColor = isSelected ? theme.onAccent : theme.textSecondary
            countBadge.backgroundColor = isSelected
                ? theme.onAccent.withAlphaComponent(0.18)
                : theme.surfaceSunken
            return
        }

        if isToday {
            // TODAY's one-hot terracotta dot (or cream on the selected espresso tile).
            todayDot.isHidden = false
            todayDot.backgroundColor = isSelected ? theme.onAccent : theme.secondary
        }
    }
}
