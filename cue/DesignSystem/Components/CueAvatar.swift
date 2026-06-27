//
//  CueAvatar.swift
//  cue
//
//  A circular profile avatar — a decoded image when one is supplied, otherwise a
//  themed initials/glyph placeholder — ringed by a thin espresso (primary) border.
//  React analogy: an `<Avatar src? fallback>` primitive shared across features.
//

import SwiftUI

/// A circular avatar with a thin espresso border. Shows `image` when present,
/// otherwise a `person.fill` glyph on a sunken surface fill.
struct CueAvatar: View {
    @Environment(\.theme) private var theme

    private let image: UIImage?
    private let size: CGFloat

    /// - Parameters:
    ///   - image: the decoded avatar image, or `nil` to show the placeholder glyph.
    ///   - size: the circle's diameter in points (default 56).
    init(image: UIImage?, size: CGFloat = 56) {
        self.image = image
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
}
