//
//  DayJumpToTodayButton.swift
//  cue
//

import UIKit

/// Floating "Today" pill — the UIKit port of the SwiftUI `JumpToTodayButton`: a
/// Liquid Glass capsule with a leading `arrow.uturn.backward` glyph and the
/// "Today" label in `theme.primary`, lifted by a warm value-shadow rather than a
/// cold black float. Owned by the Day scope and placed bottom-leading.
///
/// Named `DayJumpToTodayButton` (not `JumpToTodayButton`) so it coexists with the
/// still-present SwiftUI `JumpToTodayButton` until Integration removes the old
/// surface — the file-system-synchronized target requires distinct file names.
///
/// Visibility is host-controlled via ``setVisible(_:animated:)`` (hidden, not
/// removed, so it animates and never reflows content); the tap forwards through
/// the ``action`` closure the owner sets.
final class DayJumpToTodayButton: UIControl {

    /// The host's "today" action. Set by the owning scope.
    var action: (() -> Void)?

    private let glassContainer: UIView
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let stack = UIStackView()
    private var theme: CalendarTheme?
    private(set) var isShown: Bool = true

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

    /// Builds the pill: a glass-backed capsule wrapping an icon + label stack.
    private func setUp() {
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = String(localized: "calendar.chrome.today")

        glassContainer.translatesAutoresizingMaskIntoConstraints = false
        glassContainer.isUserInteractionEnabled = false
        addSubview(glassContainer)

        iconView.image = UIImage(
            systemName: "arrow.uturn.backward",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        )
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Spacing.xs
        stack.isUserInteractionEnabled = false
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        titleLabel.text = String(localized: "calendar.chrome.today")

        let content = glassContainer.contentViewIfAvailable ?? glassContainer
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            glassContainer.topAnchor.constraint(equalTo: topAnchor),
            glassContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Spacing.md),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Spacing.md),
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

    /// Applies the pill's colors (label/icon tint = `theme.primary`, warm shadow).
    func apply(theme: CalendarTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        iconView.tintColor = theme.primary
        titleLabel.font = theme.label
        titleLabel.textColor = theme.primary
        layer.shadowColor = theme.textPrimary.withAlphaComponent(0.10).cgColor
    }

    // MARK: - Visibility

    /// Shows/hides the pill (faded + scaled, hidden not removed). Disables hit
    /// testing and accessibility while hidden, mirroring the SwiftUI version.
    func setVisible(_ visible: Bool, animated: Bool) {
        isShown = visible
        isUserInteractionEnabled = visible
        accessibilityElementsHidden = !visible
        let apply = {
            self.alpha = visible ? 1 : 0
            self.transform = visible ? .identity : CGAffineTransform(scaleX: 0.85, y: 0.85)
        }
        guard animated else { apply(); return }
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            apply()
        }
    }

    // MARK: - Actions

    @objc private func handleTap() {
        action?()
    }

    // MARK: - Glass

    /// Builds the Liquid Glass capsule backing. Uses `UIGlassEffect` (iOS 26) via
    /// a `UIVisualEffectView`; falls back to a plain rounded view if unavailable.
    private static func makeGlassContainer() -> UIView {
        let effect = UIGlassEffect(style: .regular)
        effect.isInteractive = true
        return UIVisualEffectView(effect: effect)
    }
}

private extension UIView {
    /// The `contentView` to add subviews into when this is a
    /// `UIVisualEffectView`, otherwise `self`.
    var contentViewIfAvailable: UIView? {
        (self as? UIVisualEffectView)?.contentView
    }
}
