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
/// - **not connected** — explanation card, an "Open in Telegram" platform row,
///   a pre-fillable code field (`CueField`), "Paste from Clipboard", and the
///   hero clay **Connect** button (disabled while empty or mutating). The code is
///   *never* auto-submitted; the user always confirms. When the last attempt was
///   rejected with the typed `APIError.linkCodeInvalid`, a *persistent* brass
///   notice sits above the CTA and keeps the user here to fetch a fresh code —
///   distinct from a transient error banner.
/// - **connected** — the linked `@handle` + formatted timestamp (a "ticket"
///   `CueCard`) and a destructive **Disconnect** action.
/// - **in progress** — a blocking `.loadingOverlay` while a link/unlink runs.
/// - **fetch failure** — `ErrorStateView` with retry.
///
/// On a successful `link()` the screen dismisses itself (so the sheet closes and
/// a re-tap of the now-burned nonce can't happen here).
struct ConnectTelegramView: View {
    /// The Cue assistant bot handle and its deep link, surfaced as the
    /// "Open in Telegram" affordance on the not-connected form.
    private static let botHandle = "@cue_bot"
    private static let botURL = URL(string: "https://t.me/cue_bot")

    // Copy that has no catalog entry yet. Carried with explicit default values so
    // it renders correctly now and auto-extracts into Localizable.xcstrings later
    // (the strings catalog is owned by another workstream this pass).
    private static let notConnectedTitle = String(
        localized: "telegram.notConnected.title",
        defaultValue: "Your assistant, on Telegram"
    )
    private static let openInTelegram = String(
        localized: "telegram.open",
        defaultValue: "Open in Telegram"
    )
    private static let connectedEyebrow = String(
        localized: "telegram.connected.eyebrow",
        defaultValue: "Assistant active"
    )
    private static let connectedStatus = String(
        localized: "telegram.connected.status",
        defaultValue: "Connected"
    )
    private static let connectedHint = String(
        localized: "telegram.connected.hint",
        defaultValue: "Forward a message to the Cue bot any time to capture it as a task."
    )
    private static let badCodeNoticeText = String(
        localized: "telegram.badCode.notice",
        defaultValue: "That code didn’t work — get a fresh one from the bot."
    )

    @Environment(\.theme) private var theme
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

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
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
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.background.ignoresSafeArea())
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
        // Fill the full visible content height (not a fixed 320 min) so the
        // spinner+label group lands at true vertical center, per the design's
        // justify-content:center loading region — the ScrollView's top padding
        // would otherwise pin it into the upper third.
        LoadingStateView(label: String(localized: "telegram.status.loading"))
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical)
    }

    @ViewBuilder
    private func notConnectedState(viewModel: ConnectTelegramViewModel) -> some View {
        // Owns its own vertical rhythm (spacing 0 + explicit per-element bottom
        // padding) so the title→card and card→row gaps match the design exactly,
        // without the parent VStack's uniform spacing double-counting.
        VStack(alignment: .leading, spacing: 0) {
            // Display title — Source Serif 4 SemiBold 22pt (a ≥17pt page heading, so
            // the editorial serif voice is correct here, not the sans titleM).
            Text(Self.notConnectedTitle)
                .font(.custom(Typography.serifSemiboldFamily, size: 22, relativeTo: .title2))
                .tracking(-0.2)
                .foregroundStyle(theme.textPrimary)
                .padding(.bottom, Spacing.lg)

            // Explanation card — single star eyebrow icon + how-it-works copy.
            CueCard(radius: Radius.small, depth: .valueCut) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    Image(systemName: "star")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(theme.accentText)
                        .padding(.top, 1)
                    Text("telegram.explanation")
                        .cueText(.callout)
                        .foregroundStyle(theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.bottom, Spacing.xxl)

            openInTelegramRow
                .padding(.bottom, Spacing.xl)

            // Linking code field + the clipboard affordance.
            VStack(alignment: .leading, spacing: Spacing.sm) {
                CueField(
                    label: String(localized: "telegram.code.section"),
                    text: $viewModel.code,
                    placeholder: String(localized: "telegram.code.placeholder"),
                    mono: true
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: viewModel.code) { _, _ in
                    // The brass notice describes a *stale* code; the moment the
                    // user changes the value it no longer applies, so retire it.
                    store.clearCodeRejection()
                }

                Button {
                    viewModel.pasteFromClipboard()
                } label: {
                    Label("telegram.paste", systemImage: "doc.on.clipboard")
                        .cueText(.bodyEmphasis)
                        .foregroundStyle(theme.primary)
                }
            }

            Spacer(minLength: Spacing.xl)

            // Persistent brass "bad code" notice — kept distinct from a transient
            // banner: it lives in the form and survives until the code is edited.
            if store.lastCodeRejected {
                badCodeNotice
                    .padding(.bottom, Spacing.md)
            }

            Button {
                Task { await connect(viewModel: viewModel) }
            } label: {
                Label("telegram.connect", systemImage: "seal")
            }
            .buttonStyle(.cue(.decisive))
            .disabled(!viewModel.canSubmit || store.isMutating)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func connectedState(username: String?, linkedAt: String?) -> some View {
        // Eyebrow — olive dot + "assistant active".
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(theme.success)
                .frame(width: 7, height: 7)
            Text(Self.connectedEyebrow)
                .cueText(.label)
                .foregroundStyle(theme.accentText)
        }
        .frame(maxWidth: .infinity)

        // Ticket card — the linked handle, status, and linked-at receipt row.
        CueCard(radius: Radius.small, depth: .valueCut, header: { Text("telegram.title") }) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(theme.primary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(theme.surfaceSunken))
                        .overlay(Circle().strokeBorder(theme.primary, lineWidth: 1.5))
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(handleDisplay(for: username))
                            .cueText(.titleM)
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: Spacing.xs) {
                            Circle()
                                .fill(theme.success)
                                .frame(width: 7, height: 7)
                            Text(Self.connectedStatus)
                                .cueText(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                }

                if let formatted = Self.formattedLinkedAt(linkedAt) {
                    Divider().overlay(theme.separator)
                    LabeledContent {
                        Text(formatted)
                            .cueText(.code)
                            .foregroundStyle(theme.textPrimary)
                    } label: {
                        Text("telegram.linkedAt")
                            .cueText(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }

        Text(Self.connectedHint)
            .cueText(.callout)
            .foregroundStyle(theme.textSecondary)

        Spacer(minLength: Spacing.sm)

        Button(role: .destructive) {
            Task { await store.unlink() }
        } label: {
            Label("telegram.disconnect", systemImage: "trash")
        }
        .buttonStyle(.cue(.destructive))
    }

    @ViewBuilder
    private func failedState(message: String) -> some View {
        ErrorStateView(
            title: String(localized: "telegram.error.loadStatus"),
            message: message,
            systemImage: "wifi.exclamationmark",
            retry: { Task { await store.refreshStatus() } }
        )
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    // MARK: - Components

    /// The "Open in Telegram" platform affordance — a tappable row that deep-links
    /// to the Cue bot. Telegram-blue accents (a real platform colour, deliberately
    /// outside the Cue palette) signal "you're leaving for Telegram".
    @ViewBuilder
    private var openInTelegramRow: some View {
        let telegramBlue = Color(red: 0.133, green: 0.620, blue: 0.851)
        Link(destination: Self.botURL ?? URL(fileURLWithPath: "/")) {
            CueCard(radius: Radius.small, depth: .valueCut) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(telegramBlue)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(telegramBlue.opacity(0.12)))
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(Self.openInTelegram)
                            .cueText(.bodyEmphasis)
                            .foregroundStyle(theme.textPrimary)
                        Text(Self.botHandle)
                            .cueText(.codeSmall)
                            .foregroundStyle(telegramBlue)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(telegramBlue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
    }

    /// Persistent brass advisory shown when the last code was rejected as invalid.
    /// Brass `warning` is a *fill only*, so the surface is a low-opacity brass wash
    /// with a brass edge and dark ink — never brass text.
    @ViewBuilder
    private var badCodeNotice: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.textPrimary)
            Text(Self.badCodeNoticeText)
                .cueText(.caption)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                .fill(theme.warning.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                .strokeBorder(theme.warning.opacity(0.4), lineWidth: 1)
        )
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

#Preview("Not connected") {
    NavigationStack {
        ConnectTelegramView()
    }
    .environment(TelegramLinkStore())
    .environment(NotificationStore())
}
