//
//  CueAvatar.swift
//  cue
//
//  A circular profile avatar — a decoded image when one is supplied, else derived
//  initials, else a `person.fill` glyph — ringed by a thin clay (primary) border
//  on a sunken gray fill. React analogy: an `<Avatar src? name? fallback>`
//  primitive shared across features.
//

import SwiftUI

/// A circular avatar with a thin clay (primary) border. Resolves its content in
/// three tiers: the decoded `image` when present; otherwise derived initials from
/// `name`; otherwise a `person.fill` glyph. The placeholder tiers sit on the
/// sunken gray fill. Always circular regardless of source aspect.
struct CueAvatar: View {
    @Environment(\.theme) private var theme

    private let image: UIImage?
    private let name: String?
    private let size: CGFloat

    /// - Parameters:
    ///   - image: the decoded avatar image, or `nil` to fall through to initials/glyph.
    ///   - name: a display name to derive initials from when `image` is `nil`.
    ///     Pass `nil` (the default) to skip straight to the glyph placeholder.
    ///   - size: the circle's diameter in points (default 56).
    init(image: UIImage?, name: String? = nil, size: CGFloat = 56) {
        self.image = image
        self.name = name
        self.size = size
    }

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(.circle)
            .overlay {
                Circle().strokeBorder(theme.primary, lineWidth: 1.5)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let initials = Self.initials(from: name) {
            Circle()
                .fill(theme.surfaceSunken)
                .overlay {
                    // Serif initials, scaled to the diameter — keeps the brand
                    // voice on the placeholder without a fixed text role.
                    Text(initials)
                        .font(.custom(Typography.serifSemiboldFamily, size: size * 0.38))
                        .foregroundStyle(theme.textSecondary)
                }
        } else {
            Circle()
                .fill(theme.surfaceSunken)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.42))
                        .foregroundStyle(theme.textSecondary)
                }
        }
    }

    /// Derives up to two uppercased initials from a display name (first + last
    /// word). Returns `nil` when the name is missing or has no letters, so the
    /// caller falls through to the glyph.
    private static func initials(from name: String?) -> String? {
        guard let words = name?
            .split(whereSeparator: \.isWhitespace)
            .filter({ $0.contains(where: \.isLetter) }),
            let first = words.first?.first else { return nil }
        guard let last = words.count > 1 ? words.last?.first : nil else {
            return String(first).uppercased()
        }
        return "\(first)\(last)".uppercased()
    }
}

// MARK: - Preview

#Preview("CueAvatar") {
    HStack(spacing: Spacing.lg) {
        CueAvatar(image: nil, name: "Tony Stark")
        CueAvatar(image: nil, name: "Jarvis")
        CueAvatar(image: nil)
    }
    .padding(Spacing.xxl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(hex: 0xFFFFFF))
    .environment(\.theme, AppPalette.kraftInk.colors)
}
