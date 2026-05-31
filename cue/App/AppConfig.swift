//
//  AppConfig.swift
//  cue
//

import Foundation

/// Build-time configuration injected via `Config/*.xcconfig`.
///
/// Each value is set as `INFOPLIST_KEY_<Key>` in xcconfig, lands in the
/// generated `Info.plist`, and is read here at runtime.
enum AppConfig {
    /// Base URL of the Cue backend (per-build-configuration, set in
    /// `Config/Debug.xcconfig` and `Config/Release.xcconfig`).
    nonisolated static let apiBaseURL: URL = {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: Key.apiBaseURL) as? String,
            !raw.isEmpty,
            let url = URL(string: raw)
        else {
            fatalError("APIBaseURL missing or invalid in Info.plist — check Config/*.xcconfig")
        }
        return url
    }()

    private enum Key {
        static let apiBaseURL = "APIBaseURL"
    }
}
