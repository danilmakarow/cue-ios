//
//  BrandMark.swift
//  cue
//

import SwiftUI

// MARK: - BrandMark

/// The reusable Cue brand mark: a rounded calendar sheet with a clock badge,
/// echoing the `calendar.badge.clock` motif the app launched with but rendered
/// from first-class shapes so it scales crisply and matches the brand palette.
///
/// Use this anywhere the Cue logo appears (splash, sign-in, about screens) and
/// keep the look consistent by never re-inlining an `Image(systemName:)` logo.
///
/// ```swift
/// BrandMark(size: 72)                 // tinted, gradient fill
/// BrandMark(size: 24, style: .monochrome(.secondary))  // flat, single colour
/// ```
struct BrandMark: View {
    // MARK: Nested types

    /// How the mark is coloured.
    enum Style: Equatable {
        /// Full brand colours — blue gradient calendar on a peach rounded tile.
        case tinted
        /// A single flat colour for the whole mark (icons, monochrome contexts).
        case monochrome(Color)
    }

    // MARK: Stored properties

    /// Rendered edge length in points. The mark is always square.
    let size: CGFloat
    /// Colour treatment. Defaults to the full tinted palette.
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
enum BrandMarkRenderer {
    /// Ink tone for the mark's strokes and clock face on light backdrops.
    /// Not one of the four brand colours — a desaturated deep blue that reads
    /// as "almost black" while staying on-brand. Kept local to the mark since
    /// it isn't a shared `BrandPalette` token.
    private static let ink = Color(red: 0.149, green: 0.255, blue: 0.353)

    /// Draws the calendar-and-clock mark, filling the whole `size` square.
    ///
    /// The mark is *transparent* outside its shapes — callers that need an
    /// opaque tile (the app icon) paint a background first.
    static func draw(in context: inout GraphicsContext, size: CGSize, style: BrandMark.Style) {
        let side = min(size.width, size.height)
        let originX = (size.width - side) / 2
        let originY = (size.height - side) / 2

        // Resolve the four working colours from the chosen style.
        let calendarTop: Color
        let calendarBottom: Color
        let bindingColor: Color
        let clockFace: Color
        let clockInk: Color

        switch style {
        case .tinted:
            calendarTop = BrandPalette.skyBlue
            calendarBottom = BrandPalette.blue
            bindingColor = Self.ink
            clockFace = BrandPalette.warmYellow
            clockInk = Self.ink
        case .monochrome(let color):
            calendarTop = color
            calendarBottom = color
            bindingColor = color
            // Punch the clock face out of the calendar so the mark still reads
            // as a clock-on-calendar when flattened to one colour.
            clockFace = .clear
            clockInk = color
        }

        /// Maps a unit-square point (0...1) to the centred drawing rect.
        func point(_ unitX: CGFloat, _ unitY: CGFloat) -> CGPoint {
            CGPoint(x: originX + unitX * side, y: originY + unitY * side)
        }

        /// Maps a unit length to points.
        func length(_ unit: CGFloat) -> CGFloat { unit * side }

        // MARK: Calendar sheet

        let sheetRect = CGRect(
            x: point(0.16, 0.20).x,
            y: point(0.16, 0.20).y,
            width: length(0.68),
            height: length(0.64)
        )
        let sheetPath = Path(roundedRect: sheetRect, cornerRadius: length(0.10))

        switch style {
        case .tinted:
            context.fill(
                sheetPath,
                with: .linearGradient(
                    Gradient(colors: [calendarTop, calendarBottom]),
                    startPoint: CGPoint(x: sheetRect.minX, y: sheetRect.minY),
                    endPoint: CGPoint(x: sheetRect.maxX, y: sheetRect.maxY)
                )
            )
        case .monochrome:
            context.fill(sheetPath, with: .color(calendarBottom))
        }

        // Header band (the tear-off strip across the top of the sheet).
        if case .tinted = style {
            let headerRect = CGRect(
                x: sheetRect.minX,
                y: sheetRect.minY,
                width: sheetRect.width,
                height: length(0.16)
            )
            // Clip the band to the sheet's rounded top corners.
            context.drawLayer { layer in
                layer.clip(to: sheetPath)
                layer.fill(Path(headerRect), with: .color(bindingColor.opacity(0.92)))
            }
        }

        // MARK: Binding rings

        // Two little tabs poking above the sheet, like a spiral binding.
        let ringWidth = length(0.055)
        let ringHeight = length(0.13)
        let ringY = point(0, 0.115).y
        for ringUnitX in [CGFloat(0.36), CGFloat(0.64)] {
            let ringRect = CGRect(
                x: point(ringUnitX, 0).x - ringWidth / 2,
                y: ringY,
                width: ringWidth,
                height: ringHeight
            )
            context.fill(
                Path(roundedRect: ringRect, cornerRadius: ringWidth / 2),
                with: .color(bindingColor)
            )
        }

        // MARK: Clock badge

        // A clock sitting on the lower-right corner of the sheet.
        let clockCenter = point(0.70, 0.70)
        let clockRadius = length(0.20)
        let clockRect = CGRect(
            x: clockCenter.x - clockRadius,
            y: clockCenter.y - clockRadius,
            width: clockRadius * 2,
            height: clockRadius * 2
        )

        switch style {
        case .tinted:
            // Filled face with a ring, so it stands clear of the blue sheet.
            context.fill(Path(ellipseIn: clockRect), with: .color(clockFace))
            context.stroke(
                Path(ellipseIn: clockRect),
                with: .color(clockInk),
                lineWidth: length(0.035)
            )
        case .monochrome:
            // Knock the disc out of the sheet, then outline it, so a single
            // colour still shows a distinct clock.
            context.blendMode = .destinationOut
            context.fill(Path(ellipseIn: clockRect.insetBy(dx: length(0.02), dy: length(0.02))), with: .color(.black))
            context.blendMode = .normal
            context.stroke(
                Path(ellipseIn: clockRect),
                with: .color(clockInk),
                lineWidth: length(0.04)
            )
        }

        // Clock hands (pointing to ~10:10, the classic friendly time).
        var hands = Path()
        hands.move(to: clockCenter)
        hands.addLine(to: CGPoint(x: clockCenter.x, y: clockCenter.y - clockRadius * 0.58))
        hands.move(to: clockCenter)
        hands.addLine(to: CGPoint(x: clockCenter.x + clockRadius * 0.46, y: clockCenter.y + clockRadius * 0.20))
        context.stroke(
            hands,
            with: .color(clockInk),
            style: StrokeStyle(lineWidth: length(0.030), lineCap: .round, lineJoin: .round)
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
        BrandMark(size: 80, style: .monochrome(BrandPalette.blue))
        BrandMark(size: 80, style: .monochrome(.primary))
    }
    .padding()
}

#Preview("On peach tile") {
    BrandMark(size: 200)
        .padding(40)
        .background(BrandPalette.peach)
}
