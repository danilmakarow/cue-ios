//
//  TaskColorResolver.swift
//  cue
//

import SwiftUI

/// Resolves a backend task/group color token into a SwiftUI `Color`.
///
/// A `color` / `groupColorHex` value from the API is EITHER a named `TaskColor`
/// preset (e.g. `"BLUE"`) OR a custom `#RRGGBB` hex — both are valid on the wire
/// (the backend stores the raw string and validates it as one of the two shapes).
/// Older callers resolved only hex via `Color(hex:)`; this resolver is the single
/// place that understands both, so every surface renders a preset the same way.
///
/// The 11 preset names mirror the backend `TaskColor` enum; each maps to a stock
/// system color so the palette tracks the platform's dynamic (light/dark) inks.
enum TaskColorResolver {
    /// The named presets the backend may send, mapped to their rendered color.
    /// Keyed by the exact uppercase wire token (`"RED"`, `"BLUE"`, …).
    private static let presets: [String: Color] = [
        "RED": .red,
        "ORANGE": .orange,
        "YELLOW": .yellow,
        "GREEN": .green,
        "TEAL": .teal,
        "BLUE": .blue,
        "INDIGO": .indigo,
        "PURPLE": .purple,
        "PINK": .pink,
        "BROWN": .brown,
        "GRAY": .gray,
    ]

    /// Resolves a raw color token to a `Color`, or `nil` when the token is `nil`
    /// or unrecognized (neither a known preset nor a valid `#RRGGBB` hex).
    ///
    /// Tries the preset table first (matched case-insensitively against the
    /// uppercase wire names), then falls back to `Color(hex:)` so a custom hex
    /// still resolves. The caller decides the fallback (e.g. `?? theme.primary`).
    ///
    /// - Parameter token: a `TaskColor` preset name or a `#RRGGBB` hex string.
    static func color(from token: String?) -> Color? {
        guard let token else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if let preset = presets[trimmed.uppercased()] {
            return preset
        }
        return Color(hex: trimmed)
    }
}
