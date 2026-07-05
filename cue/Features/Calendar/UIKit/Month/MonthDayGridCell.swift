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
/// The three month-grid content densities (design-spec §4). `showChips` is false
/// only in Compact, which renders colored dots instead of text chips.
///
/// Declared at file scope so the owning ``MonthScopeViewController`` and the cell
/// share one type. Defaults to ``stacked`` (the bundle default).
enum MonthDensity {
    /// No text — a wrap row of up to four colored dots + a `+` overflow pill.
    case compact
    /// Up to three color-tinted chips, each with the task title (single line).
    case stacked
    /// Up to two color-tinted chips, each with a mono time line above its title.
    case details

    /// Whether this density renders text chips (Stacked / Details) vs dots (Compact).
    var showsChips: Bool { self != .compact }
}

/// One day's worth of event presentation for the month grid: a title, the day's
/// mono time label (`HH:MM` or all-day), the recurring flag, and the resolved
/// EFFECTIVE color (task ?? group ?? gray) used to tint its chip / draw its dot.
/// The color is `nil` only when both tokens are absent (the cell then falls back
/// to the neutral sunken chip / gray dot).
struct MonthDayChip {
    let title: String
    /// Pre-formatted time for the Details density (`09:30`) or the localized
    /// all-day label when the occurrence spans the whole day.
    let time: String
    /// Whether the occurrence is a recurring instance — drives the `▸ ` title
    /// prefix (Stacked/Details) mirroring the design bundle.
    let isRecurring: Bool
    /// Effective per-occurrence color (task ?? group ?? gray). `nil` only when the
    /// resolver had neither token, in which case the neutral fallback is used.
    let color: UIColor?
}

final class MonthDayGridCell: UICollectionViewCell {

    static let reuseIdentifier = "MonthDayGridCell"

    /// Most title chips shown in the Stacked density before the rest collapse into a
    /// "+N more" row (design-spec §4 Stacked = up to 3).
    private static let maxStackedChips = 3

    /// Most chips shown in the Details density (design-spec §4 Details = up to 2).
    private static let maxDetailChips = 2

    // MARK: - Views

    /// Most colored dots shown in the Compact density before the rest collapse into a
    /// `+` overflow pill (design-spec §4 Compact = up to 4).
    private static let maxIndicatorDots = 4
    /// The diameter of one Compact-density event dot (design: `8×8`).
    private static let indicatorDotSize: CGFloat = 8
    /// The height of the Compact `+` overflow pill (design: `height:14`).
    private static let overflowPillHeight: CGFloat = 14
    /// Local tint alpha for flattening the effective color behind a chip's ink
    /// (design tints run `~0.12–0.16`; we sit mid-range at `0.14`).
    private static let chipTintAlpha: CGFloat = 0.14

    /// Neutral gray fallback for a dot/chip when the occurrence resolved to no
    /// color at all (design `--text-tertiary` `#9C9893`). Computed locally so this
    /// cell never depends on a theme token that isn't exposed; in practice the
    /// effective-color resolver already substitutes this gray, so it is a belt-and-
    /// suspenders default.
    private static let neutralFallback = UIColor(
        red: 0x9C / 255, green: 0x98 / 255, blue: 0x93 / 255, alpha: 1
    )

    private let numberLabel = UILabel()
    private let numberBackground = UIView()
    private let indicatorStack = UIStackView()
    private let titleStack = UIStackView()
    private let overflowLabel = UILabel()
    private let overflowPill = PaddedLabel()
    private let contentStack = UIStackView()

    /// Reusable tinted chip views (Stacked/Details), grown lazily and hidden when
    /// unused so the cell avoids per-configure allocation while scrolling.
    private var titleChips: [MonthChipView] = []

    /// Reusable Compact-density dot views, grown lazily and hidden when unused so
    /// the cell avoids per-configure allocation while scrolling.
    private var indicatorDots: [UIView] = []

    private var theme: CalendarTheme?

    /// The active content density; drives which chip/dot renderer runs. Kept so a
    /// theme-only restyle repaints against the same density (defaults to Stacked).
    private var density: MonthDensity = .stacked

    /// Remembers the day's highlight state so a theme-only restyle can re-apply the
    /// TODAY/SELECTED chip with the new theme's colours (mirrors how
    /// ``YearMiniMonthCell`` keeps `isCurrentMonth` for its restyle path).
    private var highlightIsToday = false
    private var highlightIsSelected = false

    /// The day's chips, kept so a theme-only restyle re-applies the per-group
    /// chip tints / dot colors with the new theme's neutral fallbacks.
    private var lastChips: [MonthDayChip] = []

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
        // Clip the fill / border into the rounded shape so the 24×24 chip reads as a
        // true circle (design: `border-radius:50%`) rather than a rounded square.
        numberBackground.layer.masksToBounds = true
        numberBackground.addSubview(numberLabel)
        // The number chip is a fixed 24×24 circle, left-aligned in its row.
        let numberRow = UIView()
        numberRow.translatesAutoresizingMaskIntoConstraints = false
        numberRow.addSubview(numberBackground)

        indicatorStack.axis = .horizontal
        indicatorStack.alignment = .center
        indicatorStack.spacing = Spacing.xs
        indicatorStack.isHidden = true

        titleStack.axis = .vertical
        titleStack.alignment = .fill
        // 1pt inter-chip gap (tighter than the default `xxs`=2) so the Stacked
        // density's full three chips clear the day-row height without clipping.
        titleStack.spacing = 1

        // The Compact `+` overflow pill (design: sunken fill, hairline border,
        // mono `+`), tucked at the end of the dot row. Built once, reused; its font
        // and colors are set per-configure in ``applyDots``.
        overflowPill.textAlignment = .center
        overflowPill.layer.masksToBounds = true
        overflowPill.layer.cornerRadius = Self.overflowPillHeight / 2
        overflowPill.layer.borderWidth = 1
        overflowPill.isHidden = true
        overflowPill.setContentHuggingPriority(.required, for: .horizontal)

        overflowLabel.isHidden = true

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = Spacing.xxs
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(numberRow)
        contentStack.addArrangedSubview(indicatorStack)
        contentStack.addArrangedSubview(titleStack)
        contentStack.addArrangedSubview(overflowLabel)
        // A trailing spacer keeps the dot row left-aligned so the `+` pill tucks
        // right after the last dot rather than stretching across the cell.
        let dotSpacer = UIView()
        dotSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        indicatorStack.addArrangedSubview(overflowPill)
        indicatorStack.addArrangedSubview(dotSpacer)
        contentView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            overflowPill.heightAnchor.constraint(equalToConstant: Self.overflowPillHeight),
            overflowPill.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.overflowPillHeight),
        ])

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
    /// `isSelected` drive the chip highlight; `chips` are the day's occurrences,
    /// rendered per `density` (Compact dots / Stacked chips / Details timed chips)
    /// and capped with a density-specific overflow affordance.
    func configure(
        number: String,
        isToday: Bool,
        isSelected: Bool,
        chips: [MonthDayChip],
        density: MonthDensity,
        theme: CalendarTheme
    ) {
        self.theme = theme
        self.density = density
        highlightIsToday = isToday
        highlightIsSelected = isSelected
        lastChips = chips
        numberLabel.text = number
        numberLabel.font = theme.codeSmall

        applyDayHighlight(isToday: isToday, isSelected: isSelected, theme: theme)
        applyContent(chips, density: density, theme: theme)
        applyAccessibility(number: number, isToday: isToday, titles: chips.map(\.title))
    }

    /// Re-styles the cell in place when only the theme changed (no content change).
    func apply(theme: CalendarTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        numberLabel.font = theme.codeSmall
        applyDayHighlight(isToday: highlightIsToday, isSelected: highlightIsSelected, theme: theme)
        overflowLabel.font = theme.codeSmall
        // Re-apply the per-density chips/dots against the new theme's neutral
        // fallbacks (a theme change keeps the same chip set + density).
        applyContent(lastChips, density: density, theme: theme)
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
            // SELECTED is a quiet sunken-gray chip carrying OLIVE (`success`) ink and a
            // 1.5pt olive ring (design: numColor=`var(--success)`, numRing=`0 0 0 1.5px
            // var(--success)`), so the focused day reads in the CUE — Clean today/done
            // olive without taking the filled-olive TODAY treatment. Today, when also
            // selected, keeps its olive fill above (today wins).
            numberBackground.backgroundColor = theme.surfaceSunken
            numberBackground.layer.borderWidth = 1.5
            numberBackground.layer.borderColor = theme.success.cgColor
            numberLabel.textColor = theme.success
        } else {
            numberBackground.backgroundColor = .clear
            numberBackground.layer.borderWidth = 0
            numberLabel.textColor = theme.textPrimary
        }
    }

    // MARK: - Content (density-routed)

    /// Renders the day's occurrences per `density`, one branch active at a time:
    /// Compact draws colored dots (+ overflow pill), Stacked/Details draw tinted
    /// chips (+ "+N more" label). The inactive branch's views are hidden so a
    /// reused cell never shows stale content from another density.
    private func applyContent(_ chips: [MonthDayChip], density: MonthDensity, theme: CalendarTheme) {
        if density.showsChips {
            hideDots()
            let maxChips = density == .details ? Self.maxDetailChips : Self.maxStackedChips
            applyChips(chips, maxChips: maxChips, showsTime: density == .details, theme: theme)
        } else {
            hideChips()
            applyDots(chips, theme: theme)
        }
    }

    /// Hides every dot-row view (Compact) — used when the active density is chips.
    private func hideDots() {
        indicatorStack.isHidden = true
        for dot in indicatorDots { dot.isHidden = true }
        overflowPill.isHidden = true
    }

    /// Hides every chip-list view (Stacked/Details) — used when the active density
    /// is Compact dots.
    private func hideChips() {
        for chip in titleChips { chip.isHidden = true }
        titleStack.isHidden = true
        overflowLabel.isHidden = true
    }

    // MARK: - Compact (dots)

    /// Compact density: up to ``maxIndicatorDots`` effective-color dots (design:
    /// `8×8`), then a `+` overflow pill when the day holds more. Hidden entirely
    /// for an empty day. The dot + pill pool is reused across configures.
    private func applyDots(_ chips: [MonthDayChip], theme: CalendarTheme) {
        guard !chips.isEmpty else {
            indicatorStack.isHidden = true
            for dot in indicatorDots { dot.isHidden = true }
            overflowPill.isHidden = true
            return
        }
        indicatorStack.isHidden = false
        titleStack.isHidden = true

        let visibleCount = min(chips.count, Self.maxIndicatorDots)
        ensureDotCount(visibleCount, theme: theme)
        for (index, dot) in indicatorDots.enumerated() {
            if index < visibleCount {
                dot.backgroundColor = chips[index].color ?? Self.neutralFallback
                dot.isHidden = false
            } else {
                dot.isHidden = true
            }
        }

        if chips.count > Self.maxIndicatorDots {
            overflowPill.text = "+"
            overflowPill.font = theme.codeSmall
            overflowPill.textColor = theme.textSecondary
            overflowPill.backgroundColor = theme.surfaceSunken
            overflowPill.layer.borderColor = theme.border.cgColor
            overflowPill.isHidden = false
        } else {
            overflowPill.isHidden = true
        }
    }

    /// Grows the pool of reusable dots to at least `count`, styling any newly
    /// created ones. Dots are inserted *before* the `+` overflow pill (always the
    /// trailing dot-row member) so the pill tucks after the dots. Existing dots are
    /// reused across configures; their per-occurrence color is set in ``applyDots``.
    private func ensureDotCount(_ count: Int, theme: CalendarTheme) {
        while indicatorDots.count < count {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = Self.neutralFallback
            dot.layer.cornerRadius = Self.indicatorDotSize / 2
            dot.layer.masksToBounds = true
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: Self.indicatorDotSize),
                dot.heightAnchor.constraint(equalToConstant: Self.indicatorDotSize),
            ])
            indicatorDots.append(dot)
            // Insert ahead of the pill so dots always precede it.
            let pillIndex = indicatorStack.arrangedSubviews.firstIndex(of: overflowPill) ?? 0
            indicatorStack.insertArrangedSubview(dot, at: pillIndex)
        }
    }

    // MARK: - Stacked / Details (tinted chips)

    /// Stacked/Details density: up to `maxChips` color-tinted chips beneath the
    /// number, each with the task title (Stacked) or a mono time line + title
    /// (Details), plus a "+N more" label when the day holds more. Hidden entirely
    /// for an empty day. The chip pool is reused across configures.
    private func applyChips(_ chips: [MonthDayChip], maxChips: Int, showsTime: Bool, theme: CalendarTheme) {
        let visible = Array(chips.prefix(maxChips))
        titleStack.isHidden = visible.isEmpty
        ensureChipCount(visible.count, theme: theme)

        for (index, chipView) in titleChips.enumerated() {
            if index < visible.count {
                let chip = visible[index]
                chipView.configure(
                    title: displayTitle(for: chip),
                    time: showsTime ? chip.time : nil,
                    // Flatten the effective color onto white at a low alpha for the
                    // chip wash, or fall back to the neutral sunken fill.
                    tint: chip.color?.withAlphaComponent(Self.chipTintAlpha) ?? theme.surfaceSunken,
                    theme: theme
                )
                chipView.isHidden = false
            } else {
                chipView.isHidden = true
            }
        }

        let overflow = chips.count - maxChips
        if overflow > 0 {
            let format = String(
                localized: "calendar.month.moreCount",
                defaultValue: "+%lld more",
                comment: "Month day-cell overflow, e.g. \"+2 more\""
            )
            overflowLabel.text = String(format: format, overflow)
            overflowLabel.font = theme.codeSmall
            overflowLabel.textColor = theme.textSecondary
            overflowLabel.isHidden = false
        } else {
            overflowLabel.isHidden = true
        }
    }

    /// The chip's rendered title: a `▸ ` recurring prefix (design bundle) ahead of
    /// the task title for recurring occurrences, else the plain title.
    private func displayTitle(for chip: MonthDayChip) -> String {
        chip.isRecurring ? "▸ \(chip.title)" : chip.title
    }

    /// Grows the pool of reusable tinted chips to at least `count`, adding any newly
    /// created ones to the title stack. Existing chips are reused across configures;
    /// their per-occurrence tint + text are set in ``applyChips``.
    private func ensureChipCount(_ count: Int, theme: CalendarTheme) {
        while titleChips.count < count {
            let chip = MonthChipView()
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
        titleStack.isHidden = false
        overflowLabel.isHidden = true
        overflowPill.isHidden = true
        numberBackground.backgroundColor = .clear
        numberBackground.layer.borderWidth = 0
        highlightIsToday = false
        highlightIsSelected = false
        density = .stacked
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

// MARK: - Month day chip

/// One tinted event chip inside a month day cell (Stacked / Details density). A
/// rounded color-washed container holding an optional mono time line (Details
/// only) above a single-line, tail-truncated title. Built once and reconfigured
/// per occurrence so the month grid scrolls allocation-light.
///
/// The tint (the effective color flattened onto white at a low alpha) is computed
/// by the owning cell and passed in — this view never resolves color itself.
final class MonthChipView: UIView {

    private let timeLabel = UILabel()
    private let titleLabel = UILabel()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = Radius.tight
        layer.masksToBounds = true

        timeLabel.lineBreakMode = .byTruncatingTail
        titleLabel.lineBreakMode = .byTruncatingTail

        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(timeLabel)
        stack.addArrangedSubview(titleLabel)
        addSubview(stack)

        // Design chip padding is `2px 5px`; the vertical inset is trimmed to 1pt so
        // three stacked chips fit the fixed day-row height without the last chip
        // clipping (the horizontal 5px is kept for the design's chip breathing room).
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Binds the chip to an occurrence. `time` is shown (Details density) only when
    /// non-nil; `tint` is the pre-flattened wash behind the ink.
    func configure(title: String, time: String?, tint: UIColor, theme: CalendarTheme) {
        backgroundColor = tint

        titleLabel.text = title
        titleLabel.font = theme.caption
        titleLabel.textColor = theme.textPrimary

        if let time {
            timeLabel.text = time
            timeLabel.font = theme.codeSmall
            timeLabel.textColor = theme.textSecondary
            timeLabel.isHidden = false
        } else {
            timeLabel.isHidden = true
        }
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
    ///
    /// - Parameter isCurrent: whether this section is the calendar's *current*
    ///   month. The current month gets the CUE — Clean present-moment treatment:
    ///   its title inks in OLIVE (`success`) — the same today/positive accent used
    ///   for the today day-chip — so the month you're in is visually distinguished
    ///   from the neutral near-black of every other month header (impl-plan B2).
    func configure(title: String, isCurrent: Bool, theme: CalendarTheme) {
        self.theme = theme
        titleLabel.text = title
        // System SANS at 22/semibold/-0.2 (design-spec §4: "Month header 22/500/-0.2",
        // and the CUE — Clean rule that the serif is reserved for DISPLAY titles only —
        // section/nav headings render in the system-sans title voice, `titleLSans`).
        titleLabel.font = theme.titleLSans
        titleLabel.textColor = isCurrent ? theme.success : theme.textPrimary
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
