//
//  AuthStore.swift
//  cue
//

import AuthenticationServices
import Foundation
import SwiftUI

/// High-level authentication state used to gate the app's UI.
enum AuthState: Sendable {
    /// Hydrating the persisted token and validating it against `/auth/me`.
    case loading

    /// No valid session — show the sign-in screen.
    case unauthenticated

    /// Signed in with the given user profile.
    case authenticated(UserDTO)

    /// Convenience — true while the store is performing a sign-in request.
    var isSigningIn: Bool {
        if case .loading = self { return true }
        return false
    }
}

/// Errors surfaced to the sign-in UI.
enum AuthError: LocalizedError {
    case appleCredentialMissing
    case appleFailed(String)
    case api(APIError)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .appleCredentialMissing:
            return String(localized: "auth.error.appleCredentialMissing")
        case .appleFailed(let message):
            return String(format: String(localized: "auth.error.appleFailed"), message)
        case .api(let error):
            return error.errorDescription
        case .unknown(let message):
            return message
        }
    }
}

/// Shared authentication state. Loads the persisted JWT on init, validates it
/// against `/auth/me`, and drives the `AuthState` the root view reads.
@Observable
@MainActor
final class AuthStore {
    // MARK: Private

    private enum KeychainAccount {
        static let jwt = "accessToken"
    }

    private let keychain: KeychainStore
    private let api: APIClient

    // MARK: Public

    /// Current auth phase. `RootView` branches on this.
    private(set) var state: AuthState = .loading

    /// Last error surfaced by a sign-in attempt (nil when not shown).
    var errorMessage: String?

    /// True while a sign-in network request is in flight.
    private(set) var isAuthenticating: Bool = false

    // MARK: Init

    init(keychain: KeychainStore = KeychainStore(), api: APIClient = .shared) {
        self.keychain = keychain
        self.api = api

        if let token = keychain.get(account: KeychainAccount.jwt) {
            AuthTokenBridge.shared.setToken(token)
        }
    }

    // MARK: Bootstrap

    /// Verifies any persisted token by calling `/auth/me`. Transitions `state`
    /// to `.authenticated` on success, `.unauthenticated` otherwise.
    func bootstrap() async {
        guard AuthTokenBridge.shared.currentToken() != nil else {
            state = .unauthenticated
            return
        }

        do {
            let user: UserDTO = try await api.get("/auth/me")
            state = .authenticated(user)
        } catch let error as APIError where error.isUnauthorized {
            clearSession()
            state = .unauthenticated
        } catch {
            // Network hiccup at launch — keep the token, assume authenticated
            // with a stub profile so the user isn't bounced to the login screen
            // every time they open the app offline.
            state = .unauthenticated
        }
    }

    // MARK: Sign-in

    /// Exchanges an Apple credential for a Cue JWT. Pulls the user's "Me"
    /// contact photo (best-effort) as the initial avatar on first sign-in.
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        errorMessage = nil
        isAuthenticating = true
        defer { isAuthenticating = false }

        guard
            let tokenData = credential.identityToken,
            let identityToken = String(data: tokenData, encoding: .utf8)
        else {
            errorMessage = AuthError.appleCredentialMissing.errorDescription
            return
        }

        let fullName = Self.formattedFullName(from: credential.fullName)
        let avatarBase64 = await MeContactPhotoLoader.load()

        let request = AppleSignInRequest(
            identityToken: identityToken,
            fullName: fullName,
            avatarBase64: avatarBase64,
            timezone: TimeZone.current.identifier
        )

        do {
            let response: AuthResponse = try await api.post("/auth/apple", body: request)
            persistSession(token: response.accessToken)
            state = .authenticated(response.user)
        } catch let error as APIError {
            errorMessage = AuthError.api(error).errorDescription
        } catch {
            errorMessage = AuthError.unknown(error.localizedDescription).errorDescription
        }
    }

    /// Clears the persisted session and returns the UI to the sign-in screen.
    func signOut() {
        clearSession()
        state = .unauthenticated
    }

    #if DEBUG
    /// Debug-only: fetches every user from the BE via `GET /auth/dev/users`.
    /// The backing endpoint is gated on `NODE_ENV=development`, so this fails
    /// with 404 in any other environment.
    func fetchDevUsers() async throws -> [UserDTO] {
        try await api.get("/auth/dev/users")
    }

    /// Debug-only: impersonates the given user by calling
    /// `POST /auth/dev/login/:userId`, persists the returned JWT, and
    /// transitions to `.authenticated`. Compiled out of release builds.
    func signInAsDevUser(userId: String) async {
        errorMessage = nil
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let response: AuthResponse = try await api.post(
                "/auth/dev/login/\(userId)",
                body: EmptyBody()
            )
            persistSession(token: response.accessToken)
            state = .authenticated(response.user)
        } catch let error as APIError {
            errorMessage = AuthError.api(error).errorDescription
        } catch {
            errorMessage = AuthError.unknown(error.localizedDescription).errorDescription
        }
    }
    #endif

    // MARK: Helpers

    /// Persists a newly-issued token to the keychain and pushes it into the
    /// API bridge so subsequent requests carry the Authorization header.
    private func persistSession(token: String) {
        keychain.set(token, account: KeychainAccount.jwt)
        AuthTokenBridge.shared.setToken(token)
    }

    /// Drops any stored token from keychain and the API bridge.
    private func clearSession() {
        keychain.delete(account: KeychainAccount.jwt)
        AuthTokenBridge.shared.setToken(nil)
    }

    /// Joins Apple's `PersonNameComponents` into a display name string, trimmed.
    /// Apple only provides the name on the first sign-in attempt.
    private static func formattedFullName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        let name = formatter.string(from: components).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }
}
