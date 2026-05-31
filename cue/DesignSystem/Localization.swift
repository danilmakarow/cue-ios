//
//  Localization.swift
//  cue
//

import Foundation
import SwiftUI

// MARK: - AppLanguage

/// A language the user can pick in Settings. `.system` follows the device
/// language; the others force a specific localization that the app ships
/// (English and Ukrainian, per the String Catalog).
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case ukrainian

    var id: String { rawValue }

    /// The locale / `.lproj` identifier this maps to, or `nil` for `.system`
    /// (defer to the device language).
    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .ukrainian: return "uk"
        }
    }

    /// Locale to push into SwiftUI's `\.locale` environment so `Text` lookups
    /// and date/number formatting follow the choice. `.system` resolves to the
    /// device's current locale.
    var locale: Locale {
        guard let localeIdentifier else { return .autoupdatingCurrent }
        return Locale(identifier: localeIdentifier)
    }

    /// Picker label. Specific languages show their own autonym (always rendered
    /// the same, regardless of the active UI language); `.system` is localized
    /// so it reads in whatever language is currently active.
    var label: Text {
        switch self {
        case .system: return Text("settings.language.system")
        case .english: return Text(verbatim: "English")
        case .ukrainian: return Text(verbatim: "Українська")
        }
    }
}

// MARK: - LanguageSettings

/// Global, user-editable language preference, persisted to `UserDefaults` and
/// mirrored into the system `AppleLanguages` key. Inject once at the app root
/// via `.environment(_)` and read downstream with
/// `@Environment(LanguageSettings.self)`.
///
/// SwiftUI's `\.locale` (driven by ``locale``) switches most of the UI live.
/// The mirrored `AppleLanguages` value makes the choice fully consistent on the
/// next launch — covering the few strings resolved via `String(localized:)`
/// rather than SwiftUI `Text`, which read the bundle's launch-time language.
@Observable
@MainActor
final class LanguageSettings {
    // MARK: Private

    private enum Keys {
        static let language = "settings.language"
        static let appleLanguages = "AppleLanguages"
    }

    private let userDefaults: UserDefaults

    // MARK: Public

    /// Current language. Writing persists the choice and updates the system
    /// language list.
    var selected: AppLanguage {
        didSet {
            guard selected != oldValue else { return }
            persist(selected)
        }
    }

    /// Locale to bind to the SwiftUI `\.locale` environment.
    var locale: Locale { selected.locale }

    // MARK: Init

    /// Loads the persisted language, falling back to `.system`.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let raw = userDefaults.string(forKey: Keys.language) ?? AppLanguage.system.rawValue
        self.selected = AppLanguage(rawValue: raw) ?? .system
    }

    // MARK: Helpers

    /// Persists the language and mirrors it into `AppleLanguages` so a relaunch
    /// resolves every string (including non-SwiftUI ones) in the chosen language.
    private func persist(_ language: AppLanguage) {
        userDefaults.set(language.rawValue, forKey: Keys.language)
        if let identifier = language.localeIdentifier {
            userDefaults.set([identifier], forKey: Keys.appleLanguages)
        } else {
            userDefaults.removeObject(forKey: Keys.appleLanguages)
        }
    }
}
