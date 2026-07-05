//
//  TelegramLinkStoreTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

// MARK: - URLProtocol stub

/// A `URLProtocol` subclass that returns a queued, per-test response instead of
/// hitting the network. Each enqueued entry is consumed FIFO so a single test
/// can script a sequence of responses (status code + JSON body). Registered into
/// a dedicated `URLSession` config that the test-only `APIClient` is built with —
/// `URLProtocol`'s shared registry is process-global, so a config-scoped protocol
/// keeps the stub isolated to the client under test.
private final class TelegramStubURLProtocol: URLProtocol, @unchecked Sendable {
    /// One scripted reply: HTTP status + raw JSON body string.
    struct Stub {
        let statusCode: Int
        let body: String
    }

    /// FIFO queue of scripted replies, shared across the (short-lived) test.
    /// Guarded only by the single-threaded test execution model: each test sets
    /// it, runs, and the next test overwrites it.
    nonisolated(unsafe) static var queue: [Stub] = []

    /// Resets the queue between tests so a leftover reply can't bleed across.
    static func reset(_ stubs: [Stub]) {
        queue = stubs
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let client else { return }

        guard !Self.queue.isEmpty else {
            // No scripted reply left — surface a transport-style error.
            client.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }

        let stub = Self.queue.removeFirst()
        let url = request.url ?? URL(fileURLWithPath: "/")
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: Data(stub.body.utf8))
        client.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Tests

@MainActor
@Suite(.serialized)
struct TelegramLinkStoreTests {
    /// Builds an `APIClient` whose `URLSession` is backed by the stub protocol,
    /// with a fixed token so requests don't depend on the global auth bridge.
    private static func makeStore(_ stubs: [TelegramStubURLProtocol.Stub]) -> TelegramLinkStore {
        TelegramStubURLProtocol.reset(stubs)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TelegramStubURLProtocol.self]
        let session = URLSession(configuration: config)

        let baseURL = URL(string: "https://example.test") ?? URL(fileURLWithPath: "/")
        let api = APIClient(
            baseURL: baseURL,
            session: session,
            tokenProvider: { "test-token" }
        )
        return TelegramLinkStore(api: api)
    }

    /// `{ linked, telegramUsername, linkedAt }` JSON body helper.
    private static func statusBody(linked: Bool, username: String?, linkedAt: String?) -> String {
        let usernameJSON = username.map { "\"\($0)\"" } ?? "null"
        let linkedAtJSON = linkedAt.map { "\"\($0)\"" } ?? "null"
        return """
        { "linked": \(linked), "telegramUsername": \(usernameJSON), "linkedAt": \(linkedAtJSON) }
        """
    }

    // MARK: - status(from:) reducer via refreshStatus

    @Test func refreshStatusUnlinkedMapsToNotConnected() async {
        let store = Self.makeStore([
            .init(statusCode: 200, body: Self.statusBody(linked: false, username: nil, linkedAt: nil))
        ])

        await store.refreshStatus()

        #expect(store.status == .notConnected)
    }

    @Test func refreshStatusLinkedWithDetailsMapsToConnected() async {
        let store = Self.makeStore([
            .init(
                statusCode: 200,
                body: Self.statusBody(linked: true, username: "tony", linkedAt: "2026-06-28T10:00:00Z")
            )
        ])

        await store.refreshStatus()

        #expect(store.status == .connected(username: "tony", linkedAt: "2026-06-28T10:00:00Z"))
    }

    @Test func refreshStatusLinkedWithoutDetailsMapsToConnectedNils() async {
        let store = Self.makeStore([
            .init(statusCode: 200, body: Self.statusBody(linked: true, username: nil, linkedAt: nil))
        ])

        await store.refreshStatus()

        #expect(store.status == .connected(username: nil, linkedAt: nil))
    }

    @Test func refreshStatusFailureMapsToFailed() async {
        let store = Self.makeStore([
            .init(statusCode: 500, body: "{}")
        ])

        await store.refreshStatus()

        guard case .failed = store.status else {
            Issue.record("Expected .failed, got \(store.status)")
            return
        }
    }

    // MARK: - link(code:)

    @Test func linkSuccessUpdatesStatusAndReturnsTrue() async {
        let store = Self.makeStore([
            .init(
                statusCode: 200,
                body: Self.statusBody(linked: true, username: "tony", linkedAt: "2026-06-28T10:00:00Z")
            )
        ])

        let result = await store.link(code: "NONCE")

        #expect(result == true)
        #expect(store.status == .connected(username: "tony", linkedAt: "2026-06-28T10:00:00Z"))
        #expect(store.lastCodeRejected == false)
        #expect(store.isMutating == false)
    }

    @Test func linkInvalidCodeLatchesRejectionAndLeavesStatusUntouched() async {
        // GET first to establish a known prior status, then a 422 INVALID_LINK_CODE.
        let store = Self.makeStore([
            .init(statusCode: 200, body: Self.statusBody(linked: false, username: nil, linkedAt: nil)),
            .init(statusCode: 422, body: "{ \"code\": \"INVALID_LINK_CODE\", \"message\": \"Code expired\" }")
        ])

        await store.refreshStatus()
        #expect(store.status == .notConnected)

        let result = await store.link(code: "BAD")

        #expect(result == false)
        #expect(store.lastCodeRejected == true)
        // Status must NOT change on an invalid-code rejection.
        #expect(store.status == .notConnected)
        #expect(store.isMutating == false)
    }

    @Test func linkTransientFailureDoesNotLatchRejection() async {
        let store = Self.makeStore([
            .init(statusCode: 200, body: Self.statusBody(linked: false, username: nil, linkedAt: nil)),
            .init(statusCode: 500, body: "{}")
        ])

        await store.refreshStatus()

        let result = await store.link(code: "ANY")

        #expect(result == false)
        #expect(store.lastCodeRejected == false)
        // Prior status preserved on a transient failure.
        #expect(store.status == .notConnected)
        #expect(store.isMutating == false)
    }

    @Test func linkClearsPriorRejectionOnNewAttempt() async {
        // First attempt: invalid code latches lastCodeRejected. Second: a 422
        // non-INVALID_LINK_CODE body (transient class) should clear the latch on
        // entry and not re-set it.
        let store = Self.makeStore([
            .init(statusCode: 422, body: "{ \"code\": \"INVALID_LINK_CODE\", \"message\": \"nope\" }"),
            .init(statusCode: 500, body: "{}")
        ])

        _ = await store.link(code: "BAD")
        #expect(store.lastCodeRejected == true)

        _ = await store.link(code: "RETRY")
        #expect(store.lastCodeRejected == false)
    }

    // MARK: - unlink()

    @Test func unlinkSuccessSetsNotConnected() async {
        let store = Self.makeStore([
            .init(
                statusCode: 200,
                body: Self.statusBody(linked: true, username: "tony", linkedAt: "2026-06-28T10:00:00Z")
            ),
            .init(statusCode: 200, body: Self.statusBody(linked: false, username: nil, linkedAt: nil))
        ])

        await store.link(code: "NONCE")
        #expect(store.status == .connected(username: "tony", linkedAt: "2026-06-28T10:00:00Z"))

        await store.unlink()

        #expect(store.status == .notConnected)
        #expect(store.isMutating == false)
    }

    @Test func unlinkFailureLeavesStatusUntouched() async {
        let store = Self.makeStore([
            .init(
                statusCode: 200,
                body: Self.statusBody(linked: true, username: "tony", linkedAt: "2026-06-28T10:00:00Z")
            ),
            .init(statusCode: 500, body: "{}")
        ])

        await store.link(code: "NONCE")
        let connected = store.status

        await store.unlink()

        #expect(store.status == connected)
        #expect(store.isMutating == false)
    }

    // MARK: - clear() / clearCodeRejection()

    @Test func clearResetsToUnknownAndStopsMutating() async {
        let store = Self.makeStore([
            .init(statusCode: 200, body: Self.statusBody(linked: false, username: nil, linkedAt: nil))
        ])

        await store.refreshStatus()
        #expect(store.status == .notConnected)

        store.clear()

        #expect(store.status == .unknown)
        #expect(store.isMutating == false)
    }

    @Test func clearCodeRejectionFlipsLatchFalse() async {
        let store = Self.makeStore([
            .init(statusCode: 422, body: "{ \"code\": \"INVALID_LINK_CODE\", \"message\": \"nope\" }")
        ])

        _ = await store.link(code: "BAD")
        #expect(store.lastCodeRejected == true)

        store.clearCodeRejection()

        #expect(store.lastCodeRejected == false)
    }

    // MARK: - ConnectTelegramViewModel

    @Test func trimmedCodeStripsWhitespaceAndNewlines() {
        let viewModel = ConnectTelegramViewModel(prefilledCode: "  ABC123 \n")
        #expect(viewModel.trimmedCode == "ABC123")
    }

    @Test func canSubmitFalseForBlankCode() {
        let blank = ConnectTelegramViewModel(prefilledCode: "   \n\t")
        #expect(blank.canSubmit == false)

        let empty = ConnectTelegramViewModel()
        #expect(empty.canSubmit == false)
    }

    @Test func canSubmitTrueForNonBlankCode() {
        let viewModel = ConnectTelegramViewModel(prefilledCode: "  ABC  ")
        #expect(viewModel.canSubmit == true)
    }

    // NOTE: `ConnectTelegramViewModel.pasteFromClipboard()` reads
    // `UIPasteboard.general` and is UIKit/device-dependent (no deterministic
    // unit coverage without a host app), so it is intentionally not exercised here.
    //
    // NOTE: the `isMutating` re-entrancy guard (`guard !isMutating` in `link` /
    // `unlink`) is not unit-tested directly: all calls are `async` and awaited
    // serially in a test, so `isMutating` is always back to `false` between
    // awaits — there is no isolation-safe, deterministic seam to observe a
    // second call entering while the first is mid-flight (a concurrent race on
    // the shared stub queue would be flaky). The guard is covered by inspection
    // and the post-call `isMutating == false` assertions above.
}
