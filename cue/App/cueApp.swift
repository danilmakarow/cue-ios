//
//  cueApp.swift
//  cue
//
//  Created by Danil on 19.04.2026.
//

import SwiftUI
import SwiftData

@main
struct cueApp: App {
    @State private var themeSettings = ThemeSettings()
    @State private var navigation = AppNavigation()
    @State private var authStore = AuthStore()
    @State private var notifications = NotificationStore()
    @State private var languageSettings = LanguageSettings()
    @State private var telegramLink = TelegramLinkStore()

    init() {
        // Configure global UIKit chrome (serif navigation-title fonts) once at
        // launch. Idempotent — see CueAppearance.
        CueAppearance.apply()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            EventCalendar.self,
            TaskItem.self,
            EventTaskGroup.self,
            WindowSyncMeta.self,
            SyncCursorState.self,
            SyncMeta.self,
        ])
        #if DEBUG
        if UITestSupport.isActive {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // Force-try: a fresh in-memory store cannot fail to construct here.
            let container = try! ModelContainer(for: schema, configurations: [configuration])
            UITestSupport.seed(into: container)
            return container
        }
        #endif
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // The on-device store is a cache that re-syncs from the backend, so when
            // a schema change leaves the existing store unreadable (no migration plan
            // for, e.g., the occurrence-key remodel), discard it and recreate rather
            // than crashing the app. Safe while there is no local-only data to
            // preserve; revisit with a `SchemaMigrationPlan` once there is.
            Self.destroyStore(at: modelConfiguration.url)
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after resetting the store: \(error)")
            }
        }
    }()

    /// Deletes the SwiftData store at `url` along with its SQLite WAL/SHM
    /// sidecars, so a fresh store matching the current schema can replace an
    /// unreadable one. Best-effort: missing files are ignored.
    private static func destroyStore(at url: URL) {
        let fileManager = FileManager.default
        let storeFiles = [url.path, url.path + "-wal", url.path + "-shm"]
        for path in storeFiles where fileManager.fileExists(atPath: path) {
            try? fileManager.removeItem(atPath: path)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(themeSettings)
                .environment(navigation)
                .environment(authStore)
                .environment(notifications)
                .environment(languageSettings)
                .environment(telegramLink)
                // Make the active palette's semantic colors available app-wide.
                // Switching palette in Settings re-injects this and re-renders
                // every screen that reads `@Environment(\.theme)`.
                .environment(\.theme, themeSettings.palette.colors)
                // Drive SwiftUI's localization (and date/number formatting) from
                // the user's language choice, so most of the UI switches language
                // live without a relaunch.
                .environment(\.locale, languageSettings.locale)
                // Brand canvas as the window's base layer. Auth/Loading paint
                // their own gradients on top; scroll-backed tabs paint system
                // surfaces — this shows through during transitions and behind
                // any non-opaque content.
                .background(themeSettings.palette.colors.background.ignoresSafeArea())
                // Kraft & Ink is light-only for now: pin the light appearance
                // app-wide regardless of the OS/user setting. Dark is deferred —
                // when it ships, restore `themeSettings.appearance.colorScheme`
                // and give the palette a designed dark table.
                .preferredColorScheme(.light)
                // The palette's hero color becomes the app-wide tint, so every
                // `.accentColor` / `.tint` call site follows the chosen option.
                .tint(themeSettings.palette.colors.primary)
                // Rebuild the whole UI when the language changes — a clean in-app
                // "reload" so every screen re-renders in the new language at once
                // rather than leaving stale text behind.
                .id(languageSettings.selected)
        }
        .modelContainer(sharedModelContainer)
    }
}
