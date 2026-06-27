#!/usr/bin/env swift
//
//  GenerateAppIcon.swift
//  cue — build-time tool (NOT part of the app target)
//
//  Renders the 1024×1024 App Store / home-screen icon headlessly with Core
//  Graphics + Core Text, mirroring `BrandMark`: a clay wax seal (irregular,
//  hand-pressed — never a clean circle) with a cream Fraunces "C" monogram on a
//  warm kraft field. The icon and the in-app mark stay visually identical.
//
//  The icon is fully opaque (iOS app icons must not have an alpha hole) and
//  full-bleed — iOS applies its own rounded-superellipse mask.
//
//  Usage:
//      swift Scripts/GenerateAppIcon.swift \
//          cue/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//
//  The bundled Fraunces font is located relative to the output path
//  (…/Resources/Fonts/Fraunces.ttf), so the script is cwd-independent. If the
//  font can't be loaded, a geometric "C" is drawn instead.
//

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Palette (mirror of the Kraft & Ink brand colors)

/// An sRGB colour expressed as 0...1 components.
struct RGBA {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    func cgColor(in space: CGColorSpace) -> CGColor {
        CGColor(colorSpace: space, components: [red, green, blue, alpha]) ?? .init(gray: 0, alpha: 1)
    }
}

enum Palette {
    static let kraft = RGBA(0.949, 0.910, 0.847)  // #F2E8D8 kraft canvas
    static let clay = RGBA(0.745, 0.290, 0.157)   // #BE4A28 wax-seal clay
    static let clayRim = RGBA(0.541, 0.184, 0.094) // #8A2F18 darker clay rim
    static let cream = RGBA(0.984, 0.961, 0.918)  // #FBF5EA cream monogram
}

let iconSize: CGFloat = 1024

// MARK: - Wax-seal geometry (mirror of WaxSealShape)

/// Builds the irregular, hand-pressed seal outline as a smooth closed blob from
/// jittered points — identical jitter to the in-app `WaxSealShape`.
func sealPath(center: CGPoint, radius: CGFloat) -> CGPath {
    let count = 16
    let jitter: [CGFloat] = [0.03, -0.045, 0.02, -0.03, 0.05, -0.02, 0.035, -0.05,
                             0.025, -0.035, 0.045, -0.025, 0.03, -0.04, 0.02, -0.03]
    let points: [CGPoint] = (0..<count).map { index in
        let angle = CGFloat(index) / CGFloat(count) * 2 * .pi
        let scaled = radius * (1 + jitter[index % jitter.count])
        return CGPoint(x: center.x + cos(angle) * scaled, y: center.y + sin(angle) * scaled)
    }
    func mid(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }
    let path = CGMutablePath()
    path.move(to: mid(points[count - 1], points[0]))
    for index in 0..<count {
        let next = (index + 1) % count
        path.addQuadCurve(to: mid(points[index], points[next]), control: points[index])
    }
    path.closeSubpath()
    return path
}

// MARK: - Monogram

/// Draws a centered "C" — Fraunces if `fontURL` loads, else a geometric arc.
func drawMonogram(in context: CGContext, center: CGPoint, colorSpace: CGColorSpace, fontURL: URL) {
    let cream = Palette.cream.cgColor(in: colorSpace)
    let fontSize = iconSize * 0.42

    if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor],
       let descriptor = descriptors.first {
        let font = CTFontCreateWithFontDescriptor(descriptor, fontSize, nil)
        let attributes = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: cream,
        ] as CFDictionary
        if let attributed = CFAttributedStringCreate(nil, "C" as CFString, attributes) {
            let line = CTLineCreateWithAttributedString(attributed)
            let bounds = CTLineGetBoundsWithOptions(line, [])
            context.textPosition = CGPoint(
                x: center.x - bounds.width / 2 - bounds.minX,
                y: center.y - bounds.height / 2 - bounds.minY
            )
            CTLineDraw(line, context)
            return
        }
    }

    // Fallback: a geometric "C" (an open ring missing a wedge on the right).
    FileHandle.standardError.write(Data("Fraunces not found — drawing geometric C.\n".utf8))
    context.setStrokeColor(cream)
    context.setLineWidth(iconSize * 0.058)
    context.setLineCap(.round)
    context.addArc(
        center: center,
        radius: iconSize * 0.17,
        startAngle: .pi * 0.30,
        endAngle: -.pi * 0.30,
        clockwise: false
    )
    context.strokePath()
}

// MARK: - Drawing

func drawIcon(in context: CGContext, colorSpace: CGColorSpace, fontURL: URL) {
    let fullRect = CGRect(x: 0, y: 0, width: iconSize, height: iconSize)

    // 1. Full-bleed kraft field.
    context.setFillColor(Palette.kraft.cgColor(in: colorSpace))
    context.fill(fullRect)

    let center = CGPoint(x: iconSize / 2, y: iconSize / 2)
    let radius = iconSize * 0.33

    // 2. Clay wax seal — fill + darker rim.
    let seal = sealPath(center: center, radius: radius)
    context.addPath(seal)
    context.setFillColor(Palette.clay.cgColor(in: colorSpace))
    context.fillPath()

    context.addPath(seal)
    context.setStrokeColor(Palette.clayRim.cgColor(in: colorSpace))
    context.setLineWidth(iconSize * 0.02)
    context.setLineJoin(.round)
    context.strokePath()

    // 3. Embossed inner ring (cream, faint).
    let inner = sealPath(center: center, radius: radius * 0.74)
    context.addPath(inner)
    context.setStrokeColor(Palette.cream.cgColor(in: colorSpace).copy(alpha: 0.32) ?? Palette.cream.cgColor(in: colorSpace))
    context.setLineWidth(iconSize * 0.012)
    context.strokePath()

    // 4. Cream "C" monogram.
    drawMonogram(in: context, center: center, colorSpace: colorSpace, fontURL: fontURL)
}

// MARK: - Render & write PNG

func renderPNG(to outputURL: URL, fontURL: URL) -> Bool {
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
        // Fully opaque, no alpha channel (iOS app icons must not have one).
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        FileHandle.standardError.write(Data("Failed to create bitmap context.\n".utf8))
        return false
    }

    context.interpolationQuality = .high
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    drawIcon(in: context, colorSpace: colorSpace, fontURL: fontURL)

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

// Locate the bundled Fraunces relative to the icon path:
// …/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png →
// …/Resources/Fonts/Fraunces.ttf
let fontURL = outputURL
    .deletingLastPathComponent()  // AppIcon.appiconset
    .deletingLastPathComponent()  // Assets.xcassets
    .deletingLastPathComponent()  // Resources
    .appendingPathComponent("Fonts/Fraunces.ttf")

try? FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

if renderPNG(to: outputURL, fontURL: fontURL) {
    print("Wrote \(Int(iconSize))×\(Int(iconSize)) icon → \(outputURL.path)")
    exit(0)
} else {
    exit(1)
}
