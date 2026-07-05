//
//  TelegramSnapshotTests.swift
//  cueTests
//
//  Storybook-style snapshot suite for `ConnectTelegramView`.
//
//  IMPORTANT — how we reach the "not connected" form:
//  The screen renders entirely off `TelegramLinkStore.status`, which is
//  `private(set)` and starts at `.unknown` (→ a loading spinner). It only
//  advances to `.notConnected` after a successful `GET /assistant/link` that
//  returns `{ "linked": false }`. There is no public setter seam.
//
//  Rather than depend on a live backend (down in CI), we inject a
//  `TelegramLinkStore` built over an `APIClient` whose `URLSession` is wired to a
//  local `URLProtocol` stub returning `{ "linked": false }` for every request.
//  The view's `.task` fires `refreshStatus()`, the stub answers in-process, and
//  the status flips to `.notConnected` within the harness's runloop pump — so the
//  captured PNG is the unlinked code-entry form, deterministically and offline.
//
//  We override `ScreenHost.wrap`'s default `TelegramLinkStore()` by injecting our
//  stubbed store *after* `wrap` (last `.environment(_:)` wins).
//

import Foundation
import SwiftUI
import Testing
@testable import cue

@MainActor
struct TelegramSnapshotTests {
    /// In-process HTTP stub: answers every request with a fixed JSON body and
    /// 200 status, so the screen's `refreshStatus()` resolves locally with no
    /// network. The body is a `{ "linked": false }` `TelegramLinkStatusDTO`.
    private final class UnlinkedStubProtocol: URLProtocol {
        nonisolated(unsafe) static var responseBody = Data(#"{"linked":false}"#.utf8)

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func stopLoading() {}

        override func startLoading() {
            let response = HTTPURLResponse(
                url: request.url ?? URL(fileURLWithPath: "/"),
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
            if let response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            client?.urlProtocol(self, didLoad: Self.responseBody)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    /// Builds a `TelegramLinkStore` whose API client is backed by the in-process
    /// unlinked stub, so `refreshStatus()` resolves to `.notConnected`.
    private func unlinkedStore() -> TelegramLinkStore {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UnlinkedStubProtocol.self]
        let session = URLSession(configuration: configuration)
        let api = APIClient(session: session)
        return TelegramLinkStore(api: api)
    }

    /// Wraps `ConnectTelegramView` in a `NavigationStack` (its presenting sites
    /// supply one) through the full app environment, then re-injects the stubbed
    /// store so the not-connected form renders, and records the PNG.
    private func record(named name: String, prefilledCode: String = "") {
        let container = MockData.container()
        let screen = NavigationStack {
            ConnectTelegramView(prefilledCode: prefilledCode)
        }
        let hosted = ScreenHost.wrap(screen, container: container)
            .environment(unlinkedStore())
        #expect(SnapshotHarness.record(hosted, named: name) != nil)
    }

    /// Unlinked / code-entry default: the explanation card, "Open in Telegram"
    /// row, empty linking-code field, "Paste from Clipboard", and the disabled
    /// clay Connect CTA — the manual-open-from-Settings state (empty prefill).
    @Test
    func telegramUnlinked() {
        record(named: "telegram-unlinked")
    }
}
