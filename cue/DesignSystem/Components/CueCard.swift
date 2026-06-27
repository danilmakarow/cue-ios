//
//  CueCard.swift
//  cue
//
//  A surface container that applies fill + radius + depth in one place, so cards
//  stop hand-rolling backgrounds and shadows. React analogy: a `<Card>` primitive.
//

import SwiftUI

/// A themed surface card. Defaults to the `surface` fill, a 10pt "cut sheet"
/// radius, and `.letterpress` depth (a 1px functional border + a hard warm
/// value-cut, no soft float). An optional `header` renders a `surfaceSunken`
/// strip across the top (a recessed title band) clipped to the card's radius.
struct CueCard<Header: View, Content: View>: View {
    @Environment(\.theme) private var theme

    private let padding: CGFloat
    private let radius: CGFloat
    private let depth: Depth
    private let background: Color?
    private let header: (() -> Header)?
    private let content: () -> Content

    /// A card with an optional recessed header strip.
    /// - Parameters:
    ///   - padding: inner padding of the content region (default `Spacing.lg`).
    ///   - radius: corner radius (default `Radius.card`, 10pt).
    ///   - depth: depth treatment (default `.letterpress`).
    ///   - background: override the `surface` fill when needed.
    ///   - header: optional sunken title strip rendered above the content.
    ///   - content: the card body.
    init(
        padding: CGFloat = Spacing.lg,
        radius: CGFloat = Radius.card,
        depth: Depth = .letterpress,
        background: Color? = nil,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.radius = radius
        self.depth = depth
        self.background = background
        self.header = header
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header {
                header()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, padding)
                    .padding(.vertical, Spacing.md)
                    .background(theme.surfaceSunken)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(theme.separator)
                            .frame(height: 1)
                    }
            }
            content()
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            background ?? theme.surface,
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
        // Clip the sunken header's corners to the card radius.
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .cueDepth(depth, radius: radius)
    }
}

// MARK: - Header-less convenience

extension CueCard where Header == EmptyView {
    /// A plain card with no header strip — the common case.
    init(
        padding: CGFloat = Spacing.lg,
        radius: CGFloat = Radius.card,
        depth: Depth = .letterpress,
        background: Color? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            padding: padding,
            radius: radius,
            depth: depth,
            background: background,
            header: { EmptyView() },
            content: content
        )
    }
}

// MARK: - Preview

#Preview("CueCard") {
    VStack(spacing: Spacing.xl) {
        CueCard {
            Text("A plain letterpress card — 10pt cut edge, 1px border, a hard warm value-cut beneath.")
                .cueText(.body)
        }
        CueCard {
            Text("Today")
                .cueText(.label)
        } content: {
            Text("Three tasks, one event. The header strip recesses into the sheet.")
                .cueText(.body)
        }
    }
    .padding(Spacing.xxl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(hex: 0xFFFFFF))
}
