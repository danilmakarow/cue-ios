//
//  APIClientDecodingTests.swift
//  cueTests
//
//  Exercises the lenient ISO-8601 date decoder wired into `APIClient`'s private
//  `JSONDecoder`. The decoder (and its `isoDate(from:)` helper) are private, so
//  the behavior is reached the way the app actually does: a `URLProtocol`-stubbed
//  `URLSession` is injected into `APIClient(session:)`, a `TaskDTO` / `OccurrenceDTO`
//  fixture body is returned, and `get()` is awaited. We assert dates decode for
//  both fractional- and whole-second forms, that a malformed date surfaces as
//  `APIError.decoding`, and that non-2xx statuses map to `.http` / `.linkCodeInvalid`.
//

import Foundation
import Testing
@testable import cue

// MARK: - URLProtocol stub

/// Process-wide stub config for ``StubURLProtocol``. A test sets `responder`,
/// the protocol reads it on `startLoading`. Kept on a lock so the value is safe
/// to mutate from the test thread and read from URLSession's loading thread.
private final class StubConfig: @unchecked Sendable {
    static let shared = StubConfig()

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

/// A `URLProtocol` that answers every request from ``StubConfig/shared`` instead
/// of hitting the network. Registered on an ephemeral `URLSessionConfiguration`
/// so it never touches `URLSession.shared`.
private final class StubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let responder = StubConfig.shared.responder else {
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

/// Builds an `APIClient` whose session routes through ``StubURLProtocol`` and
/// whose stub responder returns the given status + body for any request. Token
/// provider is fixed to `nil` so no keychain / bridge state leaks in.
@Sendable private func makeStubbedClient(
    status: Int,
    body: String
) -> APIClient {
    StubConfig.shared.responder = { request in
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

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    let session = URLSession(configuration: configuration)

    return APIClient(
        baseURL: URL(string: "https://stub.invalid")!,
        session: session,
        tokenProvider: { nil }
    )
}

/// A `TaskDTO` JSON fixture. The two timestamps that drive the decoder tests —
/// `startAt` and `completedAt` — are parameterized so each test can flip them
/// between fractional-second, whole-second, and malformed forms.
private func taskJSON(
    startAt: String,
    completedAt: String
) -> String {
    """
    {
      "id": "task-1",
      "calendarId": "cal-1",
      "title": "Decoder fixture",
      "notes": null,
      "startAt": "\(startAt)",
      "endAt": null,
      "isAllDay": false,
      "timezone": "UTC",
      "requiresCompletion": true,
      "color": null,
      "icon": null,
      "completedAt": "\(completedAt)",
      "recurrenceRuleId": null,
      "recurrence": null,
      "reminders": [],
      "notificationStrategyId": null,
      "createdAt": "2026-06-02T14:00:00Z",
      "updatedAt": "2026-06-02T14:00:00Z"
    }
    """
}

// MARK: - Tests

/// All cases route through a stubbed `URLSession`, never the network.
/// Serialized: the suite shares one process-wide `StubConfig.shared.responder`,
/// so parallel cases would clobber each other's canned response. (Matches the
/// already-serialized network suites in this target.)
@Suite(.serialized)
struct APIClientDecodingTests {
    // MARK: Happy-path date forms

    @Test func decodesWholeSecondISO8601() async throws {
        let client = makeStubbedClient(
            status: 200,
            body: taskJSON(
                startAt: "2026-06-02T14:00:00Z",
                completedAt: "2026-06-02T15:30:00Z"
            )
        )

        let task: TaskDTO = try await client.get("/tasks/task-1")

        // 2026-06-02T14:00:00Z
        let expectedStart = ISO8601DateFormatter().date(from: "2026-06-02T14:00:00Z")
        #expect(task.startAt == expectedStart)
    }

    @Test func decodesFractionalSecondISO8601() async throws {
        // The bug this lenient decoder fixes: stock `.iso8601` rejects the
        // millisecond form and fails the whole-response decode.
        let client = makeStubbedClient(
            status: 200,
            body: taskJSON(
                startAt: "2026-06-02T14:00:00.000Z",
                completedAt: "2026-06-02T15:30:00.000Z"
            )
        )

        let task: TaskDTO = try await client.get("/tasks/task-1")

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(task.startAt == fractional.date(from: "2026-06-02T14:00:00.000Z"))
    }

    @Test func fractionalCompletedAtDoesNotFailWholeResponse() async throws {
        // A `completedAt` carrying milliseconds (assistant-created completion)
        // alongside a whole-second `startAt` must still decode the whole DTO.
        let client = makeStubbedClient(
            status: 200,
            body: taskJSON(
                startAt: "2026-06-02T14:00:00Z",
                completedAt: "2026-06-02T15:30:00.123Z"
            )
        )

        let task: TaskDTO = try await client.get("/tasks/task-1")

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(task.completedAt == fractional.date(from: "2026-06-02T15:30:00.123Z"))
        #expect(task.startAt == ISO8601DateFormatter().date(from: "2026-06-02T14:00:00Z"))
    }

    @Test func decodesFractionalDateInsideOccurrenceDTO() async throws {
        // Same lenient parser must apply to the calendar-read shape (OccurrenceDTO).
        let json = """
        {
          "taskId": "task-1",
          "calendarId": "cal-1",
          "groupId": null,
          "originalStart": "2026-06-02T14:00:00.000Z",
          "occurrenceStart": "2026-06-02T14:00:00.000Z",
          "occurrenceEnd": null,
          "title": "Occ fixture",
          "notes": null,
          "isAllDay": false,
          "timezone": "UTC",
          "requiresCompletion": true,
          "completedAt": null,
          "isRecurring": false,
          "isException": false
        }
        """
        let client = makeStubbedClient(status: 200, body: json)

        let occurrence: OccurrenceDTO = try await client.get("/tasks")

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(occurrence.occurrenceStart == fractional.date(from: "2026-06-02T14:00:00.000Z"))
    }

    // MARK: Malformed date

    @Test func malformedDateThrowsDecodingNotSilentNil() async throws {
        let client = makeStubbedClient(
            status: 200,
            body: taskJSON(
                startAt: "not-a-real-date",
                completedAt: "2026-06-02T15:30:00Z"
            )
        )

        await #expect(throws: APIError.self) {
            let _: TaskDTO = try await client.get("/tasks/task-1")
        }

        // And specifically the `.decoding` case (not `.http` / `.transport`).
        do {
            let _: TaskDTO = try await client.get("/tasks/task-1")
            Issue.record("Expected a decoding error to be thrown")
        } catch let error as APIError {
            guard case .decoding = error else {
                Issue.record("Expected APIError.decoding, got \(error)")
                return
            }
        }
    }

    // MARK: Non-2xx mapping

    @Test func nonSuccessStatusMapsToHTTPWithBody() async throws {
        let body = #"{"statusCode":500,"message":"boom","error":"Internal Server Error"}"#
        let client = makeStubbedClient(status: 500, body: body)

        do {
            let _: TaskDTO = try await client.get("/tasks/task-1")
            Issue.record("Expected an HTTP error to be thrown")
        } catch let error as APIError {
            guard case .http(let status, let returnedBody) = error else {
                Issue.record("Expected APIError.http, got \(error)")
                return
            }
            #expect(status == 500)
            #expect(returnedBody == body)
        }
    }

    @Test func invalidLinkCode422MapsToLinkCodeInvalid() async throws {
        let body = #"{"code":"INVALID_LINK_CODE","message":"This code is no longer valid"}"#
        let client = makeStubbedClient(status: 422, body: body)

        do {
            let _: TelegramLinkStatusDTO = try await client.get("/assistant/link")
            Issue.record("Expected a linkCodeInvalid error to be thrown")
        } catch let error as APIError {
            guard case .linkCodeInvalid(let message) = error else {
                Issue.record("Expected APIError.linkCodeInvalid, got \(error)")
                return
            }
            #expect(message == "This code is no longer valid")
            #expect(error.isInvalidLinkCode)
        }
    }

    @Test func unrecognized422FallsThroughToHTTP() async throws {
        // A 422 whose body is NOT the typed link envelope must stay a generic
        // `.http`, not be misclassified as linkCodeInvalid.
        let body = #"{"statusCode":422,"message":"validation failed"}"#
        let client = makeStubbedClient(status: 422, body: body)

        do {
            let _: TaskDTO = try await client.get("/tasks/task-1")
            Issue.record("Expected an HTTP error to be thrown")
        } catch let error as APIError {
            guard case .http(let status, _) = error else {
                Issue.record("Expected APIError.http, got \(error)")
                return
            }
            #expect(status == 422)
            #expect(error.isInvalidLinkCode == false)
        }
    }
}
