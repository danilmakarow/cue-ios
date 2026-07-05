//
//  CalendarColor.swift
//  cue
//

import SwiftUI
import UIKit

/// Resolves an occurrence's GROUP color token into the `UIColor` the UIKit
/// calendar scopes paint their rails / chips / dots with.
///
/// The wire token (`OccurrenceVM.groupColorToken`, off `OccurrenceDTO.groupColorHex`)
/// is EITHER a named `TaskColor` preset (`"BLUE"`) OR a `#RRGGBB` hex — both valid.
/// The single place that understands both shapes is the shared
/// ``TaskColorResolver`` (which returns a SwiftUI `Color`); this enum bridges that
/// resolved color into UIKit with `UIColor(_:)` so the day timeline blocks, agenda
/// rows, and month grid all key off ONE color source and render a group identically.
///
/// When the occurrence has no task **and** no group color (both tokens
/// `nil`/unrecognized) the rail falls back to the neutral gray
/// (``TaskColorResolver/neutral``) — so an uncolored item still reads as a
/// deliberate mark, never a missing one.
enum CalendarColor {

    /// The rail / chip / dot color for `occurrence`: its EFFECTIVE color
    /// (`task ?? group ?? gray`), resolved via
    /// ``TaskColorResolver/effectiveColor(taskToken:groupToken:)``. The completion
    /// state is intentionally NOT folded in here — callers decide whether a done
    /// item switches to olive (the day timeline keeps the group rail and fades the
    /// card; the agenda spine flips to olive on done, per the Today/Day specs).
    ///
    /// The `theme` parameter is retained for source compatibility with existing
    /// call sites; the effective color no longer depends on the theme's clay
    /// primary (the fallback is the neutral gray).
    static func rail(for occurrence: OccurrenceVM, theme: CalendarTheme) -> UIColor {
        effective(taskToken: occurrence.colorToken, groupToken: occurrence.groupColorToken)
    }

    /// The resolved GROUP (or any single) color for `token`, or nil when
    /// absent/unrecognized. Exposed so a caller can branch on "has a color at all".
    static func resolved(_ token: String?) -> UIColor? {
        guard let color = TaskColorResolver.color(from: token) else { return nil }
        return UIColor(color)
    }

    /// The EFFECTIVE rail / chip / dot color for a `(taskToken, groupToken)` pair:
    /// `task ?? group ?? gray`, bridged to `UIColor`. The single UIKit entry point
    /// mirroring ``TaskColorResolver/effectiveColor(taskToken:groupToken:)``; always
    /// returns a color (never nil), falling back to the neutral gray.
    static func effective(taskToken: String?, groupToken: String?) -> UIColor {
        UIColor(TaskColorResolver.effectiveColor(taskToken: taskToken, groupToken: groupToken))
    }
}
