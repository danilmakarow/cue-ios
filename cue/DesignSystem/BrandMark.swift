//
//  BrandMark.swift
//  cue
//

import SwiftUI

// MARK: - BrandMark

/// The reusable Cue brand mark: a white magnifying glass on a warm "Traveler"
/// gradient tile — the same artwork as the iOS app icon, rendered from first-class
/// shapes so it scales crisply at any size.
///
/// Use this anywhere the Cue logo appears (splash, sign-in, about screens) and
/// keep the look consistent by never re-inlining an `Image(systemName:)` logo.
///
/// ```swift
/// BrandMark(size: 72)                                  // gradient tile + glass
/// BrandMark(size: 24, style: .monochrome(.secondary))  // flat glass, no tile
/// ```
struct BrandMark: View {
    // MARK: Nested types

    /// How the mark is coloured.
    enum Style: Equatable {
        /// Full brand artwork — white magnifying glass on the gradient tile.
        case tinted
        /// A single flat colour for just the glass (icons, monochrome contexts);
        /// the tile is omitted so it composes onto any backdrop.
        case monochrome(Color)
    }

    // MARK: Stored properties

    /// Rendered edge length in points. The mark is always square.
    let size: CGFloat
    /// Colour treatment. Defaults to the full tinted tile.
    var style: Style = .tinted

    // MARK: Body

    var body: some View {
        Canvas { context, canvasSize in
            BrandMarkRenderer.draw(in: &context, size: canvasSize, style: style)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Renderer

/// Pure drawing geometry for the brand mark, expressed against a unit square so
/// it can be reused at any size. Kept separate from the `View` so the same
/// proportions can be mirrored by the headless Core Graphics icon generator
/// (`Scripts/GenerateAppIcon.swift`) without sharing a live SwiftUI hierarchy.
///
/// Proportions mirror the source SVG (120pt viewBox):
///   tile corner 27 → 0.225 · side; lens centre (55, 53), radius 25;
///   handle (66, 64) → (87, 87); all strokes 9pt → 0.075 · side.
enum BrandMarkRenderer {
    // The Traveler gradient stops for the tile, top-left → bottom-right.
    private static let tileStops: [Gradient.Stop] = [
        .init(color: TravelerColor.aperol, location: 0.0),   // #C1521E burnt sienna
        .init(color: TravelerColor.orange, location: 0.35),  // #E27921 terracotta
        .init(color: TravelerColor.mimosa, location: 0.65),  // #F7B557 golden amber
        .init(color: Color(hex: 0x5197AA), location: 1.0),   // cool teal-slate
    ]

    /// Draws the magnifying-glass mark, filling the whole `size` square.
    ///
    /// In `.tinted` the tile is opaque and the glass is white; in `.monochrome`
    /// only the glass is drawn (transparent tile) so it composes onto any backdrop.
    static func draw(in context: inout GraphicsContext, size: CGSize, style: BrandMark.Style) {
        let side = min(size.width, size.height)
        let originX = (size.width - side) / 2
        let originY = (size.height - side) / 2

        /// Maps a unit-square point (0...1) to the centred drawing rect.
        func point(_ unitX: CGFloat, _ unitY: CGFloat) -> CGPoint {
            CGPoint(x: originX + unitX * side, y: originY + unitY * side)
        }
        /// Maps a unit length to points.
        func length(_ unit: CGFloat) -> CGFloat { unit * side }

        // Resolve the glass colour from the chosen style.
        let glassColor: Color
        switch style {
        case .tinted:
            glassColor = .white
            // Opaque gradient tile.
            let tileRect = CGRect(x: originX, y: originY, width: side, height: side)
            let tilePath = Path(roundedRect: tileRect, cornerRadius: length(0.225))
            context.fill(
                tilePath,
                with: .linearGradient(
                    Gradient(stops: tileStops),
                    startPoint: tileRect.origin,
                    endPoint: CGPoint(x: tileRect.maxX, y: tileRect.maxY)
                )
            )
        case .monochrome(let color):
            glassColor = color
        }

        // MARK: Magnifying glass

        // Lens ring.
        let lensCenter = point(0.458, 0.442)
        let lensRadius = length(0.208)
        let lensRect = CGRect(
            x: lensCenter.x - lensRadius,
            y: lensCenter.y - lensRadius,
            width: lensRadius * 2,
            height: lensRadius * 2
        )
        context.stroke(
            Path(ellipseIn: lensRect),
            with: .color(glassColor),
            lineWidth: length(0.075)
        )

        // Handle, from the lower-right of the ring outward.
        var handle = Path()
        handle.move(to: point(0.55, 0.533))
        handle.addLine(to: point(0.725, 0.725))
        context.stroke(
            handle,
            with: .color(glassColor),
            style: StrokeStyle(lineWidth: length(0.075), lineCap: .round)
        )
    }
}

// MARK: - Previews

#Preview("Tinted") {
    BrandMark(size: 160)
        .padding()
}

#Preview("Monochrome") {
    HStack(spacing: 24) {
        BrandMark(size: 80, style: .monochrome(TravelerColor.orange))
        BrandMark(size: 80, style: .monochrome(.primary))
    }
    .padding()
}

#Preview("On surface") {
    BrandMark(size: 200)
        .padding(40)
        .background(TravelerColor.cloud)
}
