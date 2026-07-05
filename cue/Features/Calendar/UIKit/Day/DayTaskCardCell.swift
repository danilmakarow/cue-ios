//
//  DayTaskCardCell.swift
//  cue
//

import UIKit

/// The single reusable Day-tile card: the floating chrome shared by BOTH the
/// timeline block (``DayTimelineEventCell``) and the agenda row (``DayAgendaCell``).
///
/// It renders the CUE — Clean floating card — `Radius.card` corner, a 1pt hairline
/// border, an explicit `shadowPath` soft floating shadow, `clipsToBounds = false`
/// so the shadow shows — plus a task-colored accent LINE down the card's LEFT edge.
///
/// **The left rail is a FULL-HEIGHT left border.** It spans the card top-to-bottom
/// and is clipped to the card's own rounded-rect silhouette, so its top and bottom
/// ends follow the card's top-left / bottom-left corner arcs and it never pokes
/// past the rounded corners. This is implemented by masking a solid left strip with
/// the card's rounded-rect path (see ``rebuildRail()``) rather than trying to round
/// the thin strip by its own tiny width — a strip rounded by `railWidth` would
/// overflow the card's larger corner arc, which is the overflow bug this replaces.
///
/// **Composition, not inheritance.** The card owns a single ``contentView`` region
/// that fills the card from just past the left rail to the trailing edge; each
/// adopting cell drops its own content subview into it and configures it. The card
/// knows nothing about titles, durations, notes, or toggles — only chrome, fill,
/// border, shadow, and the rail.
final class DayTaskCardView: UIView {

    // MARK: - Layout constants

    /// The rail's width — a slim colored left border line.
    static let railWidth: CGFloat = 4

    // MARK: - Variables

    /// Container for the left rail, sized to the FULL card and masked by the card's
    /// rounded-rect path so the rail's ends follow the rounded corners.
    private let railLayer = CALayer()
    /// The solid colored strip inside ``railLayer`` — a full-height rectangle of
    /// width ``railWidth`` pinned to the leading edge; the mask clips its corners.
    private let railFill = CALayer()
    /// The rounded-rect mask (card silhouette) applied to ``railLayer`` so the strip
    /// can never overflow the card's rounded corners.
    private let railMask = CAShapeLayer()

    /// The rail's source color, kept as a trait-aware `UIColor` so it can be
    /// re-resolved to a fresh `cgColor` for ``railFill`` on every layout / trait
    /// change (a `cgColor` handed to a layer is trait-snapshotted and would
    /// otherwise linger as a stale variant).
    private var railColorSource: UIColor = .clear

    /// The pluggable content region: fills the card from just past the left rail to
    /// the trailing edge, inset by ``contentInsets``. Adopting cells add their own
    /// subviews here and lay them out — the card does not.
    let contentView = UIView()

    /// Inset applied to ``contentView`` inside the card (the rail width is added to
    /// the LEADING side on top of this). Set BEFORE first layout by the adopting cell
    /// (defaults to a symmetric small inset that suits the agenda row; the denser
    /// timeline block overrides it).
    var contentInsets: UIEdgeInsets = UIEdgeInsets(
        top: Spacing.md, left: Spacing.md, bottom: Spacing.md, right: Spacing.md
    ) {
        didSet { setNeedsLayout() }
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Builds the static card chrome once. Fill/border/shadow/rail colors are
    /// supplied per-theme in ``applyChrome(theme:fillColor:railColor:)``; content is
    /// owned by the adopting cell via ``contentView``.
    private func setUp() {
        layer.cornerRadius = Radius.card
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        // The card is NOT clipped so the shadow shows; the left rail is instead
        // clipped to the card silhouette by its own mask.
        clipsToBounds = false

        // The content region fills the card up to the trailing edge; it is manually
        // framed in `layoutSubviews` (not Auto-Layout-pinned) so adopting cells stay
        // free to frame OR constrain their own children inside it.
        addSubview(contentView)

        // The left rail: a full-height strip clipped to the card's rounded rect. The
        // container spans the whole card so the mask shares the card's coordinate
        // space; the fill is the leading `railWidth` slice.
        railMask.fillColor = UIColor.white.cgColor
        railLayer.mask = railMask
        railLayer.addSublayer(railFill)
        layer.addSublayer(railLayer)
    }

    // MARK: - Configuration

    /// Applies the CUE — Clean floating-card chrome: `fillColor` background, the
    /// theme's hairline border, the soft `restShadow*` floating shadow, and the
    /// full-height LEFT rail painted `railColor`. Called by adopting cells from their
    /// own `applyTheme`, so the card never resolves color itself.
    func applyChrome(theme: CalendarTheme, fillColor: UIColor, railColor: UIColor) {
        backgroundColor = fillColor
        layer.borderColor = theme.border.cgColor
        layer.shadowColor = theme.textPrimary.cgColor
        layer.shadowRadius = theme.restShadowRadius
        layer.shadowOffset = theme.restShadowOffset
        layer.shadowOpacity = theme.restShadowOpacity
        railColorSource = railColor
        setNeedsLayout()
    }

    // MARK: - Trait changes

    /// Re-resolves the rail color against the current traits so the `cgColor` handed
    /// to ``railFill`` never lingers as a stale (e.g. dark-variant) snapshot.
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        setNeedsLayout()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        // Explicit shadow path (rounded rect matching the card bounds + radius) so
        // the soft floating shadow doesn't force an offscreen render pass on the
        // perf-sensitive timeline / scrolling list. Recomputed every pass to track
        // the card's changing per-duration / per-row height.
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: Radius.card).cgPath

        rebuildRail()

        // The content region fills the card from just past the left rail to the
        // trailing edge, inset by `contentInsets`.
        let leadingInset = contentInsets.left + Self.railWidth
        let trailingInset = contentInsets.right
        let contentX = leadingInset
        let contentWidth = max(bounds.width - leadingInset - trailingInset, 0)
        let contentY = contentInsets.top
        let contentHeight = max(bounds.height - contentInsets.top - contentInsets.bottom, 0)
        contentView.frame = CGRect(
            x: contentX, y: contentY, width: contentWidth, height: contentHeight
        )
    }

    /// (Re)frames the full-height left rail and its rounded-rect mask from the
    /// settled bounds, and repaints the fill with the trait-resolved rail color. All
    /// inside an implicit-animation-free transaction so an offscreen snapshot can
    /// never catch the geometry or color mid-transition.
    private func rebuildRail() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        railLayer.frame = bounds
        railFill.frame = CGRect(x: 0, y: 0, width: Self.railWidth, height: bounds.height)
        railFill.backgroundColor = railColorSource.resolvedColor(with: traitCollection).cgColor
        railMask.frame = CGRect(origin: .zero, size: bounds.size)
        railMask.path = UIBezierPath(roundedRect: railMask.bounds, cornerRadius: Radius.card).cgPath
        CATransaction.commit()
    }
}
