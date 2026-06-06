//
//  ConnectTelegramViewModel.swift
//  cue
//

import Foundation
import UIKit

/// Local form state for `ConnectTelegramView`'s not-connected state: the editable
/// linking code and the clipboard-paste affordance.
///
/// Holds *only* view-local form state — the network calls and shared link status
/// live in `TelegramLinkStore`. Seeded with any deep-link code via
/// `init(prefilledCode:)` + `State(initialValue:)` (the `CalendarRootView` idiom),
/// so the field arrives pre-filled but is never auto-submitted.
@Observable
final class ConnectTelegramViewModel {
    /// The linking code as typed/pasted/pre-filled. Bound to the `TextField`.
    var code: String

    /// - Parameter prefilledCode: code captured from the deep link, or `""` when
    ///   the user opened the screen manually.
    init(prefilledCode: String = "") {
        self.code = prefilledCode
    }

    /// The code with surrounding whitespace/newlines removed — what gets sent.
    var trimmedCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether there's a non-blank code to submit. Combined with the store's
    /// `isMutating` at the call site to gate the Connect button.
    var canSubmit: Bool {
        !trimmedCode.isEmpty
    }

    /// Fills `code` from the system clipboard, trimmed. No-op when the clipboard
    /// holds no usable text.
    func pasteFromClipboard() {
        guard let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !pasted.isEmpty else {
            return
        }
        code = pasted
    }
}
