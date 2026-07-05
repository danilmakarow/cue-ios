//
//  CueAppearance.swift
//  cue
//
//  Global UIKit-chrome appearance for the CUE — Clean design system. SwiftUI's
//  `.navigationTitle` (large + inline) renders through a UIKit navigation bar, and
//  there is no SwiftUI hook to set its title FONT — so the bar's title attributes
//  must be configured via `UINavigationBarAppearance`. Without this, every screen's
//  large/inline title falls back to the system sans; the design uses Source Serif 4
//  Bold (`Typography.serifFamily`) for large titles.
//
//  This is the one sanctioned `UINavigationBar.appearance()` mutation: it sets ONLY
//  the title fonts, leaving Liquid Glass background/material untouched (no
//  `configureWithOpaqueBackground`, no blur override — see CLAUDE.md "DO NOT
//  hand-roll Liquid Glass").
//

import SwiftUI
import UIKit

/// Configures global UIKit chrome that SwiftUI cannot reach — currently the
/// navigation-bar title fonts (serif large + inline titles). Idempotent: calling
/// `apply()` more than once re-applies the same attributes with no side effects, so
/// it is safe to call at app launch AND at the top of snapshot hosting.
enum CueAppearance {
    /// Applies the serif navigation-title fonts to every navigation bar. Sets
    /// `largeTitleTextAttributes` (Source Serif 4 Bold ≈34) and `titleTextAttributes`
    /// (≈17) on the standard / scrollEdge / compact appearances of the shared
    /// `UINavigationBar.appearance()` proxy, with tight negative tracking for the
    /// strict display look (matching the `Typography` display ramp). Idempotent.
    static func apply() {
        let largeFont = serifFont(size: 34, weight: .bold)
        let inlineFont = serifFont(size: 17, weight: .bold)

        let appearance = UINavigationBarAppearance()
        // Inherit the system's (Liquid Glass) background — only override fonts.
        appearance.configureWithDefaultBackground()
        appearance.largeTitleTextAttributes[.font] = largeFont
        appearance.largeTitleTextAttributes[.kern] = -0.7 as NSNumber
        appearance.titleTextAttributes[.font] = inlineFont

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
    }

    /// Resolves the bundled Source Serif 4 Bold display `UIFont` at `size`, falling
    /// back to the system serif design (then the plain system font) if the bundled
    /// face cannot be resolved (so titles are never invisible). `Typography.serifFamily`
    /// is the exact PostScript name of the Bold face, so we resolve by name directly —
    /// the weight is intrinsic to the face, so no weight trait is applied.
    private static func serifFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        if let postScriptFont = UIFont(name: Typography.serifFamily, size: size) {
            return postScriptFont
        }
        let system = UIFont.systemFont(ofSize: size, weight: weight)
        if let serifDescriptor = system.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: serifDescriptor, size: size)
        }
        return system
    }
}
