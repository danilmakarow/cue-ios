//
//  DeepLinkTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct DeepLinkTests {
    /// Builds a `URL` from a string, failing the test if it can't be formed.
    private func url(_ string: String) throws -> URL {
        try #require(URL(string: string))
    }

    // MARK: - Happy paths

    @Test func parsesUniversalLink() throws {
        let link = DeepLink(url: try url("https://cue.ngrok.app/app/telegram/link?code=abc-123"))
        #expect(link == .telegramLink(code: "abc-123"))
    }

    @Test func parsesCustomScheme() throws {
        let link = DeepLink(url: try url("cue://telegram/link?code=abc-123"))
        #expect(link == .telegramLink(code: "abc-123"))
    }

    @Test func parsesUniversalLinkWithExtraQueryItems() throws {
        let link = DeepLink(url: try url("https://cue.ngrok.app/app/telegram/link?foo=bar&code=xyz"))
        #expect(link == .telegramLink(code: "xyz"))
    }

    // MARK: - Rejections

    @Test func rejectsMissingCode() throws {
        #expect(DeepLink(url: try url("https://cue.ngrok.app/app/telegram/link")) == nil)
        #expect(DeepLink(url: try url("cue://telegram/link")) == nil)
    }

    @Test func rejectsWrongPath() throws {
        #expect(DeepLink(url: try url("https://cue.ngrok.app/app/other?code=abc")) == nil)
        #expect(DeepLink(url: try url("cue://telegram/other?code=abc")) == nil)
    }

    @Test func rejectsBlankCode() throws {
        #expect(DeepLink(url: try url("https://cue.ngrok.app/app/telegram/link?code=")) == nil)
        #expect(DeepLink(url: try url("https://cue.ngrok.app/app/telegram/link?code=%20%20")) == nil)
        #expect(DeepLink(url: try url("cue://telegram/link?code=")) == nil)
    }

    @Test func rejectsUnknownSchemeAndHost() throws {
        // Right path but neither a recognized universal-link scheme nor the
        // custom scheme.
        #expect(DeepLink(url: try url("http://cue.ngrok.app/app/telegram/link?code=abc")) == nil)
        // Custom scheme but wrong host.
        #expect(DeepLink(url: try url("cue://other/link?code=abc")) == nil)
    }

    @Test func trimsSurroundingWhitespaceInCode() throws {
        let link = DeepLink(url: try url("cue://telegram/link?code=%20abc%20"))
        #expect(link == .telegramLink(code: "abc"))
    }
}
