//
//  CueBadge.swift
//  cue
//
//  A small rubber-stamp status mark in the receipt voice (uppercase JetBrains
//  Mono). Semantic presence, not a rainbow: olive=done, brass=pending (dark INK
//  on it), ink=info/structure, brick=blocked, gray=neutral. Clay is reserved for
//  the seal / decisive CTA / now-line — a badge is NEVER clay.
//

import SwiftUI

/// The semantic tone of a `CueBadge`. Each tone maps to a single theme role for
/// the fill and a contrast-safe ink for the text.
enum CueBadgeTone {
    /// Olive — completed / positive.
    case done
    /// Brass — pending / draft. Carries DARK ink, never white.
    case pending
    /// Ink — structural / informational.
    case info
    /// Brick — blocked / failed (destructive register, not an action).
    case blocked
    /// Neutral gray — a quiet, non-semantic tag.
    case neutral
}

/// A receipt-voice status stamp. Selection is carried by tone, not iconography:
/// a filled badge reads as an inked stamp (tone fill + contrast ink); the
/// `outline` variant reads as an empty stamp (transparent fill + tone-colored
/// 1px border and text). Text is uppercased monospace so it sits in the
/// "recorded by the system" voice alongside IDs and dates.
struct CueBadge: View {
    @Environment(\.theme) private var theme

    private let text: String
    private let tone: CueBadgeTone
    private let outline: Bool

    /// - Parameters:
    ///   - text: the label, rendered uppercased.
    ///   - tone: the semantic tone (default `.neutral`).
    ///   - outline: when `true`, render a transparent fill with a tone-colored
    ///     border and text instead of a solid stamp.
    init(_ text: String, tone: CueBadgeTone = .neutral, outline: Bool = false) {
        self.text = text
        self.tone = tone
        self.outline = outline
    }

    /// The stamp fill (and, for the outline variant, the border + text color).
    private var toneColor: Color {
        switch tone {
        case .done: return theme.success
        case .pending: return theme.warning
        case .info: return theme.info
        case .blocked: return theme.danger
        case .neutral: return theme.surfaceSunken
        }
    }

    /// The ink placed on top of a solid `toneColor` fill. Brass `pending` demands
    /// dark ink (white fails on it); neutral gray reads with secondary ink; the
    /// rest carry white.
    private var inkColor: Color {
        switch tone {
        case .pending: return theme.textPrimary
        case .neutral: return theme.textSecondary
        case .done, .info, .blocked: return theme.onAccent
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
    }

    var body: some View {
        Text(text.uppercased())
            .cueText(.codeSmall)
            .foregroundStyle(outline ? toneColor : inkColor)
            .lineLimit(1)
            .padding(.vertical, Spacing.xxs)
            .padding(.horizontal, Spacing.sm - 1)
            .background(shape.fill(outline ? Color.clear : toneColor))
            .overlay(
                shape.strokeBorder(toneColor, lineWidth: outline ? 1 : 0)
            )
            .fixedSize()
    }
}

// MARK: - Preview

#Preview("CueBadge") {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        HStack(spacing: Spacing.sm) {
            CueBadge("Done", tone: .done)
            CueBadge("Pending", tone: .pending)
            CueBadge("Info", tone: .info)
            CueBadge("Blocked", tone: .blocked)
            CueBadge("Draft", tone: .neutral)
        }
        HStack(spacing: Spacing.sm) {
            CueBadge("Done", tone: .done, outline: true)
            CueBadge("Pending", tone: .pending, outline: true)
            CueBadge("Info", tone: .info, outline: true)
            CueBadge("Blocked", tone: .blocked, outline: true)
            CueBadge("Draft", tone: .neutral, outline: true)
        }
    }
    .padding(Spacing.xxl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(hex: 0xFFFFFF))
    .environment(\.theme, AppPalette.kraftInk.colors)
}
