//
//  Theme.swift
//  cue
//

import SwiftUI

// MARK: - Appearance

/// User-selectable appearance preference. `.system` follows the OS.
enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// Human-readable label for pickers.
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// Value to pass to `.preferredColorScheme(_)`. `nil` defers to the OS.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Accent color

/// Predefined accent colors selectable in Settings.
/// Stored as a raw string so it round-trips through `UserDefaults`.
enum AppAccentColor: String, CaseIterable, Identifiable, Sendable {
    case blue
    case indigo
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case teal

    var id: String { rawValue }

    /// SwiftUI color to tint the app with.
    var color: Color {
        switch self {
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .teal: return .teal
        }
    }

    /// Human-readable label for accessibility and pickers.
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - ThemeSettings

/// Global, user-editable theme preferences persisted to `UserDefaults`.
/// Inject into the environment once at the app root via `.environment(_)`
/// and read downstream with `@Environment(ThemeSettings.self)`.
@Observable
@MainActor
final class ThemeSettings {
    // MARK: Private

    private enum Keys {
        static let appearance = "theme.appearance"
        static let accentColor = "theme.accentColor"
    }

    private let userDefaults: UserDefaults

    // MARK: Public

    /// Current appearance preference. Writing persists to `UserDefaults`.
    var appearance: AppearanceMode {
        didSet {
            userDefaults.set(appearance.rawValue, forKey: Keys.appearance)
        }
    }

    /// Current accent color preference. Writing persists to `UserDefaults`.
    var accentColor: AppAccentColor {
        didSet {
            userDefaults.set(accentColor.rawValue, forKey: Keys.accentColor)
        }
    }

    // MARK: Init

    /// Loads persisted preferences, falling back to defaults (`.system`, `.blue`).
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let appearanceRaw = userDefaults.string(forKey: Keys.appearance)
            ?? AppearanceMode.system.rawValue
        self.appearance = AppearanceMode(rawValue: appearanceRaw) ?? .system

        let accentRaw = userDefaults.string(forKey: Keys.accentColor)
            ?? AppAccentColor.blue.rawValue
        self.accentColor = AppAccentColor(rawValue: accentRaw) ?? .blue
    }
}
