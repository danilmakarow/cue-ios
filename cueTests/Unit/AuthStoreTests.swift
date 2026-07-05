//
//  AuthStoreTests.swift
//  cueTests
//
//  Covers AuthStore bootstrap/cache/token logic plus the AuthTokenBridge lock.
//
//  Injection note: `KeychainStore` is a concrete `struct` (not a protocol and
//  not subclassable), and `AuthStore.init(keychain:api:)` takes that concrete
//  type. There is therefore NO seam to inject an in-memory fake keychain. These
//  tests instead drive the REAL keychain, isolated per test by a UNIQUE service
//  name, and clean up the entries afterwards. See `notes` in the run summary for
//  the recommended protocol-seam extraction.
//

import Foundation
import Testing
@testable import cue

// MARK: - URLProtocol network stub

/// In-memory `URLProtocol` that answers every request from a per-test handler.
/// Registered on an ephemeral `URLSession` so no real network is ever touched.
private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    /// Per-test handler: maps an outgoing request to a status + JSON body. A
    /// thrown error simulates a transport failure (offline). Guarded by a lock so
    /// it is safe to assign from the test actor and read on the URL loading queue.
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?
    private static let lock = NSLock()

    /// Installs a handler under the lock.
    static func setHandler(_ newHandler: ((URLRequest) throws -> (Int, Data))?) {
        lock.lock()
        defer { lock.unlock() }
        handler = newHandler
    }

    /// Reads the handler under the lock.
    private static func currentHandler() -> ((URLRequest) throws -> (Int, Data))? {
        lock.lock()
        defer { lock.unlock() }
        return handler
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.currentHandler() else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (status, body) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url ?? URL(fileURLWithPath: "/"),
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
            if let response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Suite

@MainActor
@Suite(.serialized)
struct AuthStoreTests {
    // MARK: Fixtures

    /// A frozen ISO-8601 timestamp (whole seconds, `Z`) used in every UserDTO
    /// fixture so the round-trip is deterministic.
    private static let isoTimestamp = "2026-06-28T10:30:00Z"

    /// Builds the `/auth/me` JSON body for a user with the given id.
    private func userJSON(id: String = "user-1") -> Data {
        let json = """
        {
          "id": "\(id)",
          "appleUserId": "apple-\(id)",
          "email": "user@example.com",
          "displayName": "Tony Stark",
          "avatarBase64": null,
          "timezone": "Europe/Berlin",
          "createdAt": "\(Self.isoTimestamp)",
          "updatedAt": "\(Self.isoTimestamp)"
        }
        """
        return Data(json.utf8)
    }

    /// A `URLSession` whose only protocol is the in-memory stub — never hits the
    /// network.
    private func makeStubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// Builds an `APIClient` wired to the stubbed session. `tokenProvider` is left
    /// at its default so it reads the same `AuthTokenBridge.shared` that AuthStore
    /// drives — exactly the production wiring.
    private func makeAPIClient() -> APIClient {
        let baseURL = URL(string: "https://test.invalid") ?? URL(fileURLWithPath: "/")
        return APIClient(baseURL: baseURL, session: makeStubbedSession())
    }

    /// A keychain scoped to a unique service so each test is isolated from the
    /// shared device keychain and from sibling tests.
    private func makeKeychain() -> KeychainStore {
        KeychainStore(service: "cueTests.AuthStore.\(UUID().uuidString)")
    }

    /// Resets process-wide global token state so a prior test cannot bleed in.
    private func resetBridge() {
        AuthTokenBridge.shared.setToken(nil)
    }

    /// Removes both accounts from the given keychain so the OS keychain is left
    /// clean after a test.
    private func cleanup(_ keychain: KeychainStore) {
        keychain.delete(account: "accessToken")
        keychain.delete(account: "cachedUser")
    }

    // MARK: init — persisted token hydration

    @Test func initPushesPersistedTokenIntoBridge() {
        resetBridge()
        let keychain = makeKeychain()
        defer { cleanup(keychain) }
        keychain.set("persisted-jwt", account: "accessToken")

        _ = AuthStore(keychain: keychain, api: makeAPIClient())

        #expect(AuthTokenBridge.shared.currentToken() == "persisted-jwt")
    }

    @Test func initWithNoPersistedTokenLeavesBridgeEmpty() {
        resetBridge()
        let keychain = makeKeychain()
        defer { cleanup(keychain) }

        _ = AuthStore(keychain: keychain, api: makeAPIClient())

        #expect(AuthTokenBridge.shared.currentToken() == nil)
    }

    // MARK: bootstrap — no token

    @Test func bootstrapWithNoTokenIsUnauthenticated() async {
        resetBridge()
        StubURLProtocol.setHandler { _ in
            Issue.record("Network must not be hit when there is no token")
            return (500, Data())
        }
        defer { StubURLProtocol.setHandler(nil) }

        let keychain = makeKeychain()
        defer { cleanup(keychain) }
        let store = AuthStore(keychain: keychain, api: makeAPIClient())

        await store.bootstrap()

        #expect(isUnauthenticated(store.state))
    }

    // MARK: bootstrap — 200 /auth/me

    @Test func bootstrapWith200AuthenticatesAndCachesUser() async throws {
        resetBridge()
        let body = userJSON(id: "me-200")
        StubURLProtocol.setHandler { _ in (200, body) }
        defer { StubURLProtocol.setHandler(nil) }

        let keychain = makeKeychain()
        defer { cleanup(keychain) }
        keychain.set("valid-jwt", account: "accessToken")
        let store = AuthStore(keychain: keychain, api: makeAPIClient())

        await store.bootstrap()

        let user = try #require(authenticatedUser(store.state))
        #expect(user.id == "me-200")

        // cacheUser must have written the profile JSON into the keychain.
        let cachedJSON = try #require(keychain.get(account: "cachedUser"))
        let data = try #require(cachedJSON.data(using: .utf8))
        let cached = try decodeUser(data)
        #expect(cached.id == "me-200")
    }

    // MARK: bootstrap — 401 /auth/me

    @Test func bootstrapWith401ClearsSessionAndIsUnauthenticated() async {
        resetBridge()
        StubURLProtocol.setHandler { _ in (401, Data("{\"message\":\"expired\"}".utf8)) }
        defer { StubURLProtocol.setHandler(nil) }

        let keychain = makeKeychain()
        defer { cleanup(keychain) }
        keychain.set("stale-jwt", account: "accessToken")
        keychain.set("{\"stale\":true}", account: "cachedUser")
        let store = AuthStore(keychain: keychain, api: makeAPIClient())

        // Sanity: the token is live on the bridge before bootstrap.
        #expect(AuthTokenBridge.shared.currentToken() == "stale-jwt")

        await store.bootstrap()

        #expect(isUnauthenticated(store.state))
        // clearSession deletes both keychain accounts and clears the bridge.
        #expect(keychain.get(account: "accessToken") == nil)
        #expect(keychain.get(account: "cachedUser") == nil)
        #expect(AuthTokenBridge.shared.currentToken() == nil)
    }

    // MARK: bootstrap — non-401 (network) error, offline tolerance

    @Test func bootstrapOnNetworkErrorWithCachedUserStaysAuthenticated() async throws {
        resetBridge()
        StubURLProtocol.setHandler { _ in throw URLError(.notConnectedToInternet) }
        defer { StubURLProtocol.setHandler(nil) }

        let keychain = makeKeychain()
        defer { cleanup(keychain) }
        keychain.set("valid-jwt", account: "accessToken")

        // Seed a cached user written exactly the way `cacheUser` would.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let seeded = try decodeUser(userJSON(id: "cached-me"))
        let seededData = try encoder.encode(seeded)
        let seededJSON = try #require(String(data: seededData, encoding: .utf8))
        keychain.set(seededJSON, account: "cachedUser")

        let store = AuthStore(keychain: keychain, api: makeAPIClient())
        await store.bootstrap()

        let user = try #require(authenticatedUser(store.state))
        #expect(user.id == "cached-me")
        // The token must NOT be dropped on a transient (non-401) failure.
        #expect(AuthTokenBridge.shared.currentToken() == "valid-jwt")
    }

    @Test func bootstrapOnNetworkErrorWithoutCachedUserIsUnauthenticated() async {
        resetBridge()
        StubURLProtocol.setHandler { _ in throw URLError(.timedOut) }
        defer { StubURLProtocol.setHandler(nil) }

        let keychain = makeKeychain()
        defer { cleanup(keychain) }
        keychain.set("valid-jwt", account: "accessToken")
        let store = AuthStore(keychain: keychain, api: makeAPIClient())

        await store.bootstrap()

        #expect(isUnauthenticated(store.state))
        // Offline tolerance keeps the token even though we land unauthenticated:
        // only a real 401 drops it.
        #expect(AuthTokenBridge.shared.currentToken() == "valid-jwt")
    }

    // MARK: cacheUser / cachedUser round-trip via bootstrap

    @Test func cachedUserRoundTripPreservesIso8601Dates() async throws {
        resetBridge()
        let body = userJSON(id: "roundtrip")
        StubURLProtocol.setHandler { _ in (200, body) }
        defer { StubURLProtocol.setHandler(nil) }

        let keychain = makeKeychain()
        defer { cleanup(keychain) }
        keychain.set("valid-jwt", account: "accessToken")
        let store = AuthStore(keychain: keychain, api: makeAPIClient())

        await store.bootstrap()

        // Read back the cached JSON and decode with the SAME .iso8601 strategy
        // AuthStore.cachedUser uses; the dates must survive the round-trip.
        let json = try #require(keychain.get(account: "cachedUser"))
        let data = try #require(json.data(using: .utf8))
        let cached = try decodeUser(data)
        let expectedDate = ISO8601DateFormatter().date(from: Self.isoTimestamp)

        #expect(cached.id == "roundtrip")
        #expect(cached.createdAt == expectedDate)
        #expect(cached.updatedAt == expectedDate)
    }

    // MARK: signOut

    @Test func signOutClearsSessionAndIsUnauthenticated() async {
        resetBridge()
        let body = userJSON(id: "signout")
        StubURLProtocol.setHandler { _ in (200, body) }
        defer { StubURLProtocol.setHandler(nil) }

        let keychain = makeKeychain()
        defer { cleanup(keychain) }
        keychain.set("valid-jwt", account: "accessToken")
        let store = AuthStore(keychain: keychain, api: makeAPIClient())
        await store.bootstrap()
        // Precondition: authenticated + cached user present.
        #expect(authenticatedUser(store.state) != nil)
        #expect(keychain.get(account: "cachedUser") != nil)

        store.signOut()

        #expect(isUnauthenticated(store.state))
        #expect(keychain.get(account: "accessToken") == nil)
        #expect(keychain.get(account: "cachedUser") == nil)
        #expect(AuthTokenBridge.shared.currentToken() == nil)
    }

    // MARK: AuthTokenBridge lock — independently assertable

    @Test func tokenBridgeSetAndCurrentRoundTrip() {
        let bridge = AuthTokenBridge()
        #expect(bridge.currentToken() == nil)

        bridge.setToken("abc")
        #expect(bridge.currentToken() == "abc")

        bridge.setToken(nil)
        #expect(bridge.currentToken() == nil)
    }

    @Test func tokenBridgeIsThreadSafeUnderConcurrentWrites() async {
        let bridge = AuthTokenBridge()

        // Hammer the lock from many tasks; the unfair-lock must serialize without
        // crashing or tearing, and the final read must be one of the written values.
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<200 {
                group.addTask {
                    bridge.setToken("token-\(index)")
                    _ = bridge.currentToken()
                }
            }
        }

        let final = bridge.currentToken()
        #expect(final?.hasPrefix("token-") == true)
    }

    // MARK: Helpers

    /// Decodes a UserDTO from JSON using the iso8601 strategy.
    private func decodeUser(_ data: Data) throws -> UserDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UserDTO.self, from: data)
    }

    /// Returns true when the state is `.unauthenticated`.
    private func isUnauthenticated(_ state: AuthState) -> Bool {
        if case .unauthenticated = state { return true }
        return false
    }

    /// Extracts the user from an `.authenticated` state, else nil.
    private func authenticatedUser(_ state: AuthState) -> UserDTO? {
        if case .authenticated(let user) = state { return user }
        return nil
    }
}
