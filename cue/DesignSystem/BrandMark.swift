//
//  BrandMark.swift
//  cue
//

import SwiftUI

// MARK: - BrandMark

/// The Cue brand mark: a clay wax seal with a cream IBM Plex Serif "C" monogram.
/// It shares the `WaxSealShape` blob with the in-app `WaxSeal` save mark, so the
/// logo and the app's "make it stick" voice are one idea — and it scales crisply
/// at any size. (The seal is no longer the task-done marker; completion now uses
/// `OliveCheck` and the commit motion lives in `RootsCommitView`.)
///
/// Brand colors are intentionally fixed (a logo is constant across themes), so
/// this is the one sanctioned place for brand color literals. The mark reads on
/// the white app canvas: the clay fill and darker rim carry their own contrast.
///
/// ```swift
/// BrandMark(size: 96)                                  // clay seal + cream C
/// BrandMark(size: 24, style: .monochrome(.secondary))  // flat single-color seal
/// ```
struct BrandMark: View {
    /// How the mark is coloured.
    enum Style: Equatable {
        /// Full brand artwork — clay seal, darker rim, cream monogram.
        case tinted
        /// A single flat colour — seal outline + monogram, transparent center,
        /// so it composes onto any backdrop.
        case monochrome(Color)
    }

    // Fixed brand palette.
    private static let clay = Color(hex: 0xBE4A28)
    private static let clayRim = Color(hex: 0x8A2F18)
    private static let cream = Color(hex: 0xFBF5EA)

    /// Rendered edge length in points. The mark is always square.
    let size: CGFloat
    /// Colour treatment. Defaults to the full tinted seal.
    var style: Style = .tinted

    var body: some View {
        ZStack {
            switch style {
            case .tinted:
                WaxSealShape()
                    .fill(Self.clay)
                WaxSealShape()
                    .stroke(Self.clayRim, lineWidth: size * 0.022)
                WaxSealShape()
                    .scale(0.74)
                    .stroke(Self.cream.opacity(0.35), lineWidth: size * 0.016)
                monogram(Self.cream)
            case .monochrome(let color):
                WaxSealShape()
                    .stroke(color, lineWidth: size * 0.03)
                monogram(color)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// The IBM Plex Serif "C" at the seal's center — ties the serif brand voice
    /// into the mark itself. Tracks `Typography.serifFamily`, so a future face
    /// swap flows here automatically.
    private func monogram(_ color: Color) -> some View {
        Text(verbatim: "C")
            .font(.custom(Typography.serifFamily, size: size * 0.46).weight(.semibold))
            .foregroundStyle(color)
    }
}

// MARK: - Previews

#Preview("Tinted") {
    BrandMark(size: 160)
        .padding()
}

#Preview("Monochrome") {
    HStack(spacing: 24) {
        BrandMark(size: 80, style: .monochrome(Color(hex: 0x5A3A24)))
        BrandMark(size: 80, style: .monochrome(.primary))
    }
    .padding()
}

#Preview("On surface") {
    // The brand seal sits on the white app canvas.
    BrandMark(size: 200)
        .padding(40)
        .background(Color(hex: 0xFFFFFF))
}
