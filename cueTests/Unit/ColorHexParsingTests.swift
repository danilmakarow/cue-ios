//
//  ColorHexParsingTests.swift
//  cueTests
//
//  Covers `Color.init?(hex string:)` — the parser that renders backend-persisted
//  group color hex strings. See `cue/DesignSystem/Theme.swift`.
//

import SwiftUI
import Testing
import UIKit
@testable import cue

struct ColorHexParsingTests {

    // MARK: - Valid input

    @Test func acceptsSixDigitHexWithLeadingHash() {
        #expect(Color(hex: "#E27921") != nil)
    }

    @Test func acceptsSixDigitHexWithoutLeadingHash() {
        #expect(Color(hex: "E27921") != nil)
    }

    @Test func acceptsLowercaseHexDigits() {
        #expect(Color(hex: "#e27921") != nil)
        #expect(Color(hex: "abcdef") != nil)
    }

    @Test func acceptsPureBlackAndWhite() {
        #expect(Color(hex: "#000000") != nil)
        #expect(Color(hex: "FFFFFF") != nil)
    }

    // MARK: - Whitespace / newline trimming

    @Test func trimsSurroundingWhitespace() {
        #expect(Color(hex: "  #E27921  ") != nil)
        #expect(Color(hex: "\tE27921") != nil)
    }

    @Test func trimsSurroundingNewlines() {
        #expect(Color(hex: "\nE27921\n") != nil)
        #expect(Color(hex: "#E27921\r\n") != nil)
    }

    // MARK: - Malformed: rejected (returns nil)

    @Test func rejectsEmptyString() {
        #expect(Color(hex: "") == nil)
    }

    @Test func rejectsWhitespaceOnlyString() {
        #expect(Color(hex: "   ") == nil)
    }

    @Test func rejectsBareHashWithNoDigits() {
        #expect(Color(hex: "#") == nil)
    }

    @Test func rejectsFiveHexChars() {
        #expect(Color(hex: "E2792") == nil)
        #expect(Color(hex: "#E2792") == nil)
    }

    @Test func rejectsSevenHexChars() {
        #expect(Color(hex: "E279211") == nil)
        #expect(Color(hex: "#E279211") == nil)
    }

    @Test func rejectsEightDigitHexWithAlphaChannel() {
        // #RRGGBBAA form is NOT supported — only 6 digits.
        #expect(Color(hex: "#E27921FF") == nil)
    }

    @Test func rejectsThreeDigitShorthand() {
        // CSS #FFF shorthand is explicitly NOT expanded.
        #expect(Color(hex: "#FFF") == nil)
        #expect(Color(hex: "FFF") == nil)
    }

    @Test func rejectsNonHexCharacters() {
        #expect(Color(hex: "#ZZZZZZ") == nil)
        #expect(Color(hex: "GGGGGG") == nil)
        #expect(Color(hex: "12345G") == nil)
    }

    @Test func rejectsInteriorWhitespace() {
        // Trimming only strips the ends; interior spaces break the length/parse.
        #expect(Color(hex: "E2 7921") == nil)
        #expect(Color(hex: "#E2 79 21") == nil)
    }

    @Test func rejectsDoubleHashPrefix() {
        // Only one leading '#' is dropped; the second makes it non-hex.
        #expect(Color(hex: "##E27921") == nil)
    }

    @Test func rejectsZeroXPrefixedLiteral() {
        // "0xE27921" is 8 chars and contains the non-hex 'x'.
        #expect(Color(hex: "0xE27921") == nil)
    }

    // MARK: - UInt32 packing path (exact channel verification)

    /// Resolves the parsed `Color` through `UIColor` to confirm the
    /// `(hex >> 16)/(>> 8)/& 0xFF` packing maps each pair to the right channel.
    @MainActor
    @Test func packsChannelsInRedGreenBlueOrder() throws {
        let parsed = try #require(Color(hex: "#E27921"))
        let uiColor = UIColor(parsed)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        let didResolve = uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #expect(didResolve)

        // 0xE2 = 226, 0x79 = 121, 0x21 = 33, each over 255.
        let tolerance: CGFloat = 1.0 / 255.0
        #expect(abs(red - 226.0 / 255.0) < tolerance)
        #expect(abs(green - 121.0 / 255.0) < tolerance)
        #expect(abs(blue - 33.0 / 255.0) < tolerance)
        #expect(abs(alpha - 1.0) < tolerance)
    }

    @MainActor
    @Test func hashPrefixedAndBareFormsProduceSameChannels() throws {
        let withHash = UIColor(try #require(Color(hex: "#466234")))
        let withoutHash = UIColor(try #require(Color(hex: "466234")))

        var firstRed: CGFloat = 0, firstGreen: CGFloat = 0, firstBlue: CGFloat = 0, firstAlpha: CGFloat = 0
        var secondRed: CGFloat = 0, secondGreen: CGFloat = 0, secondBlue: CGFloat = 0, secondAlpha: CGFloat = 0
        withHash.getRed(&firstRed, green: &firstGreen, blue: &firstBlue, alpha: &firstAlpha)
        withoutHash.getRed(&secondRed, green: &secondGreen, blue: &secondBlue, alpha: &secondAlpha)

        let tolerance: CGFloat = 1.0 / 255.0
        #expect(abs(firstRed - secondRed) < tolerance)
        #expect(abs(firstGreen - secondGreen) < tolerance)
        #expect(abs(firstBlue - secondBlue) < tolerance)
        #expect(abs(firstAlpha - secondAlpha) < tolerance)
    }

    @MainActor
    @Test func resolvedColorIsFullyOpaque() throws {
        let uiColor = UIColor(try #require(Color(hex: "#000000")))
        var white: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getWhite(&white, alpha: &alpha)
        #expect(abs(alpha - 1.0) < 1.0 / 255.0)
    }
}
