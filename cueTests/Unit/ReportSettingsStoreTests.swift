//
//  ReportSettingsStoreTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

// MARK: - URLProtocol stub

/// Per-request stubbed handler installed on an ephemeral `URLSession`, so
/// `ReportSettingsStore` can drive the real `APIClient` transport without ever
/// touching the network. Keyed by `METHOD path` so the two concurrent reads in
/// `load()` (`GET /users/me/report-settings` + `GET /users/me/settings`) and the
/// individual `PATCH`es each resolve to their own canned outcome.
private final class ReportSettingsURLProtocol: URLProtocol, @unchecked Sendable {
    /// Outcome for one stubbed request: an HTTP status + JSON body, or a
    /// transport-level failure.
    enum Outcome: Sendable {
        case response(status: Int, json: String)
        case failure
    }

    nonisolated(unsafe) private static var handlers: [String: Outcome] = [:]
    nonisolated(unsafe) private static var seenKeys: [String] = []
    private static let lock = NSLock()

    /// Installs (or replaces) the canned outcome for a `METHOD path` pair.
    static func set(method: String, path: String, outcome: Outcome) {
        lock.lock()
        defer { lock.unlock() }
        handlers["\(method) \(path)"] = outcome
    }

    /// Clears all installed handlers and the request log between tests.
    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        handlers.removeAll()
        seenKeys.removeAll()
    }

    /// The ordered list of `METHOD path` keys actually requested — lets a test
    /// assert that a guarded setter made (or skipped) its `PATCH`.
    static func requestedKeys() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return seenKeys
    }

    private static func key(for request: URLRequest) -> String {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? ""
        return "\(method) \(path)"
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let requestKey = Self.key(for: request)
        Self.lock.lock()
        Self.seenKeys.append(requestKey)
        let outcome = Self.handlers[requestKey]
        Self.lock.unlock()

        guard let outcome else {
            client?.urlProtocol(
                self,
                didFailWithError: NSError(
                    domain: "ReportSettingsURLProtocol",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No stub for \(requestKey)"]
                )
            )
            return
        }

        switch outcome {
        case .failure:
            client?.urlProtocol(
                self,
                didFailWithError: NSError(
                    domain: "ReportSettingsURLProtocol",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Stubbed transport failure"]
                )
            )
        case let .response(status, json):
            guard let url = request.url else { return }
            let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
            if let response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            client?.urlProtocol(self, didLoad: Data(json.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

// MARK: - Fixtures + helpers

/// JSON wire bodies and a configured `APIClient` wired to the URLProtocol stub.
private enum Fixture {
    static let reportPath = "/users/me/report-settings"
    static let userPath = "/users/me/settings"

    /// A report-settings DTO body. `time` is the `HH:mm` wall-clock string.
    static func reportJSON(enabled: Bool, time: String, channel: String) -> String {
        """
        { "enabled": \(enabled), "reportTimeLocal": "\(time)", "channel": "\(channel)" }
        """
    }

    /// A user-settings DTO body with the two opt-ins + timezone.
    static func userJSON(
        timezone: String,
        morningBrief: Bool,
        eveningRecap: Bool
    ) -> String {
        """
        {
          "timezone": "\(timezone)",
          "displayName": null,
          "avatarBase64": null,
          "morningBriefEnabled": \(morningBrief),
          "eveningRecapEnabled": \(eveningRecap)
        }
        """
    }

    /// An `APIClient` whose `URLSession` routes every request through the stub.
    static func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReportSettingsURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let baseURL = URL(string: "https://stub.test") ?? URL(fileURLWithPath: "/")
        return APIClient(
            baseURL: baseURL,
            session: session,
            tokenProvider: { nil }
        )
    }
}

// MARK: - Tests

// Serialized: the URLProtocol stub holds process-wide static handler state, so
// the cases must not run in parallel and clobber each other's stubs.
@MainActor
@Suite(.serialized)
struct ReportSettingsStoreTests {
    /// Fresh, isolated stub state for every test.
    init() {
        ReportSettingsURLProtocol.reset()
    }

    // MARK: load() folds both payloads

    @Test func loadFoldsReportAndUserDTOs() async {
        ReportSettingsURLProtocol.set(
            method: "GET",
            path: Fixture.reportPath,
            outcome: .response(
                status: 200,
                json: Fixture.reportJSON(enabled: true, time: "08:00", channel: "TELEGRAM")
            )
        )
        ReportSettingsURLProtocol.set(
            method: "GET",
            path: Fixture.userPath,
            outcome: .response(
                status: 200,
                json: Fixture.userJSON(
                    timezone: "Europe/Berlin",
                    morningBrief: true,
                    eveningRecap: false
                )
            )
        )

        let store = ReportSettingsStore(api: Fixture.makeClient())
        await store.load()

        #expect(store.phase == .loaded)
        #expect(store.enabled == true)
        #expect(store.channel == .telegram)
        // Timezone is sourced from the user settings, not the report payload.
        #expect(store.timezoneIdentifier == "Europe/Berlin")
        #expect(store.morningBriefEnabled == true)
        #expect(store.eveningRecapEnabled == false)
        // "08:00" parsed in en_US_POSIX → 8h 0m wall-clock.
        let components = Calendar.current.dateComponents([.hour, .minute], from: store.reportTime)
        #expect(components.hour == 8)
        #expect(components.minute == 0)
    }

    @Test func loadFailureSetsFailedPhase() async {
        ReportSettingsURLProtocol.set(
            method: "GET",
            path: Fixture.reportPath,
            outcome: .failure
        )
        ReportSettingsURLProtocol.set(
            method: "GET",
            path: Fixture.userPath,
            outcome: .response(
                status: 200,
                json: Fixture.userJSON(timezone: "UTC", morningBrief: false, eveningRecap: false)
            )
        )

        let store = ReportSettingsStore(api: Fixture.makeClient())
        await store.load()

        guard case .failed = store.phase else {
            Issue.record("Expected .failed phase, got \(store.phase)")
            return
        }
    }

    // MARK: setChannel — happy path applies DTO + flashes saved

    @Test func setChannelSuccessAppliesReturnedDTOAndFlashesSaved() async {
        let store = ReportSettingsStore(api: Fixture.makeClient())
        // Seed a confirmed snapshot so the channel starts at .telegram.
        await loadSeed(into: store, channel: "TELEGRAM")

        // The PATCH echoes the new channel back.
        ReportSettingsURLProtocol.set(
            method: "PATCH",
            path: Fixture.reportPath,
            outcome: .response(
                status: 200,
                json: Fixture.reportJSON(enabled: true, time: "08:00", channel: "PUSH")
            )
        )

        await store.setChannel(.push)

        #expect(store.channel == .push)
        #expect(store.showSaved == true)
        #expect(store.showSaveError == false)
        #expect(store.isSaving == false)
    }

    // MARK: setChannel — failure reverts to previous + shows error

    @Test func setChannelFailureRevertsToPreviousAndShowsError() async {
        let store = ReportSettingsStore(api: Fixture.makeClient())
        await loadSeed(into: store, channel: "TELEGRAM")

        ReportSettingsURLProtocol.set(
            method: "PATCH",
            path: Fixture.reportPath,
            outcome: .failure
        )

        await store.setChannel(.push)

        // Optimistic value flipped to .push, then reverted back to .telegram.
        #expect(store.channel == .telegram)
        #expect(store.showSaveError == true)
        #expect(store.showSaved == false)
        #expect(store.isSaving == false)
    }

    // MARK: setChannel — guard no-ops when value unchanged

    @Test func setChannelNoOpsWhenSameValue() async {
        let store = ReportSettingsStore(api: Fixture.makeClient())
        await loadSeed(into: store, channel: "TELEGRAM")

        await store.setChannel(.telegram)

        // No PATCH should have fired; no saved/error flag toggled on.
        #expect(ReportSettingsURLProtocol.requestedKeys().contains("PATCH \(Fixture.reportPath)") == false)
        #expect(store.showSaved == false)
        #expect(store.showSaveError == false)
    }

    // MARK: commitTime — round-trips HH:mm and reverts on failure

    @Test func commitTimeSuccessPersistsAndRoundTripsTime() async {
        let store = ReportSettingsStore(api: Fixture.makeClient())
        await loadSeed(into: store, time: "08:00", channel: "TELEGRAM")

        // Move the picker to 09:30 and have the server confirm it.
        store.reportTime = makeTime(hour: 9, minute: 30)
        ReportSettingsURLProtocol.set(
            method: "PATCH",
            path: Fixture.reportPath,
            outcome: .response(
                status: 200,
                json: Fixture.reportJSON(enabled: true, time: "09:30", channel: "TELEGRAM")
            )
        )

        await store.commitTime()

        #expect(store.showSaved == true)
        let components = Calendar.current.dateComponents([.hour, .minute], from: store.reportTime)
        #expect(components.hour == 9)
        #expect(components.minute == 30)
    }

    @Test func commitTimeFailureRevertsToConfirmedTime() async {
        let store = ReportSettingsStore(api: Fixture.makeClient())
        await loadSeed(into: store, time: "08:00", channel: "TELEGRAM")

        // Picker moved to 09:30; the PATCH fails → revert to confirmed 08:00.
        store.reportTime = makeTime(hour: 9, minute: 30)
        ReportSettingsURLProtocol.set(
            method: "PATCH",
            path: Fixture.reportPath,
            outcome: .failure
        )

        await store.commitTime()

        #expect(store.showSaveError == true)
        let components = Calendar.current.dateComponents([.hour, .minute], from: store.reportTime)
        // Reverted to confirmedReport.reportTimeLocal ("08:00").
        #expect(components.hour == 8)
        #expect(components.minute == 0)
    }

    @Test func commitTimeNoOpsWhenWireMatchesConfirmed() async {
        let store = ReportSettingsStore(api: Fixture.makeClient())
        await loadSeed(into: store, time: "08:00", channel: "TELEGRAM")

        // Picker still at 08:00 → wire matches confirmed → guard, no PATCH.
        store.reportTime = makeTime(hour: 8, minute: 0)
        await store.commitTime()

        #expect(ReportSettingsURLProtocol.requestedKeys().contains("PATCH \(Fixture.reportPath)") == false)
        #expect(store.showSaved == false)
    }

    // MARK: setMorningBrief — happy + revert + guard (account settings PATCH)

    @Test func setMorningBriefSuccessAppliesUserDTO() async {
        let store = ReportSettingsStore(api: Fixture.makeClient())
        await loadSeed(into: store, morningBrief: false)

        ReportSettingsURLProtocol.set(
            method: "PATCH",
            path: Fixture.userPath,
            outcome: .response(
                status: 200,
                json: Fixture.userJSON(timezone: "UTC", morningBrief: true, eveningRecap: false)
            )
        )

        await store.setMorningBrief(true)

        #expect(store.morningBriefEnabled == true)
        #expect(store.showSaved == true)
        #expect(store.showSaveError == false)
    }

    @Test func setMorningBriefFailureRevertsOptIn() async {
        let store = ReportSettingsStore(api: Fixture.makeClient())
        await loadSeed(into: store, morningBrief: false)

        ReportSettingsURLProtocol.set(
            method: "PATCH",
            path: Fixture.userPath,
            outcome: .failure
        )

        await store.setMorningBrief(true)

        #expect(store.morningBriefEnabled == false)
        #expect(store.showSaveError == true)
    }

    @Test func setMorningBriefNoOpsWhenSameValue() async {
        let store = ReportSettingsStore(api: Fixture.makeClient())
        await loadSeed(into: store, morningBrief: false)

        await store.setMorningBrief(false)

        #expect(ReportSettingsURLProtocol.requestedKeys().contains("PATCH \(Fixture.userPath)") == false)
        #expect(store.showSaved == false)
    }

    // MARK: setEnabled(false) — skips push path, persists optimistically

    @Test func setEnabledFalseSkipsPushAndPersists() async {
        let store = ReportSettingsStore(api: Fixture.makeClient())
        await loadSeed(into: store, enabled: true)

        ReportSettingsURLProtocol.set(
            method: "PATCH",
            path: Fixture.reportPath,
            outcome: .response(
                status: 200,
                json: Fixture.reportJSON(enabled: false, time: "08:00", channel: "TELEGRAM")
            )
        )

        await store.setEnabled(false)

        #expect(store.enabled == false)
        #expect(store.showSaved == true)
        #expect(store.showSaveError == false)
    }

    @Test func setEnabledFalseFailureRevertsToEnabled() async {
        let store = ReportSettingsStore(api: Fixture.makeClient())
        await loadSeed(into: store, enabled: true)

        ReportSettingsURLProtocol.set(
            method: "PATCH",
            path: Fixture.reportPath,
            outcome: .failure
        )

        await store.setEnabled(false)

        // Optimistically flipped to false, reverted back to true on failure.
        #expect(store.enabled == true)
        #expect(store.showSaveError == true)
    }

    @Test func setEnabledNoOpsWhenSameValue() async {
        let store = ReportSettingsStore(api: Fixture.makeClient())
        await loadSeed(into: store, enabled: true)

        await store.setEnabled(true)

        #expect(ReportSettingsURLProtocol.requestedKeys().contains("PATCH \(Fixture.reportPath)") == false)
    }

    // MARK: setEveningRecap — happy path (mirror of morning brief)

    @Test func setEveningRecapSuccessAppliesUserDTO() async {
        let store = ReportSettingsStore(api: Fixture.makeClient())
        await loadSeed(into: store, eveningRecap: false)

        ReportSettingsURLProtocol.set(
            method: "PATCH",
            path: Fixture.userPath,
            outcome: .response(
                status: 200,
                json: Fixture.userJSON(timezone: "UTC", morningBrief: false, eveningRecap: true)
            )
        )

        await store.setEveningRecap(true)

        #expect(store.eveningRecapEnabled == true)
        #expect(store.showSaved == true)
    }

    // MARK: - Helpers

    /// Seeds the store's confirmed snapshot + fields by running a stubbed `load()`,
    /// then clears the GET handlers so subsequent PATCH assertions read clean.
    private func loadSeed(
        into store: ReportSettingsStore,
        enabled: Bool = true,
        time: String = "08:00",
        channel: String = "TELEGRAM",
        timezone: String = "UTC",
        morningBrief: Bool = false,
        eveningRecap: Bool = false
    ) async {
        ReportSettingsURLProtocol.set(
            method: "GET",
            path: Fixture.reportPath,
            outcome: .response(
                status: 200,
                json: Fixture.reportJSON(enabled: enabled, time: time, channel: channel)
            )
        )
        ReportSettingsURLProtocol.set(
            method: "GET",
            path: Fixture.userPath,
            outcome: .response(
                status: 200,
                json: Fixture.userJSON(
                    timezone: timezone,
                    morningBrief: morningBrief,
                    eveningRecap: eveningRecap
                )
            )
        )
        await store.load()
        ReportSettingsURLProtocol.reset()
    }

    /// Builds a `Date` with the given wall-clock hour/minute on a reference day.
    private func makeTime(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 28
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}
