//
//  DeepLink.swift
//  cue
//

import Foundation

/// A deep link the app knows how to route, parsed from an incoming `URL`.
///
/// Two entry shapes resolve to the same case:
/// - **Universal Link** — `https://<host>/app/telegram/link?code=<uuid>`, the
///   tappable link the Telegram bot sends (a `cue://` scheme won't linkify in
///   Telegram). Routed via Associated Domains.
/// - **Custom scheme** — `cue://telegram/link?code=<uuid>`, the reliable
///   dev/simulator fallback (and `simctl openurl` target) that needs no
///   provisioning.
///
/// The type is pure (no SwiftUI, no I/O) so it can be unit-tested in isolation;
/// `RootView.onOpenURL` turns a parsed value into navigation state.
enum DeepLink: Equatable, Sendable {
    /// Confirm-link request carrying the single-use linking nonce minted by the
    /// backend. The code is non-empty (blank codes are rejected at parse time).
    case telegramLink(code: String)

    /// Path of the universal-link route, e.g. `https://host/app/telegram/link`.
    private static let universalLinkPath = "/app/telegram/link"

    /// Custom URL scheme registered in `Info.plist` (`CFBundleURLSchemes`).
    private static let customScheme = "cue"

    /// Host segment of the custom-scheme link (`cue://telegram/link`), where the
    /// scheme parser treats `telegram` as the host and `/link` as the path.
    private static let customHost = "telegram"

    /// Path segment of the custom-scheme link (`cue://telegram/link`).
    private static let customPath = "/link"

    /// Query item name carrying the linking nonce on both link shapes.
    private static let codeQueryName = "code"

    /// Parses a supported deep link from `url`, or returns `nil` when the URL is
    /// not a recognized route or is missing a usable `code`.
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let scheme = components.scheme?.lowercased()
        let isUniversalLink = (scheme == "https") && components.path == Self.universalLinkPath
        let isCustomScheme = (scheme == Self.customScheme)
            && (components.host?.lowercased() == Self.customHost)
            && components.path == Self.customPath

        guard isUniversalLink || isCustomScheme else {
            return nil
        }

        guard
            let rawCode = components.queryItems?.first(where: { $0.name == Self.codeQueryName })?.value
        else {
            return nil
        }

        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            return nil
        }

        self = .telegramLink(code: code)
    }
}
