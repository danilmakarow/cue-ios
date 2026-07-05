//
//  YearSyncOverlayView.swift
//  cue
//

import UIKit

/// A small, non-blocking floating "syncing" pill for the year overview: a Liquid
/// Glass capsule with a clay spinner and a "Syncing…" label. It signals that the
/// visible year is still filling its heatmap while the grid itself renders and
/// closes/zooms immediately behind it — so the scope never feels stalled.
///
/// Shown/hidden via ``setVisible(_:animated:)``. A short **show delay** means a
/// year whose months are already cached (its `ensureMonthSynced` fan-out returns
/// almost instantly) never flashes the spinner — only a genuinely slow sync
/// outlives the delay and reveals it.
///
/// Named `YearSyncOverlayView` (Year-scoped) and kept in the Year folder; it is a
/// dumb view the ``YearScopeViewController`` drives.
final class YearSyncOverlayView: UIView {

    /// How long a sync must outlive before the spinner appears — long enough that a
    /// cached (instant) year never flashes it, short enough that a real fetch shows
    /// it promptly.
    private static let showDelay: TimeInterval = 0.25

    private let glassContainer: UIView
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let titleLabel = UILabel()
    private let stack = UIStackView()
    private var theme: CalendarTheme?

    /// The delayed-show work item, so a `setVisible(false)` before the delay
    /// elapses cancels a spinner that would otherwise have flashed.
    private var pendingShow: DispatchWorkItem?
    private var isShown = false

    // MARK: - Init

    override init(frame: CGRect) {
        glassContainer = Self.makeGlassContainer()
        super.init(frame: frame)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Builds the pill: a glass-backed capsule wrapping a spinner + label stack.
    /// Starts hidden (alpha 0) and non-interactive — it never intercepts touches,
    /// so the grid underneath stays fully tappable/scrollable.
    private func setUp() {
        isUserInteractionEnabled = false
        alpha = 0

        glassContainer.translatesAutoresizingMaskIntoConstraints = false
        glassContainer.isUserInteractionEnabled = false
        addSubview(glassContainer)

        spinner.hidesWhenStopped = false
        spinner.startAnimating()
        spinner.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.text = String(localized: "calendar.year.syncing", defaultValue: "Syncing…")

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Spacing.sm
        stack.isUserInteractionEnabled = false
        stack.addArrangedSubview(spinner)
        stack.addArrangedSubview(titleLabel)

        let content = glassContainer.syncOverlayContentView ?? glassContainer
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            glassContainer.topAnchor.constraint(equalTo: topAnchor),
            glassContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Spacing.sm),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Spacing.sm),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Spacing.lg),
        ])

        // Warm value-shadow lift on the control itself (the glass clips its own).
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 1
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = bounds.height / 2
        glassContainer.layer.cornerRadius = radius
        glassContainer.layer.cornerCurve = .continuous
        glassContainer.clipsToBounds = true
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
    }

    // MARK: - Theming

    /// Applies colors: clay spinner + secondary label (matching the Today pill's
    /// warm value-shadow).
    func apply(theme: CalendarTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        spinner.color = theme.primary
        titleLabel.font = theme.label
        titleLabel.textColor = theme.textSecondary
        layer.shadowColor = theme.textPrimary.withAlphaComponent(0.10).cgColor
    }

    // MARK: - Visibility

    /// Shows the pill after ``showDelay`` (so cached/instant syncs never flash it)
    /// or hides it immediately, cancelling any pending delayed show.
    func setVisible(_ visible: Bool, animated: Bool) {
        pendingShow?.cancel()
        pendingShow = nil

        guard visible else {
            fade(to: false, animated: animated)
            return
        }
        guard !isShown else { return }

        let work = DispatchWorkItem { [weak self] in
            self?.pendingShow = nil
            self?.fade(to: true, animated: animated)
        }
        pendingShow = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.showDelay, execute: work)
    }

    /// Fades the pill in/out (hidden, not removed, so it never reflows content).
    private func fade(to visible: Bool, animated: Bool) {
        isShown = visible
        let apply = {
            self.alpha = visible ? 1 : 0
            self.transform = visible ? .identity : CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
        guard animated else { apply(); return }
        UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState]) {
            apply()
        }
    }

    // MARK: - Glass

    /// Builds the Liquid Glass capsule backing (mirrors ``DayJumpToTodayButton``).
    private static func makeGlassContainer() -> UIView {
        let effect = UIGlassEffect(style: .regular)
        return UIVisualEffectView(effect: effect)
    }
}

private extension UIView {
    /// The `contentView` to add subviews into when this is a `UIVisualEffectView`,
    /// otherwise `self`.
    var syncOverlayContentView: UIView? {
        (self as? UIVisualEffectView)?.contentView
    }
}
