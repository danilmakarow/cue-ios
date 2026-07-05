//
//  ColorTokenPicker.swift
//  cue
//
//  A reusable swatch grid for selecting a task/group color token, extracted from
//  the color card in `GroupEditSheet`. Reads/writes an optional token string: the
//  11 `TaskColorResolver` presets plus a "none / inherit" hollow swatch. Every
//  swatch resolves its ink through `TaskColorResolver` so what is stored is exactly
//  what ships to the API.
//

import SwiftUI

/// A grid (or horizontal rail) of color swatches bound to an optional token.
///
/// The bound value is `nil` for the "none / inherit" swatch, otherwise one of the
/// ``TaskColorResolver`` preset names (e.g. `"BLUE"`). Callers that already store a
/// custom `#RRGGBB` hex still round-trip: a hex not in the preset set simply won't
/// mark any preset selected, but selecting a preset overwrites it — which is the
/// intended editing behavior for the picker.
struct ColorTokenPicker: View {
    @Environment(\.theme) private var theme

    /// The selected color token; `nil` == none / inherit.
    @Binding var selection: String?
    /// When true (default) lays the swatches out in a wrapping grid; when false in
    /// a single horizontally-scrolling rail (the `GroupEditSheet` idiom).
    private let usesGrid: Bool

    /// The 11 named presets the backend accepts, in a stable display order. These
    /// mirror ``TaskColorResolver``'s preset table (the wire tokens), so the picker
    /// and the resolver never drift.
    private static let presetTokens: [String] = [
        "RED", "ORANGE", "YELLOW", "GREEN", "TEAL", "BLUE",
        "INDIGO", "PURPLE", "PINK", "BROWN", "GRAY",
    ]

    /// - Parameters:
    ///   - selection: the bound optional color token (`nil` == none / inherit).
    ///   - usesGrid: `true` for a wrapping grid (default), `false` for a horizontal rail.
    init(selection: Binding<String?>, usesGrid: Bool = true) {
        self._selection = selection
        self.usesGrid = usesGrid
    }

    var body: some View {
        if usesGrid {
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 6), spacing: Spacing.md) {
                swatches
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    swatches
                }
                .padding(.vertical, Spacing.xs)
                .padding(.horizontal, Spacing.xs)
            }
        }
    }

    /// The "none / inherit" swatch followed by every preset swatch.
    @ViewBuilder
    private var swatches: some View {
        swatch(token: nil)
        ForEach(Self.presetTokens, id: \.self) { token in
            swatch(token: token)
        }
    }

    /// One color swatch. `token == nil` is the "none / inherit" option, drawn as a
    /// hollow slashed chip; otherwise the token resolves to its ink via
    /// ``TaskColorResolver``. Selection is marked with a clay ring. Wrapped in a
    /// 44pt tap target.
    private func swatch(token: String?) -> some View {
        let isSelected = selection == token
        let fill = TaskColorResolver.color(from: token)
        return Button {
            selection = token
        } label: {
            Circle()
                .fill(fill ?? theme.surfaceSunken)
                .frame(width: 32, height: 32)
                .overlay {
                    if fill == nil {
                        Image(systemName: "slash.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(theme.border, lineWidth: 1)
                }
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(theme.primary, lineWidth: 2)
                            .padding(-4)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(token ?? String(localized: "colorPicker.none", defaultValue: "No color"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview("ColorTokenPicker") {
    struct Demo: View {
        @State private var gridSelection: String? = "BLUE"
        @State private var railSelection: String? = nil
        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text(verbatim: "Grid")
                    .cueText(.label)
                ColorTokenPicker(selection: $gridSelection)
                Text(verbatim: "Rail")
                    .cueText(.label)
                ColorTokenPicker(selection: $railSelection, usesGrid: false)
            }
            .padding(Spacing.xl)
        }
    }
    return Demo()
        .environment(\.theme, AppPalette.kraftInk.colors)
}
