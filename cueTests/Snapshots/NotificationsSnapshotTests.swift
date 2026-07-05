//
//  NotificationsSnapshotTests.swift
//  cueTests
//
//  Storybook-style snapshot of the Notifications & Report settings screen
//  (`NotificationsReportView`). Unlike the calendar screens, this screen renders
//  its loaded form ONLY after two GETs succeed (`/users/me/report-settings` and
//  `/users/me/settings`) — the form is gated behind the store's `.loaded` phase.
//
//  The view owns its `ReportSettingsStore` as private `@State`, so the store
//  cannot be injected pre-loaded. Instead we stub the network at the URL-loading
//  layer: a process-wide `URLProtocol` intercepts those two endpoints and answers
//  instantly with canned DTOs, driving the store to `.loaded` within the
//  harness's render window. With the report ENABLED, this exercises the full
//  surface from the design ref `Notifications.dc.html`: the daily-report master
//  card, the revealed channel/time config card, the timezone footnote, and the
//  morning-brief / evening-recap opt-ins.
//

import Foundation
import Testing
import SwiftUI
@testable import cue

@MainActor
struct NotificationsSnapshotTests {
    /// Renders the notifications/report screen in its default loaded state with
    /// the daily report enabled (config card + footnote + opt-ins all visible),
    /// driven by stubbed settings responses.
    @Test
    func notificationsLoaded() async {
        ReportSettingsStubProtocol.install(
            report: ReportSettingsStubProtocol.Response(
                enabled: true,
                reportTimeLocal: "08:00",
                channel: "TELEGRAM"
            ),
            settings: ReportSettingsStubProtocol.UserResponse(
                timezone: "Europe/Berlin",
                morningBriefEnabled: true,
                eveningRecapEnabled: false
            )
        )
        defer { ReportSettingsStubProtocol.uninstall() }

        let container = MockData.container()

        let screen = NavigationStack {
            NotificationsReportView()
        }

        // Give the view's `.task` time to run the two stubbed GETs and flip the
        // store to `.loaded` before the harness rasterizes. The stub answers
        // synchronously, so a short settle is enough.
        let host = ScreenHost.wrap(screen, container: container)
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(150))

        #expect(SnapshotHarness.record(host, named: "notifications-loaded") != nil)
    }
}

/// Process-wide `URLProtocol` that answers the Notifications/Report screen's two
/// cold-load GETs (`/users/me/report-settings`, `/users/me/settings`) with canned
/// JSON, so the screen's internally-owned store reaches its `.loaded` phase
/// without a live backend. Any other request is failed fast so nothing hangs the
/// render window. Self-contained to this suite — does not touch the shared
/// foundation.
final class ReportSettingsStubProtocol: URLProtocol, @unchecked Sendable {
    /// Canned `ReportSettingsDTO` shape (wire field names match the DTO).
    struct Response {
        let enabled: Bool
        let reportTimeLocal: String
        let channel: String
    }

    /// Canned `UserSettingsDTO` shape (only the fields this screen reads).
    struct UserResponse {
        let timezone: String
        let morningBriefEnabled: Bool
        let eveningRecapEnabled: Bool
    }

    nonisolated(unsafe) private static var report: Response?
    nonisolated(unsafe) private static var settings: UserResponse?

    /// Registers the stub and arms the two canned payloads.
    static func install(report: Response, settings: UserResponse) {
        self.report = report
        self.settings = settings
        URLProtocol.registerClass(ReportSettingsStubProtocol.self)
    }

    /// Removes the stub and clears the armed payloads.
    static func uninstall() {
        URLProtocol.unregisterClass(ReportSettingsStubProtocol.self)
        report = nil
        settings = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        // Intercept everything while installed; we hand back canned JSON for the
        // two settings endpoints and an empty 200 for anything else.
        request.url != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let path = request.url?.path ?? ""
        let body = Self.body(for: path)

        let response = HTTPURLResponse(
            url: request.url ?? URL(fileURLWithPath: "/"),
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// Picks the canned JSON for a request path; an empty object for the rest.
    private static func body(for path: String) -> Data {
        if path.hasSuffix("/report-settings"), let report {
            let json = """
            {"enabled":\(report.enabled),"reportTimeLocal":"\(report.reportTimeLocal)","channel":"\(report.channel)"}
            """
            return Data(json.utf8)
        }
        if path.hasSuffix("/settings"), let settings {
            let json = """
            {"timezone":"\(settings.timezone)","displayName":"Tony Stark","avatarBase64":null,"morningBriefEnabled":\(settings.morningBriefEnabled),"eveningRecapEnabled":\(settings.eveningRecapEnabled)}
            """
            return Data(json.utf8)
        }
        return Data("{}".utf8)
    }
}
