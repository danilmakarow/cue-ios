//
//  MorningBriefStoreTests.swift
//  cueTests
//

import Foundation
import os.lock
import Testing
@testable import cue

/// Tests for ``MorningBriefStore``'s once-per-day caching behaviour, driving a
/// real ``APIClient`` over a request-counting `URLProtocol` stub so we exercise
/// the genuine fetch/decode path without any network.
@MainActor
struct MorningBriefStoreTests {
    // MARK: - Happy path

    @Test func firstLoadFetchesAndSetsLoadedWithBrief() async {
        let stub = StubState(brief: "Good morning, sir.", localDate: "2026-06-28")
        let store = makeStore(stub)

        await store.load(for: makeDate("2026-06-28"))

        #expect(store.phase == .loaded)
        #expect(store.brief == "Good morning, sir.")
        #expect(stub.requestCount() == 1)
    }

    @Test func secondLoadSameDayShortCircuitsWithNoSecondRequest() async {
        let stub = StubState(brief: "Cached brief.", localDate: "2026-06-28")
        let store = makeStore(stub)
        let day = makeDate("2026-06-28")

        await store.load(for: day)
        await store.load(for: day)

        #expect(store.phase == .loaded)
        #expect(stub.requestCount() == 1)
    }

    @Test func forceReloadRefetchesEvenWhenCached() async {
        let stub = StubState(brief: "First.", localDate: "2026-06-28")
        let store = makeStore(stub)
        let day = makeDate("2026-06-28")

        await store.load(for: day)
        stub.setBrief("Second.")
        await store.load(for: day, force: true)

        #expect(store.phase == .loaded)
        #expect(store.brief == "Second.")
        #expect(stub.requestCount() == 2)
    }

    @Test func differentDayRefetches() async {
        let stub = StubState(brief: "Monday.", localDate: "2026-06-28")
        let store = makeStore(stub)

        await store.load(for: makeDate("2026-06-28"))
        // Server now answers for the next day with a matching localDate.
        stub.setBrief("Tuesday.")
        stub.setLocalDate("2026-06-29")
        await store.load(for: makeDate("2026-06-29"))

        #expect(store.phase == .loaded)
        #expect(store.brief == "Tuesday.")
        #expect(stub.requestCount() == 2)
    }

    // MARK: - Edge cases

    @Test func emptyBriefIsValidLoadedState() async {
        let stub = StubState(brief: nil, localDate: "2026-06-28")
        let store = makeStore(stub)

        await store.load(for: makeDate("2026-06-28"))

        #expect(store.phase == .loaded)
        #expect(store.brief == nil)
        #expect(stub.requestCount() == 1)
    }

    @Test func emptyBriefStillCachesAndShortCircuits() async {
        let stub = StubState(brief: nil, localDate: "2026-06-28")
        let store = makeStore(stub)
        let day = makeDate("2026-06-28")

        await store.load(for: day)
        await store.load(for: day)

        #expect(store.phase == .loaded)
        #expect(stub.requestCount() == 1)
    }

    @Test func failureSetsFailedPhaseAndLeavesPriorBriefInPlace() async {
        let stub = StubState(brief: "Survivor.", localDate: "2026-06-28")
        let store = makeStore(stub)

        // First a good load on one day so there's a prior brief to preserve.
        await store.load(for: makeDate("2026-06-28"))
        #expect(store.brief == "Survivor.")

        // A different day errors (cache key mismatch forces a re-fetch).
        stub.setStatusCode(500)
        await store.load(for: makeDate("2026-06-29"))

        #expect(store.phase == .failed)
        // The prior brief is NOT cleared — the failed re-fetch leaves it intact.
        #expect(store.brief == "Survivor.")
    }

    @Test func failureFromIdleLeavesBriefNil() async {
        let stub = StubState(brief: "ignored", localDate: "2026-06-28", statusCode: 503)
        let store = makeStore(stub)

        await store.load(for: makeDate("2026-06-28"))

        #expect(store.phase == .failed)
        #expect(store.brief == nil)
    }

    @Test func failedThenSuccessfulRetrySamePhaseProgression() async {
        let stub = StubState(brief: "Recovered.", localDate: "2026-06-28", statusCode: 500)
        let store = makeStore(stub)
        let day = makeDate("2026-06-28")

        await store.load(for: day)
        #expect(store.phase == .failed)
        #expect(stub.requestCount() == 1)

        // A retry on a .failed (non-.loaded) phase must NOT short-circuit.
        stub.setStatusCode(200)
        await store.load(for: day)

        #expect(store.phase == .loaded)
        #expect(store.brief == "Recovered.")
        #expect(stub.requestCount() == 2)
    }

    @Test func cacheKeyComesFromServerLocalDateNotRequestedDay() async {
        // The store keys its cache off `response.localDate`, which the stub makes
        // DIFFERENT from the requested day. A subsequent load for that server
        // date short-circuits; a load for the originally-requested day refetches.
        let stub = StubState(brief: "Server authoritative.", localDate: "2026-07-01")
        let store = makeStore(stub)

        await store.load(for: makeDate("2026-06-28"))
        #expect(store.phase == .loaded)
        #expect(stub.requestCount() == 1)

        // Loading the SERVER-returned date is a cache hit (no new request).
        await store.load(for: makeDate("2026-07-01"))
        #expect(stub.requestCount() == 1)

        // Loading the originally-requested day is a miss (cachedDate mismatch).
        await store.load(for: makeDate("2026-06-28"))
        #expect(stub.requestCount() == 2)
    }

    // MARK: - Helpers

    /// Builds a `MorningBriefStore` backed by an `APIClient` whose URLSession is
    /// wired to the given counting stub, with a no-op token provider so the test
    /// never touches the process-wide auth bridge.
    private func makeStore(_ stub: StubState) -> MorningBriefStore {
        // Bind this stub to a unique key carried on every request via a header,
        // so parallel test cases never share global state through the protocol.
        let stubKey = UUID().uuidString
        StubURLProtocol.register(stub, for: stubKey)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [StubURLProtocol.keyHeader: stubKey]
        let session = URLSession(configuration: configuration)
        let baseURL = URL(string: "https://stub.test") ?? URL(fileURLWithPath: "/")
        let api = APIClient(
            baseURL: baseURL,
            session: session,
            tokenProvider: { nil }
        )
        return MorningBriefStore(api: api)
    }

    /// A fixed-noon `Date` for the given `yyyy-MM-dd` in the current calendar, so
    /// the store's `en_US_POSIX` day formatter yields that exact key.
    private func makeDate(_ key: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let midnight = formatter.date(from: key) ?? Date(timeIntervalSince1970: 0)
        // Nudge to local noon so DST/edge rounding never shifts the day key.
        return midnight.addingTimeInterval(12 * 3600)
    }
}

/// Mutable, thread-safe stub configuration shared between the test and the
/// `URLProtocol` (which runs off the main actor). Tracks how many requests the
/// session issued so caching assertions can count network hits exactly.
private final class StubState: Sendable {
    private let brief: OSAllocatedUnfairLock<String?>
    private let localDate: OSAllocatedUnfairLock<String>
    private let statusCode: OSAllocatedUnfairLock<Int>
    private let count: OSAllocatedUnfairLock<Int>

    init(brief: String?, localDate: String, statusCode: Int = 200) {
        self.brief = OSAllocatedUnfairLock(initialState: brief)
        self.localDate = OSAllocatedUnfairLock(initialState: localDate)
        self.statusCode = OSAllocatedUnfairLock(initialState: statusCode)
        self.count = OSAllocatedUnfairLock(initialState: 0)
    }

    func setBrief(_ value: String?) { brief.withLock { $0 = value } }
    func setLocalDate(_ value: String) { localDate.withLock { $0 = value } }
    func setStatusCode(_ value: Int) { statusCode.withLock { $0 = value } }

    func requestCount() -> Int { count.withLock { $0 } }
    func incrementCount() { count.withLock { $0 += 1 } }

    func currentStatusCode() -> Int { statusCode.withLock { $0 } }

    /// The JSON body the stub returns, mirroring `DailyBriefDTO`'s wire shape.
    func responseBody() -> Data {
        let localDateValue = localDate.withLock { $0 }
        let briefValue = brief.withLock { $0 }
        let briefField: String
        if let briefValue {
            briefField = "\"\(briefValue)\""
        } else {
            briefField = "null"
        }
        let json = "{\"brief\": \(briefField), \"localDate\": \"\(localDateValue)\"}"
        return Data(json.utf8)
    }
}

/// A `URLProtocol` that intercepts every request, increments the active stub's
/// request counter, and replies with the stub's configured status + body. Never
/// touches the network.
private final class StubURLProtocol: URLProtocol {
    /// Request header carrying the per-session stub key, so concurrent test
    /// cases route to their own `StubState` without sharing global mutable state.
    static let keyHeader = "X-Stub-Key"

    /// Registry of live stubs keyed by their per-session UUID. A lock keeps the
    /// off-main protocol lookups race-free under parallel test execution.
    nonisolated(unsafe) private static let registry =
        OSAllocatedUnfairLock<[String: StubState]>(initialState: [:])

    /// Registers a stub under `identifier` for later lookup from `startLoading`.
    static func register(_ stub: StubState, for identifier: String) {
        registry.withLock { $0[identifier] = stub }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let key = request.value(forHTTPHeaderField: Self.keyHeader)
        guard
            let key,
            let stub = Self.registry.withLock({ $0[key] }),
            let url = request.url
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        stub.incrementCount()

        let status = stub.currentStatusCode()
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )
        guard let response else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.responseBody())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
