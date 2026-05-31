//
//  AuthView.swift
//  cue
//

import AuthenticationServices
import SwiftUI
import UIKit

/// Sign-in screen. Currently a single Sign in with Apple button — the product's
/// only authentication path.
struct AuthView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(\.colorScheme) private var colorScheme

    #if DEBUG
    @State private var isDevLoginPresented: Bool = false
    #endif

    var body: some View {
        @Bindable var authStore = authStore

        ZStack {
            LinearGradient(
                colors: [Color.appPrimary.opacity(0.25), Color.appBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                header

                Spacer()

                signInButton

                disclaimer

                if authStore.isAuthenticating {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Signing you in…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .alert(
            "Couldn't sign in",
            isPresented: Binding(
                get: { authStore.errorMessage != nil },
                set: { isPresented in
                    if !isPresented { authStore.errorMessage = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authStore.errorMessage ?? "")
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            devLoginButton
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
        .sheet(isPresented: $isDevLoginPresented) {
            DevLoginSheet()
                .environment(authStore)
        }
        #endif
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Cue")
                .font(.system(size: 44, weight: .bold, design: .rounded))

            Text("Your day, cued just right.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var signInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            handleCompletion(result: result)
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 52)
        .clipShape(.rect(cornerRadius: 14))
        .disabled(authStore.isAuthenticating)
    }

    private var disclaimer: some View {
        Text("We use your Apple ID to create your Cue account. No password required.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    #if DEBUG
    /// Floating pill that opens the dev-login sheet. Debug-only — never ships.
    private var devLoginButton: some View {
        Button {
            isDevLoginPresented = true
        } label: {
            Label("Dev login", systemImage: "hammer.fill")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel("Developer login with a pasted access token")
    }
    #endif

    // MARK: - Actions

    /// Bridges the `SignInWithAppleButton` completion result into `AuthStore`.
    private func handleCompletion(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential
            else {
                authStore.errorMessage = AuthError.appleCredentialMissing.errorDescription
                return
            }
            Task { await authStore.signInWithApple(credential: credential) }

        case .failure(let error):
            let nsError = error as NSError
            // User cancellation isn't an error worth surfacing.
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                return
            }
            authStore.errorMessage = AuthError.appleFailed(error.localizedDescription).errorDescription
        }
    }
}

#Preview {
    AuthView()
        .environment(AuthStore())
}

#if DEBUG

/// Loading phase for the dev-login user list.
private enum DevUsersPhase {
    case loading
    case loaded([UserDTO])
    case failed(String)
}

/// Debug-only sheet that lists every user on the dev backend and lets the
/// developer impersonate one with a single tap. Backed by `GET /auth/dev/users`
/// and `POST /auth/dev/login/:userId`, both gated to `NODE_ENV=development`.
private struct DevLoginSheet: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(\.dismiss) private var dismiss

    @State private var phase: DevUsersPhase = .loading
    @State private var loggingInUserId: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Dev login")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await loadUsers() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isBusy)
                    }
                }
        }
        .task { await loadUsers() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView("Loading users…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let users) where users.isEmpty:
            ContentUnavailableView(
                "No users",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text("Create one with `pnpm dev-cli create-user --appleUserId <id>`.")
            )

        case .loaded(let users):
            List {
                Section {
                    ForEach(users) { user in
                        Button {
                            Task { await login(as: user) }
                        } label: {
                            DevUserRow(user: user, isLoggingIn: loggingInUserId == user.id)
                        }
                        .disabled(isBusy)
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Debug builds only. Tap a user to sign in without going through Apple.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load users", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") {
                    Task { await loadUsers() }
                }
            }
        }
    }

    private var isBusy: Bool {
        loggingInUserId != nil
    }

    // MARK: - Actions

    /// Fetches the dev-user list from the BE and updates `phase`.
    private func loadUsers() async {
        phase = .loading
        do {
            let users = try await authStore.fetchDevUsers()
            phase = .loaded(users)
        } catch let error as APIError {
            phase = .failed(error.errorDescription ?? "Unknown error.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Impersonates the given user via the BE dev-login endpoint and dismisses
    /// the sheet on success.
    private func login(as user: UserDTO) async {
        loggingInUserId = user.id
        defer { loggingInUserId = nil }

        await authStore.signInAsDevUser(userId: user.id)

        if case .authenticated = authStore.state {
            dismiss()
        }
    }
}

/// Single row in the dev-login user list.
private struct DevUserRow: View {
    let user: UserDTO
    let isLoggingIn: Bool

    var body: some View {
        HStack(spacing: 12) {
            avatar
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let email = user.email, !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if isLoggingIn {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }

    private var displayName: String {
        let trimmed = user.displayName?.trimmingCharacters(in: .whitespaces)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return user.email ?? user.appleUserId
    }

    @ViewBuilder
    private var avatar: some View {
        if let image = decodedAvatar {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(.circle)
        } else {
            Circle()
                .fill(.secondary.opacity(0.15))
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var decodedAvatar: UIImage? {
        guard let avatarBase64 = user.avatarBase64, !avatarBase64.isEmpty,
              let data = Data(base64Encoded: avatarBase64),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
}

#endif
