//
//  MonthLayout.swift
//  cue
//

import UIKit

/// Pure compositional-layout geometry for the month scope: one section per month,
/// each a 7-column day grid (six week rows) preceded by a month-title supplementary
/// header, with a single pinned weekday-symbol header spanning the whole scope.
///
/// Kept free of any data or view-controller state so the layout is testable and the
/// owning ``MonthScopeViewController`` only wires the section provider. The grid is
/// always laid out as six rows (`weekRowCount` = 6) regardless of the month's real
/// row count so every section is the same height — which makes the prepend
/// content-offset correction a simple `prependedSectionCount * sectionHeight`.
enum MonthLayout {

    // MARK: - Supplementary kinds

    /// Boundary-supplementary kind for the per-section month title (pinned to the
    /// top of its own section while that section scrolls under the weekday header).
    static let monthTitleKind = "month-title-header"

    /// Boundary-supplementary kind for the scope-wide weekday-symbol row, pinned to
    /// the top of the visible bounds so the column legend is always on screen.
    static let weekdayHeaderKind = "weekday-symbol-header"

    // MARK: - Fixed structure

    /// Fixed number of week rows per month section. Using a constant six (rather
    /// than the month's real `weekRowCount`) keeps every section identical in
    /// height, so the infinite-scroll prepend can correct `contentOffset` by a
    /// simple multiple of the section height.
    static let weekRowCount = 6

    /// Height of a single day row. Raised from 64 (past the design's documented
    /// cell `min-height:72px`, §4) with headroom so the Stacked density's full three
    /// tinted chips fit under the 24pt number without the 2nd/3rd chip clipping at
    /// the cell's bottom edge: 24 (number) + 2 (gap) + three ~16pt chips + two 1pt
    /// inter-chip gaps ≈ 77pt, so 80 clears it with a sub-pixel-rounding margin.
    /// (Pairs with the tightened `MonthChipView` vertical padding + `titleStack`
    /// spacing below.)
    static let dayRowHeight: CGFloat = 80

    /// Height of the per-section month-title header.
    static let monthTitleHeight: CGFloat = 44

    /// Height of the pinned weekday-symbol legend row.
    static let weekdayHeaderHeight: CGFloat = 32

    /// Horizontal inset on each side of the grid, matching the SwiftUI grid's
    /// `Spacing.md` horizontal padding.
    static let horizontalInset: CGFloat = Spacing.md

    /// Inter-item spacing inside a week row, matching the SwiftUI grid's `Spacing.xs`.
    static let columnSpacing: CGFloat = Spacing.xs

    /// Inter-row spacing inside a month, matching the SwiftUI grid's `Spacing.sm`.
    static let rowSpacing: CGFloat = Spacing.sm

    // MARK: - Section height

    /// The fixed on-screen height of one month section (title + six week rows +
    /// inter-row spacing + bottom breathing room). The infinite-scroll prepend
    /// uses this to correct `contentOffset` so the viewport doesn't jump.
    static var sectionHeight: CGFloat {
        let rows = CGFloat(weekRowCount)
        let grid = rows * dayRowHeight + (rows - 1) * rowSpacing
        return monthTitleHeight + grid + Spacing.xxl
    }

    // MARK: - Layout

    /// Builds the compositional layout: a section provider that lays out the
    /// 7-column / 6-row grid plus the per-section month-title header, and the
    /// scope-wide pinned weekday-symbol boundary header.
    static func make() -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.interSectionSpacing = 0
        configuration.boundarySupplementaryItems = [makeWeekdayHeaderItem()]

        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { _, _ in makeMonthSection() },
            configuration: configuration
        )
        return layout
    }

    // MARK: - Section

    /// One month: a 7-column grid of six week rows plus a month-title header item.
    private static func makeMonthSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / 7.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let rowSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(dayRowHeight)
        )
        let row = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitems: [item])
        row.interItemSpacing = .fixed(columnSpacing)

        let gridSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(CGFloat(weekRowCount) * dayRowHeight + CGFloat(weekRowCount - 1) * rowSpacing)
        )
        let grid = NSCollectionLayoutGroup.vertical(
            layoutSize: gridSize,
            repeatingSubitem: row,
            count: weekRowCount
        )
        grid.interItemSpacing = .fixed(rowSpacing)

        let section = NSCollectionLayoutSection(group: grid)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0, leading: horizontalInset, bottom: Spacing.xxl, trailing: horizontalInset
        )
        section.boundarySupplementaryItems = [makeMonthTitleItem()]
        return section
    }

    // MARK: - Supplementary items

    /// The per-section month-title header (`MonthTitleHeaderView`), full width and
    /// sitting above the grid. Not pinned — it scrolls with its section under the
    /// pinned weekday legend.
    private static func makeMonthTitleItem() -> NSCollectionLayoutBoundarySupplementaryItem {
        let size = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(monthTitleHeight)
        )
        let item = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: size,
            elementKind: monthTitleKind,
            alignment: .top
        )
        item.pinToVisibleBounds = false
        // The grid section has horizontal content insets; the title should align
        // with the day columns, so no extra offset is applied.
        return item
    }

    /// The scope-wide weekday-symbol legend, pinned to the top of the visible
    /// bounds so the column meaning stays on screen while months scroll under it.
    /// Its backing view is opaque so scrolling content never shows through.
    private static func makeWeekdayHeaderItem() -> NSCollectionLayoutBoundarySupplementaryItem {
        let size = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(weekdayHeaderHeight)
        )
        let item = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: size,
            elementKind: weekdayHeaderKind,
            alignment: .top
        )
        item.pinToVisibleBounds = true
        // Keep the legend above every section's own title supplementary.
        item.zIndex = 10
        return item
    }
}
