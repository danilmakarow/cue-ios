//
//  SearchStoreTests.swift
//  cueTests
//
//  Exercises `SearchStore`'s debounce + cancellation + phase-reduction logic.
//  `SearchStore(api:)` takes an injected `APIClient`, so a `URLProtocol`-stubbed
//  `URLSession` is wired into `APIClient(session:)` and reaches `searchTasks`
//  without ever touching the network. The 250ms debounce makes raw `search()`
//  timing-sensitive, so result-mapping is covered deterministically via
//  `refresh()` (bypasses the debounce, awaitable), and `search()` is used for the
//  short-circuit + cancellation paths. Nothing here hits a real server.
//

import Foundation
import Testing
@testable import cue

// MARK: - URLProtocol stub

/// Process-wide stub config for ``SearchStubURLProtocol``. A test installs a
/// `responder`; the protocol reads it on `startLoading`. Held behind a lock so it
/// is safe to mutate from the test thread and read from URLSession's loading
/// thread. Named distinctly from the stub in `APIClientDecodingTests` to avoid a
/// same-module symbol clash.
private final class SearchStubConfig: @unchecked Sendable {
    static let shared = SearchStubConfig()

    private let lock = NSLock()
    private var stored: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?

    /// The active responder mapping a request to a canned status + body.
    var responder: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            stored = newValue
        }
    }
}

/// A `URLProtocol` answering every request from ``SearchStubConfig/shared``
/// instead of hitting the network. Registered on an ephemeral
/// `URLSessionConfiguration` so it never touches `URLSession.shared`.
private final class SearchStubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let responder = SearchStubConfig.shared.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let (response, data) = responder(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Fixtures & helpers

/// Builds an `APIClient` whose session routes through ``SearchStubURLProtocol``
/// and whose responder answers any request with the given `respond` closure.
/// Token provider is fixed to `nil` so no keychain / bridge state leaks in.
@Sendable private func makeStubbedClient(
    respond: @escaping @Sendable (URLRequest) -> (HTTPURLResponse, Data)
) -> APIClient {
    SearchStubConfig.shared.responder = respond

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [SearchStubURLProtocol.self]
    let session = URLSession(configuration: configuration)

    guard let baseURL = URL(string: "https://stub.invalid") else {
        fatalError("Static stub URL is valid.")
    }
    return APIClient(baseURL: baseURL, session: session, tokenProvider: { nil })
}

/// Convenience: a client that returns the given status + raw body for any
/// request, regardless of the query.
@Sendable private func makeStubbedClient(status: Int, body: String) -> APIClient {
    makeStubbedClient { request in
        let response = HTTPURLResponse(
            url: request.url ?? URL(fileURLWithPath: "/"),
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )
        guard let response else {
            return (HTTPURLResponse(), Data())
        }
        return (response, Data(body.utf8))
    }
}

/// A single `TaskSearchResultDTO` JSON object with the given title + id, built so
/// the decoder (lenient ISO-8601) accepts every field.
private func resultJSON(taskId: String, title: String) -> String {
    """
    {
      "taskId": "\(taskId)",
      "calendarId": "cal-1",
      "groupId": null,
      "groupColorHex": null,
      "title": "\(title)",
      "notes": null,
      "startAt": "2026-06-02T14:00:00Z",
      "endAt": null,
      "isAllDay": false,
      "timezone": "UTC",
      "isRecurring": false
    }
    """
}

/// A JSON array body for `GET /tasks/search` carrying the given hit objects.
private func resultsArrayJSON(_ objects: [String]) -> String {
    "[\(objects.joined(separator: ","))]"
}

/// Reads `q` off the request's URL query — used by the supersession test to
/// branch distinct payloads per query.
private func queryValue(from request: URLRequest) -> String? {
    guard
        let url = request.url,
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else {
        return nil
    }
    return components.queryItems?.first(where: { $0.name == "q" })?.value
}

/// Builds a 200 JSON response for the given body string + request.
private func okResponse(for request: URLRequest, body: String) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
        url: request.url ?? URL(fileURLWithPath: "/"),
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "application/json"]
    )
    guard let response else {
        return (HTTPURLResponse(), Data())
    }
    return (response, Data(body.utf8))
}

// MARK: - Tests

/// All cases inject a stubbed `URLSession` into `APIClient`; the real network is
/// never reached.
@MainActor
@Suite(.serialized)
struct SearchStoreTests {
    // MARK: Short-circuit (idle)

    @Test func emptyQueryShortCircuitsToIdle() async {
        let store = SearchStore(api: makeStubbedClient(
            status: 200,
            body: resultsArrayJSON([resultJSON(taskId: "t1", title: "Buy milk")])
        ))

        store.search(query: "", groupId: nil)

        #expect(store.phase == .idle)
    }

    @Test func whitespaceOnlyQueryShortCircuitsToIdle() async {
        let store = SearchStore(api: makeStubbedClient(
            status: 200,
            body: resultsArrayJSON([resultJSON(taskId: "t1", title: "Buy milk")])
        ))

        store.search(query: "   \n\t ", groupId: nil)

        #expect(store.phase == .idle)
    }

    @Test func emptyQueryCancelsInFlightWorkAndStaysIdle() async {
        // A non-empty query schedules a debounced task; a follow-up empty query
        // must cancel it and short-circuit to .idle. After the debounce window
        // elapses, the cancelled task must NOT resolve into a results phase.
        let store = SearchStore(api: makeStubbedClient(
            status: 200,
            body: resultsArrayJSON([resultJSON(taskId: "t1", title: "Buy milk")])
        ))

        store.search(query: "milk", groupId: nil)
        #expect(store.phase == .loading)

        store.search(query: "", groupId: nil)
        #expect(store.phase == .idle)

        // Wait well past the 250ms debounce: the cancelled task must not flip it.
        try? await Task.sleep(nanoseconds: 500_000_000)
        #expect(store.phase == .idle)
    }

    // MARK: Loading state on search()

    @Test func nonEmptyQuerySetsLoadingImmediately() async {
        let store = SearchStore(api: makeStubbedClient(
            status: 200,
            body: resultsArrayJSON([resultJSON(taskId: "t1", title: "Buy milk")])
        ))

        store.search(query: "milk", groupId: nil)

        // Synchronous: `search()` sets .loading before the debounced Task runs.
        #expect(store.phase == .loading)
    }

    // MARK: refresh() — deterministic result mapping

    @Test func refreshSetsLoadingThenResolvesToResults() async {
        let store = SearchStore(api: makeStubbedClient(
            status: 200,
            body: resultsArrayJSON([
                resultJSON(taskId: "t1", title: "Buy milk"),
                resultJSON(taskId: "t2", title: "Buy bread")
            ])
        ))

        await store.refresh(query: "buy", groupId: nil)

        guard case .results(let hits) = store.phase else {
            Issue.record("Expected .results, got \(store.phase)")
            return
        }
        #expect(hits.count == 2)
        #expect(hits.first?.taskId == "t1")
        #expect(hits.first?.title == "Buy milk")
    }

    @Test func refreshWithZeroHitsResolvesToEmpty() async {
        let store = SearchStore(api: makeStubbedClient(
            status: 200,
            body: resultsArrayJSON([])
        ))

        await store.refresh(query: "nothing-matches", groupId: nil)

        #expect(store.phase == .empty)
    }

    @Test func refreshWithEmptyQueryShortCircuitsToIdle() async {
        let store = SearchStore(api: makeStubbedClient(
            status: 200,
            body: resultsArrayJSON([resultJSON(taskId: "t1", title: "Buy milk")])
        ))

        await store.refresh(query: "   ", groupId: nil)

        #expect(store.phase == .idle)
    }

    @Test func refreshTrimsQueryBeforeSearching() async {
        // A surrounding-whitespace query is non-empty after trimming, so it must
        // resolve to results, not short-circuit to idle.
        let store = SearchStore(api: makeStubbedClient(
            status: 200,
            body: resultsArrayJSON([resultJSON(taskId: "t1", title: "Buy milk")])
        ))

        await store.refresh(query: "  milk  ", groupId: nil)

        guard case .results(let hits) = store.phase else {
            Issue.record("Expected .results, got \(store.phase)")
            return
        }
        #expect(hits.count == 1)
    }

    // MARK: Error mapping

    @Test func failedRequestMapsToFailedPhase() async {
        let store = SearchStore(api: makeStubbedClient(
            status: 500,
            body: #"{"statusCode":500,"message":"boom","error":"Internal Server Error"}"#
        ))

        await store.refresh(query: "milk", groupId: nil)

        guard case .failed(let message) = store.phase else {
            Issue.record("Expected .failed, got \(store.phase)")
            return
        }
        #expect(message.isEmpty == false)
    }

    @Test func decodingErrorMapsToFailedPhase() async {
        // A 200 whose body is not a `[TaskSearchResultDTO]` surfaces as a decoding
        // error, which the store folds into .failed (not .empty / .results).
        let store = SearchStore(api: makeStubbedClient(status: 200, body: "not-json"))

        await store.refresh(query: "milk", groupId: nil)

        guard case .failed = store.phase else {
            Issue.record("Expected .failed, got \(store.phase)")
            return
        }
    }

    // MARK: reset()

    @Test func resetReturnsToIdleFromResults() async {
        let store = SearchStore(api: makeStubbedClient(
            status: 200,
            body: resultsArrayJSON([resultJSON(taskId: "t1", title: "Buy milk")])
        ))

        await store.refresh(query: "milk", groupId: nil)
        guard case .results = store.phase else {
            Issue.record("Precondition: expected .results before reset, got \(store.phase)")
            return
        }

        store.reset()

        #expect(store.phase == .idle)
    }

    @Test func resetCancelsPendingSearch() async {
        // reset() must cancel a scheduled debounced search so it never resolves.
        let store = SearchStore(api: makeStubbedClient(
            status: 200,
            body: resultsArrayJSON([resultJSON(taskId: "t1", title: "Buy milk")])
        ))

        store.search(query: "milk", groupId: nil)
        #expect(store.phase == .loading)

        store.reset()
        #expect(store.phase == .idle)

        // Past the debounce window: the cancelled task must not flip the phase.
        try? await Task.sleep(nanoseconds: 500_000_000)
        #expect(store.phase == .idle)
    }

    // MARK: Supersession / cancellation

    @Test func supersededSearchResolvesOnlyLatestQuery() async {
        // Two rapid `search()` calls: the responder returns a payload whose hit
        // title echoes the `q` query value, so we can tell which query won. The
        // older task is cancelled (and guarded by `!Task.isCancelled` after the
        // await), so only the latest ("second") query resolves into phase.
        let store = SearchStore(api: makeStubbedClient { request in
            let query = queryValue(from: request) ?? "unknown"
            let body = resultsArrayJSON([resultJSON(taskId: query, title: query)])
            return okResponse(for: request, body: body)
        })

        store.search(query: "first", groupId: nil)
        store.search(query: "second", groupId: nil)
        #expect(store.phase == .loading)

        // Let the debounce + request resolve for the surviving (latest) task.
        try? await Task.sleep(nanoseconds: 600_000_000)

        guard case .results(let hits) = store.phase else {
            Issue.record("Expected .results for the latest query, got \(store.phase)")
            return
        }
        #expect(hits.count == 1)
        #expect(hits.first?.taskId == "second")
        #expect(hits.first?.title == "second")
    }
}
