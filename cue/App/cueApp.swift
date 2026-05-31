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
                .environment(notifications)
                // Brand canvas as the window's base layer. Auth/Loading paint
                // their own gradients on top; scroll-backed tabs paint system
                // surfaces — this shows through during transitions and behind
                // any non-opaque content.
                .background(Color.appBackground.ignoresSafeArea())
                // Drive both the SwiftUI environment color scheme AND the
                // asset-catalog appearance resolution from the user's choice.
                .preferredColorScheme(themeSettings.appearance.colorScheme)
                .tint(themeSettings.accentColor.color)
        }
        .modelContainer(sharedModelContainer)
    }
}
