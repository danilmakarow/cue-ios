#!/usr/bin/env swift
//
//  GenerateAppIcon.swift
//  cue — build-time tool (NOT part of the app target)
//
//  Renders the 1024×1024 App Store / home-screen icon headlessly with Core
//  Graphics + ImageIO, mirroring the geometry of `BrandMark` /
//  `BrandMarkRenderer` so the icon and the in-app logo stay visually identical:
//  a white magnifying glass on a warm "Traveler" gradient.
//
//  The icon is fully opaque (iOS app icons must not have an alpha hole) and
//  full-bleed — iOS applies its own rounded-superellipse mask, so the gradient
//  fills the entire square with no baked-in corner radius.
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

// MARK: - Traveler palette (mirror of TravelerColor in Theme.swift)

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
    static let aperol = RGBA(0.7569, 0.3216, 0.1176) // #C1521E burnt sienna
    static let orange = RGBA(0.8863, 0.4745, 0.1294) // #E27921 terracotta
    static let mimosa = RGBA(0.9686, 0.7098, 0.3412) // #F7B557 golden amber
    static let teal = RGBA(0.3176, 0.5922, 0.6667)   // #5197AA cool teal-slate
    static let glass = RGBA(1.0, 1.0, 1.0)           // white magnifying glass
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

    // 1. Full-bleed Traveler gradient, top-left → bottom-right.
    if let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            Palette.aperol.cgColor(in: colorSpace),
            Palette.orange.cgColor(in: colorSpace),
            Palette.mimosa.cgColor(in: colorSpace),
            Palette.teal.cgColor(in: colorSpace),
        ] as CFArray,
        locations: [0, 0.35, 0.65, 1]
    ) {
        context.saveGState()
        context.addRect(fullRect)
        context.clip()
        context.drawLinearGradient(
            gradient,
            start: point(0, 0), // top-left
            end: point(1, 1),   // bottom-right
            options: []
        )
        context.restoreGState()
    } else {
        context.setFillColor(Palette.orange.cgColor(in: colorSpace))
        context.fill(fullRect)
    }

    // 2. Magnifying glass — white lens ring.
    let lensCenter = point(0.458, 0.442)
    let lensRadius = length(0.208)
    let lensRect = CGRect(
        x: lensCenter.x - lensRadius,
        y: lensCenter.y - lensRadius,
        width: lensRadius * 2,
        height: lensRadius * 2
    )
    context.setStrokeColor(Palette.glass.cgColor(in: colorSpace))
    context.setLineWidth(length(0.075))
    context.setLineCap(.round)
    context.strokeEllipse(in: lensRect)

    // 3. Handle, from the lower-right of the ring outward.
    context.beginPath()
    context.move(to: point(0.55, 0.533))
    context.addLine(to: point(0.725, 0.725))
    context.strokePath()
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
