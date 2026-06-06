//
//  ConnectTelegramView.swift
//  cue
//

import SwiftUI

/// Screen for linking (and unlinking) a Telegram chat to the Cue account.
///
/// Reached two ways: pushed from Settings, or presented as a sheet by the
/// Telegram deep link (with the code pre-filled). It renders five states off
/// `TelegramLinkStore.status`:
/// - **loading** — initial status fetch (`LoadingStateView`).
/// - **not connected** — explanation + a pre-fillable code field, "Paste from
///   Clipboard", and a **Connect** button (disabled while empty or mutating).
///   The code is *never* auto-submitted; the user always confirms.
/// - **connected** — the linked `@handle` + formatted timestamp and a
///   destructive **Disconnect** action.
/// - **in progress** — a blocking `.loadingOverlay` while a link/unlink runs.
/// - **fetch failure** — `ErrorStateView` with retry.
///
/// On a successful `link()` the screen dismisses itself (so the sheet closes and
/// a re-tap of the now-burned nonce can't happen here).
struct ConnectTelegramView: View {
    @Environment(TelegramLinkStore.self) private var store
    @Environment(NotificationStore.self) private var notifications
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ConnectTelegramViewModel

    /// - Parameter prefilledCode: code captured from a deep link, or `""` for a
    ///   manual open from Settings.
    init(prefilledCode: String = "") {
        _viewModel = State(initialValue: ConnectTelegramViewModel(prefilledCode: prefilledCode))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            switch store.status {
            case .unknown, .loading:
                loadingState
            case .notConnected:
                notConnectedState(viewModel: viewModel)
            case .connected(let username, let linkedAt):
                connectedState(username: username, linkedAt: linkedAt)
            case .failed(let message):
                failedState(message: message)
            }
        }
        .navigationTitle("telegram.title")
        .navigationBarTitleDisplayMode(.inline)
        .loadingOverlay(store.isMutating, label: String(localized: "telegram.working"))
        .disabled(store.isMutating)
        .task {
            store.bind(notifications: notifications)
            await store.refreshStatus()
        }
    }

    // MARK: - States

    @ViewBuilder
    private var loadingState: some View {
        Section {
            LoadingStateView(label: String(localized: "telegram.status.loading"))
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func notConnectedState(viewModel: ConnectTelegramViewModel) -> some View {
        Section {
            Text("telegram.explanation")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        Section("telegram.code.section") {
            TextField("telegram.code.placeholder", text: $viewModel.code)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospaced())

            Button {
                viewModel.pasteFromClipboard()
            } label: {
                Label("telegram.paste", systemImage: "doc.on.clipboard")
            }
        }

        Section {
            Button {
                Task { await connect(viewModel: viewModel) }
            } label: {
                Text("telegram.connect")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.canSubmit || store.isMutating)
        }
    }

    @ViewBuilder
    private func connectedState(username: String?, linkedAt: String?) -> some View {
        Section {
            LabeledContent("telegram.connectedAs") {
                Text(handleDisplay(for: username))
                    .foregroundStyle(.secondary)
            }
            if let formatted = Self.formattedLinkedAt(linkedAt) {
                LabeledContent("telegram.linkedAt") {
                    Text(formatted)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("telegram.connected.section")
        }

        Section {
            Button(role: .destructive) {
                Task { await store.unlink() }
            } label: {
                Text("telegram.disconnect")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func failedState(message: String) -> some View {
        Section {
            ErrorStateView(
                title: String(localized: "telegram.error.loadStatus"),
                message: message,
                systemImage: "wifi.exclamationmark",
                retry: { Task { await store.refreshStatus() } }
            )
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Actions

    /// Submits the current code and dismisses on success. Never called
    /// implicitly — only from the explicit Connect button.
    private func connect(viewModel: ConnectTelegramViewModel) async {
        let didLink = await store.link(code: viewModel.trimmedCode)
        if didLink {
            dismiss()
        }
    }

    // MARK: - Formatting

    /// Renders the linked username as `@handle`, or a generic "connected" label
    /// when the backend hasn't supplied one yet.
    private func handleDisplay(for username: String?) -> String {
        guard let username, !username.isEmpty else {
            return String(localized: "telegram.connected.noHandle")
        }
        return username.hasPrefix("@") ? username : "@\(username)"
    }

    /// Formats the backend's ISO-8601 `linkedAt` string into a medium
    /// date + short time for display, falling back to `nil` when absent or
    /// unparseable (the row is then hidden).
    private static func formattedLinkedAt(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }

        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        guard let date = withFractional.date(from: raw) ?? plain.date(from: raw) else {
            return nil
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

#Preview {
    NavigationStack {
        ConnectTelegramView()
    }
    .environment(TelegramLinkStore())
    .environment(NotificationStore())
}
