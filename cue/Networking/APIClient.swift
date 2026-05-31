//
//  APIClient.swift
//  cue
//

import Foundation
import os.lock

/// Errors surfaced by the API layer to the UI.
///
/// Each case exposes two distinct strings so the UI can show a friendly
/// one-liner and, on demand, the full diagnostic:
/// - `userMessage` — short, human-readable; safe to show collapsed.
/// - `diagnosticDetail` — the full picture (HTTP status, raw response body,
///   underlying description) for the expanded notification / debugging.
///
/// The design system never imports this type — the bridge in
/// `AppNotification+APIError.swift` maps it onto a generic `AppNotification`,
/// keeping the network and UI layers decoupled.
enum APIError: LocalizedError {
    case transport(String)
    case http(status: Int, body: String)
    case decoding(String)

    // MARK: User-facing message

    /// Short, friendly message for the collapsed notification / alert. Parses
    /// the BE's `{ statusCode, message, error }` body when present so the user
    /// sees the server's own validation text rather than raw JSON.
    var userMessage: String {
        switch self {
        case .transport:
            return String(localized: "error.network.unreachable")
        case .http(let status, let body):
            if let parsed = ServerErrorBody(rawBody: body)?.displayMessage {
                return parsed
            }
            return Self.genericMessage(for: status)
        case .decoding:
            return String(localized: "api.userError.decoding")
        }
    }

    /// Full diagnostic shown when an error notification is expanded. Includes
    /// the HTTP status, the raw response body, and any underlying description —
    /// everything a developer (or a curious user filing a report) would want.
    var diagnosticDetail: String {
        switch self {
        case .transport(let message):
            return String(format: String(localized: "api.error.transport"), message)
        case .http(let status, let body):
            if body.isEmpty {
                return String(format: String(localized: "api.error.httpStatus"), status)
            }
            return String(format: String(localized: "api.error.httpStatusWithBody"), status, body)
        case .decoding(let message):
            return String(format: String(localized: "api.error.decoding"), message)
        }
    }

    /// `LocalizedError` conformance. Kept equal to `userMessage` so existing
    /// `.alert` call sites that read `errorDescription` keep working unchanged.
    var errorDescription: String? {
        userMessage
    }

    /// Convenience for call sites that only care about "session expired / invalid".
    var isUnauthorized: Bool {
        if case .http(let status, _) = self, status == 401 {
            return true
        }
        return false
    }

    /// Friendly fallback copy keyed off the HTTP status family, used when the
    /// response body has no parseable message.
    private static func genericMessage(for status: Int) -> String {
        switch status {
        case 401: return String(localized: "api.userError.sessionExpired")
        case 403: return String(localized: "api.userError.forbidden")
        case 404: return String(localized: "api.userError.notFound")
        case 408, 504: return String(localized: "api.userError.timeout")
        case 429: return String(localized: "api.userError.rateLimited")
        case 400..<500: return String(localized: "api.userError.clientError")
        case 500..<600: return String(localized: "api.userError.serverError")
        default: return String(format: String(localized: "api.userError.unknown"), status)
        }
    }
}

/// Decoded NestJS error envelope (`{ statusCode, message, error }`). `message`
/// may be a single string or an array of validation strings — handled by
/// `FlexibleMessage`. Used only to extract a friendly line from `.http` bodies;
/// failure to decode falls back to a status-based generic message.
private struct ServerErrorBody: Decodable {
    let statusCode: Int?
    let message: FlexibleMessage?
    let error: String?

    /// Best human-readable line: the `message` (joined if it's an array),
    /// falling back to the `error` label.
    var displayMessage: String? {
        if let joined = message?.joined, !joined.isEmpty {
            return joined
        }
        return error
    }

    /// Decodes from a raw JSON body string; nil when the body isn't the
    /// expected envelope (e.g. an HTML error page or empty body).
    init?(rawBody: String) {
        guard
            let data = rawBody.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(ServerErrorBody.self, from: data)
        else {
            return nil
        }
        self = decoded
    }
}

/// `message` field that tolerates either a `String` or `[String]`, matching the
/// BE's `ValidationErrorBody.message` `oneOf` schema.
private enum FlexibleMessage: Decodable {
    case single(String)
    case many([String])

    /// The message(s) as one newline-joined string.
    var joined: String {
        switch self {
        case .single(let value): return value
        case .many(let values): return values.joined(separator: "\n")
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(String.self) {
            self = .single(single)
        } else {
            self = .many(try container.decode([String].self))
        }
    }
}

/// Closure that supplies the current bearer token (or nil when unauthenticated).
/// The closure is called on every request so token refreshes are picked up without re-wiring.
typealias TokenProvider = @Sendable () -> String?

/// Thin URLSession wrapper with async/await + Codable. Adds the caller-supplied
/// bearer token (when present) to every request.
struct APIClient: Sendable {
    /// Shared instance. Token resolution is wired by `AuthStore` at app start.
    nonisolated static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let tokenProvider: TokenProvider

    nonisolated init(
        baseURL: URL = AppConfig.apiBaseURL,
        session: URLSession = .shared,
        tokenProvider: @escaping TokenProvider = { AuthTokenBridge.shared.currentToken() }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// GETs a decodable resource from the given relative path.
    /// Optional `queryItems` are appended as a URL query string.
    nonisolated func get<Response: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> Response {
        var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw APIError.transport("Invalid URL for path: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request)
    }

    /// POSTs a Codable body to the given relative path and decodes the response.
    nonisolated func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    /// PATCHes a Codable body to the given relative path and decodes the response.
    nonisolated func patch<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    /// Runs the request, validates status, decodes the body.
    nonisolated private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        var authenticatedRequest = request
        if let token = tokenProvider() {
            authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: authenticatedRequest)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.transport("Unexpected non-HTTP response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.http(status: httpResponse.statusCode, body: body)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
}

/// Process-wide bridge that lets the sendable `APIClient` read the current
/// access token synchronously. `AuthStore` installs/clears the token via
/// `AuthTokenBridge.shared` whenever it changes.
///
/// Uses `OSAllocatedUnfairLock` (iOS 26 ships with a first-class Sendable lock)
/// to keep reads cheap from any isolation context. Every member is
/// `nonisolated` so the bridge is reachable from Sendable closures and
/// background tasks without hopping to the main actor.
final class AuthTokenBridge: Sendable {
    nonisolated static let shared = AuthTokenBridge()

    private let token = OSAllocatedUnfairLock<String?>(initialState: nil)

    nonisolated init() {}

    nonisolated func currentToken() -> String? {
        token.withLock { $0 }
    }

    nonisolated func setToken(_ newToken: String?) {
        token.withLock { stored in stored = newToken }
    }
}
