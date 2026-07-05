//
//  YearLayout.swift
//  cue
//

import UIKit

/// Pure compositional-layout geometry for the year scope: one section per year,
/// each a grid of twelve mini-month cells (two columns, mirroring the CUE — Clean
/// `Calendar Year` design) preceded by a year-title supplementary header.
///
/// Kept free of any data or view-controller state so the layout is testable and
/// the owning ``YearScopeViewController`` only wires the section provider. Every
/// section is laid out at the same fixed height (`sectionHeight`) regardless of
/// how many rows the months actually need — a year always has 12 mini-months in
/// six rows of two — which makes the infinite-scroll prepend content-offset
/// correction a simple `prependedSectionCount * sectionHeight`.
enum YearLayout {

    // MARK: - Supplementary kinds

    /// Boundary-supplementary kind for the per-section year title (e.g. "2026"),
    /// scrolling with its own section above the mini-month grid.
    static let yearTitleKind = "year-title-header"

    // MARK: - Fixed structure

    /// Number of mini-month columns per year. Matches the CUE — Clean design's
    /// two-column `repeat(2, 1fr)` year grid (wide 2-up mini-months).
    static let columnCount = 2

    /// Number of mini-month rows per year (12 months / 2 columns = 6 rows).
    static let rowCount = 6

    /// Height of one mini-month cell. Sized to comfortably hold the abbreviated
    /// month name, the `M T W T F S S` weekday header row, and a six-row 7-column
    /// day-number heatmap mini-grid (see ``YearMiniMonthCell``). The heatmap rows
    /// are taller than the old dot-free grid (13pt vs 11pt) to give each tinted
    /// tile room, and the weekday header adds ~15pt above the grid, so the cell is
    /// a touch taller than the header-less version.
    static let miniMonthHeight: CGFloat = 132

    /// Height of the per-section year-title header (a large Fraunces year plus an
    /// underline rule), mirroring the SwiftUI `YearPage` title block.
    static let yearTitleHeight: CGFloat = 64

    /// Horizontal inset on each side of the grid, matching the SwiftUI year grid's
    /// `Spacing.lg` horizontal padding.
    static let horizontalInset: CGFloat = Spacing.lg

    /// Inter-item spacing between mini-month columns, matching the SwiftUI grid's
    /// `Spacing.lg` column spacing.
    static let columnSpacing: CGFloat = Spacing.lg

    /// Inter-row spacing between mini-month rows, matching the SwiftUI grid's
    /// `Spacing.xl` row spacing.
    static let rowSpacing: CGFloat = Spacing.xl

    /// Vertical gap between year sections, matching the SwiftUI `LazyVStack`'s
    /// 36pt spacing.
    static let interSectionSpacing: CGFloat = 36

    // MARK: - Section height

    /// The fixed on-screen height of one year section (title + four mini-month
    /// rows + inter-row spacing + bottom breathing room). The infinite-scroll
    /// prepend uses this — plus ``interSectionSpacing`` — to correct
    /// `contentOffset` so the viewport doesn't jump.
    static var sectionHeight: CGFloat {
        let rows = CGFloat(rowCount)
        let grid = rows * miniMonthHeight + (rows - 1) * rowSpacing
        return yearTitleHeight + grid + Spacing.xxl
    }

    /// The full vertical advance from one section's top to the next section's top
    /// — the section height plus the configured inter-section spacing. The prepend
    /// offset correction multiplies this by the number of prepended sections.
    static var sectionAdvance: CGFloat {
        sectionHeight + interSectionSpacing
    }

    // MARK: - Layout

    /// Builds the compositional layout: a section provider laying out the
    /// two-column / six-row mini-month grid plus the per-section year-title
    /// header, with a fixed inter-section gap.
    static func make() -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.interSectionSpacing = interSectionSpacing

        return UICollectionViewCompositionalLayout(
            sectionProvider: { _, _ in makeYearSection() },
            configuration: configuration
        )
    }

    // MARK: - Section

    /// One year: a two-column grid of six mini-month rows plus a year-title
    /// header item.
    private static func makeYearSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(columnCount)),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let rowSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(miniMonthHeight)
        )
        let row = NSCollectionLayoutGroup.horizontal(
            layoutSize: rowSize,
            repeatingSubitem: item,
            count: columnCount
        )
        row.interItemSpacing = .fixed(columnSpacing)

        let gridSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(
                CGFloat(rowCount) * miniMonthHeight + CGFloat(rowCount - 1) * rowSpacing
            )
        )
        let grid = NSCollectionLayoutGroup.vertical(
            layoutSize: gridSize,
            repeatingSubitem: row,
            count: rowCount
        )
        grid.interItemSpacing = .fixed(rowSpacing)

        let section = NSCollectionLayoutSection(group: grid)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0, leading: horizontalInset, bottom: Spacing.xxl, trailing: horizontalInset
        )
        section.boundarySupplementaryItems = [makeYearTitleItem()]
        return section
    }

    // MARK: - Supplementary item

    /// The per-section year-title header (``YearTitleHeaderView``), full width and
    /// sitting above the mini-month grid. Not pinned — it scrolls with its section.
    private static func makeYearTitleItem() -> NSCollectionLayoutBoundarySupplementaryItem {
        let size = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(yearTitleHeight)
        )
        let item = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: size,
            elementKind: yearTitleKind,
            alignment: .top
        )
        item.pinToVisibleBounds = false
        return item
    }
}
