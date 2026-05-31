#!/usr/bin/env swift
//
//  GenerateAppIcon.swift
//  cue — build-time tool (NOT part of the app target)
//
//  Renders the 1024×1024 App Store / home-screen icon headlessly with Core
//  Graphics + ImageIO, mirroring the geometry of `BrandMark` /
//  `BrandMarkRenderer` so the icon and the in-app logo stay visually identical.
//
//  The icon is fully opaque (iOS app icons must not have an alpha hole): the
//  background is filled with the brand peach before the mark is drawn on top.
//
//  Usage:
//      swift Scripts/GenerateAppIcon.swift \
//          cue/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//
//  If no output path is given, it writes ./AppIcon.png.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Brand palette (mirror of BrandPalette in BrandMark.swift)

/// An sRGB colour expressed as 0...1 components.
struct RGBA {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Builds a `CGColor` in the given sRGB space.
    func cgColor(in space: CGColorSpace) -> CGColor {
        CGColor(colorSpace: space, components: [red, green, blue, alpha]) ?? .init(gray: 0, alpha: 1)
    }
}

enum Palette {
    static let paleYellow = RGBA(1.0, 0.976, 0.824)   // #FFF9D2
    static let peach = RGBA(1.0, 0.922, 0.800)         // #FFEBCC
    static let lightBlue = RGBA(0.749, 0.867, 0.941)   // #BFDDF0
    static let mediumBlue = RGBA(0.549, 0.753, 0.922)  // #8CC0EB
    static let ink = RGBA(0.149, 0.255, 0.353)         // desaturated deep blue
}

// MARK: - Geometry helpers

let iconSize: CGFloat = 1024

/// Maps a unit-square coordinate (0...1) to icon pixels.
func point(_ unitX: CGFloat, _ unitY: CGFloat) -> CGPoint {
    // Core Graphics origin is bottom-left; the SwiftUI renderer uses top-left.
    // Flip Y so the drawing matches BrandMarkRenderer's top-left convention.
    CGPoint(x: unitX * iconSize, y: (1 - unitY) * iconSize)
}

/// Maps a unit length to icon pixels.
func length(_ unit: CGFloat) -> CGFloat { unit * iconSize }

// MARK: - Drawing

/// Draws the full opaque app icon into `context`.
func drawIcon(in context: CGContext, colorSpace: CGColorSpace) {
    let fullRect = CGRect(x: 0, y: 0, width: iconSize, height: iconSize)

    // 1. Opaque background — a soft peach→pale-yellow vertical wash.
    if let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            Palette.paleYellow.cgColor(in: colorSpace),
            Palette.peach.cgColor(in: colorSpace),
        ] as CFArray,
        locations: [0, 1]
    ) {
        context.saveGState()
        context.addRect(fullRect)
        context.clip()
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: iconSize),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
        context.restoreGState()
    } else {
        context.setFillColor(Palette.peach.cgColor(in: colorSpace))
        context.fill(fullRect)
    }

    // 2. Calendar sheet (rounded rect) with a blue gradient.
    let sheetRect = CGRect(
        x: length(0.16),
        y: length(1 - 0.20 - 0.64), // top at unitY 0.20, height 0.64 (flipped)
        width: length(0.68),
        height: length(0.64)
    )
    let sheetPath = CGPath(
        roundedRect: sheetRect,
        cornerWidth: length(0.10),
        cornerHeight: length(0.10),
        transform: nil
    )

    context.saveGState()
    context.addPath(sheetPath)
    context.clip()
    if let sheetGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            Palette.lightBlue.cgColor(in: colorSpace),
            Palette.mediumBlue.cgColor(in: colorSpace),
        ] as CFArray,
        locations: [0, 1]
    ) {
        context.drawLinearGradient(
            sheetGradient,
            start: CGPoint(x: sheetRect.minX, y: sheetRect.maxY),
            end: CGPoint(x: sheetRect.maxX, y: sheetRect.minY),
            options: []
        )
    }
    context.restoreGState()

    // 3. Header band across the top of the sheet, clipped to its rounded corners.
    context.saveGState()
    context.addPath(sheetPath)
    context.clip()
    let headerRect = CGRect(
        x: sheetRect.minX,
        y: sheetRect.maxY - length(0.16),
        width: sheetRect.width,
        height: length(0.16)
    )
    // Fully opaque: the bitmap has no alpha channel, so blend is meaningless here.
    context.setFillColor(Palette.ink.cgColor(in: colorSpace))
    context.fill(headerRect)
    context.restoreGState()

    // 4. Binding rings poking above the sheet.
    let ringWidth = length(0.055)
    let ringHeight = length(0.13)
    for ringUnitX in [CGFloat(0.36), CGFloat(0.64)] {
        let ringRect = CGRect(
            x: point(ringUnitX, 0).x - ringWidth / 2,
            y: point(0, 0.115).y - ringHeight, // top at unitY 0.115, grows downward in flipped space
            width: ringWidth,
            height: ringHeight
        )
        let ringPath = CGPath(
            roundedRect: ringRect,
            cornerWidth: ringWidth / 2,
            cornerHeight: ringWidth / 2,
            transform: nil
        )
        context.addPath(ringPath)
        context.setFillColor(Palette.ink.cgColor(in: colorSpace))
        context.fillPath()
    }

    // 5. Clock badge on the lower-right of the sheet.
    let clockCenter = point(0.70, 0.70)
    let clockRadius = length(0.20)
    let clockRect = CGRect(
        x: clockCenter.x - clockRadius,
        y: clockCenter.y - clockRadius,
        width: clockRadius * 2,
        height: clockRadius * 2
    )

    // Filled pale face.
    context.setFillColor(Palette.paleYellow.cgColor(in: colorSpace))
    context.fillEllipse(in: clockRect)
    // Ink ring.
    context.setStrokeColor(Palette.ink.cgColor(in: colorSpace))
    context.setLineWidth(length(0.035))
    context.strokeEllipse(in: clockRect)

    // 6. Clock hands at ~10:10.
    context.setStrokeColor(Palette.ink.cgColor(in: colorSpace))
    context.setLineWidth(length(0.030))
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.beginPath()
    // Minute hand (up).
    context.move(to: clockCenter)
    context.addLine(to: CGPoint(x: clockCenter.x, y: clockCenter.y + clockRadius * 0.58))
    // Hour hand (down-right). +X right; -Y in flipped space means downward on screen.
    context.move(to: clockCenter)
    context.addLine(to: CGPoint(x: clockCenter.x + clockRadius * 0.46, y: clockCenter.y - clockRadius * 0.20))
    context.strokePath()

    // 7. Centre pin.
    let pinRadius = length(0.018)
    let pinRect = CGRect(
        x: clockCenter.x - pinRadius,
        y: clockCenter.y - pinRadius,
        width: pinRadius * 2,
        height: pinRadius * 2
    )
    context.setFillColor(Palette.ink.cgColor(in: colorSpace))
    context.fillEllipse(in: pinRect)
}

// MARK: - Render & write PNG

/// Renders the icon and writes it as a PNG to `outputURL`. Returns false on any failure.
func renderPNG(to outputURL: URL) -> Bool {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        FileHandle.standardError.write(Data("Failed to create sRGB colour space.\n".utf8))
        return false
    }

    let bytesPerRow = Int(iconSize) * 4
    guard let context = CGContext(
        data: nil,
        width: Int(iconSize),
        height: Int(iconSize),
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        // iOS app icons must be fully opaque with NO alpha channel. `noneSkipLast`
        // makes Core Graphics ignore alpha entirely, so ImageIO writes an opaque
        // RGB PNG (PNG colour type 2) rather than RGBA.
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        FileHandle.standardError.write(Data("Failed to create bitmap context.\n".utf8))
        return false
    }

    context.interpolationQuality = .high
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    drawIcon(in: context, colorSpace: colorSpace)

    guard let image = context.makeImage() else {
        FileHandle.standardError.write(Data("Failed to snapshot CGImage.\n".utf8))
        return false
    }

    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        FileHandle.standardError.write(Data("Failed to create PNG destination.\n".utf8))
        return false
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        FileHandle.standardError.write(Data("Failed to finalize PNG.\n".utf8))
        return false
    }

    return true
}

// MARK: - Entry point

let arguments = CommandLine.arguments
let outputPath = arguments.count > 1 ? arguments[1] : "AppIcon.png"
let outputURL = URL(fileURLWithPath: outputPath)

// Ensure the parent directory exists.
try? FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

if renderPNG(to: outputURL) {
    print("Wrote \(Int(iconSize))×\(Int(iconSize)) icon → \(outputURL.path)")
    exit(0)
} else {
    exit(1)
}
