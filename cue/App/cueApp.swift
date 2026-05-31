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

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            EventCalendar.self,
            TaskItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(themeSettings)
                .environment(navigation)
                .environment(authStore)
                .preferredColorScheme(themeSettings.appearance.colorScheme)
                .tint(themeSettings.accentColor.color)
        }
        .modelContainer(sharedModelContainer)
    }
}
