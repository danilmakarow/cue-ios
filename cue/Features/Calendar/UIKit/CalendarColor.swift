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
/// When the occurrence has no group color (token `nil`/unrecognized) the rail
/// falls back to the theme's clay `primary` — the structural "open task" rail — so
/// an ungrouped item still reads as a deliberate mark, never a missing one.
enum CalendarColor {

    /// The rail / chip / dot color for `occurrence`: its resolved group color, or
    /// the theme's clay `primary` when the group is uncolored. The completion state
    /// is intentionally NOT folded in here — callers decide whether a done item
    /// switches to olive (the day timeline keeps the group rail and fades the card;
    /// the agenda spine flips to olive on done, per the Today/Day specs).
    static func rail(for occurrence: OccurrenceVM, theme: CalendarTheme) -> UIColor {
        resolved(occurrence.groupColorToken) ?? theme.primary
    }

    /// The resolved group color for `token`, or nil when absent/unrecognized.
    /// Exposed so a caller can branch on "has a group color at all".
    static func resolved(_ token: String?) -> UIColor? {
        guard let color = TaskColorResolver.color(from: token) else { return nil }
        return UIColor(color)
    }
}
