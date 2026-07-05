//
//  TaskColorResolverTests.swift
//  cueTests
//
//  Unit tests for `TaskColorResolver.color(from:)` preset + hex resolution,
//  paired with the `Color(hex:)` string initializer it falls through to.
//
//  Color equality is unreliable across SwiftUI's internal representations, so
//  these tests assert only presence (non-nil) for valid inputs and absence
//  (nil) for invalid ones — never that two `Color` values are equal.
//

import SwiftUI
import Testing
@testable import cue

@MainActor
struct TaskColorResolverTests {
    /// Every preset name the backend may send on the wire (the 11 `TaskColor`
    /// presets mirrored in `TaskColorResolver.presets`).
    private static let presetNames = [
        "RED", "ORANGE", "YELLOW", "GREEN", "TEAL",
        "BLUE", "INDIGO", "PURPLE", "PINK", "BROWN", "GRAY",
    ]

    // MARK: - nil token

    @Test func returnsNilForNilToken() {
        #expect(TaskColorResolver.color(from: nil) == nil)
    }

    // MARK: - Presets

    @Test func resolvesAllElevenPresets() {
        for name in Self.presetNames {
            #expect(
                TaskColorResolver.color(from: name) != nil,
                "preset \(name) should resolve to a non-nil Color"
            )
        }
    }

    @Test func resolvesPresetCaseInsensitively() {
        #expect(TaskColorResolver.color(from: "BLUE") != nil)
        #expect(TaskColorResolver.color(from: "blue") != nil)
        #expect(TaskColorResolver.color(from: "Blue") != nil)
        #expect(TaskColorResolver.color(from: "bLuE") != nil)
    }

    @Test func trimsSurroundingWhitespaceFromPreset() {
        #expect(TaskColorResolver.color(from: " Blue ") != nil)
        #expect(TaskColorResolver.color(from: "\tGREEN\n") != nil)
        #expect(TaskColorResolver.color(from: "  red  ") != nil)
    }

    // MARK: - Hex fallthrough

    @Test func fallsThroughToHexWithHashPrefix() {
        #expect(TaskColorResolver.color(from: "#E27921") != nil)
    }

    @Test func fallsThroughToHexWithoutHashPrefix() {
        #expect(TaskColorResolver.color(from: "E27921") != nil)
    }

    @Test func resolvesHexCaseInsensitivelyAndTrimmed() {
        #expect(TaskColorResolver.color(from: "#abcdef") != nil)
        #expect(TaskColorResolver.color(from: "  #ABCDEF  ") != nil)
    }

    // MARK: - Unrecognized tokens

    @Test func returnsNilForNonPresetNonHexWord() {
        #expect(TaskColorResolver.color(from: "NOTACOLOR") == nil)
    }

    @Test func returnsNilForOutOfRangeHexDigits() {
        // 'G' is not a valid hex digit, so UInt32(_, radix: 16) fails.
        #expect(TaskColorResolver.color(from: "#GGGGGG") == nil)
    }

    @Test func returnsNilForTooShortHex() {
        #expect(TaskColorResolver.color(from: "#12345") == nil)
        #expect(TaskColorResolver.color(from: "12345") == nil)
    }

    @Test func returnsNilForEmptyAndWhitespaceOnly() {
        #expect(TaskColorResolver.color(from: "") == nil)
        #expect(TaskColorResolver.color(from: "   ") == nil)
    }

    // MARK: - Paired Color(hex:) string initializer

    @Test func colorHexInitAcceptsValidSixDigitHex() {
        #expect(Color(hex: "#E27921") != nil)
        #expect(Color(hex: "E27921") != nil)
    }

    @Test func colorHexInitTrimsWhitespace() {
        #expect(Color(hex: "  #E27921  ") != nil)
    }

    @Test func colorHexInitRejectsWrongLength() {
        #expect(Color(hex: "#12345") == nil)
        #expect(Color(hex: "12345") == nil)
        #expect(Color(hex: "#1234567") == nil)
    }

    @Test func colorHexInitRejectsNonHexDigits() {
        #expect(Color(hex: "#GGGGGG") == nil)
        #expect(Color(hex: "ZZZZZZ") == nil)
    }

    @Test func colorHexInitRejectsEmpty() {
        #expect(Color(hex: "") == nil)
    }
}
