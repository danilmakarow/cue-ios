//
//  GreetingHeader.swift
//  cue
//

import SwiftUI

/// Top-of-screen greeting with the user's first name, a theme-mode toggle,
/// and a settings button. Greeting phrase is time-of-day aware.
struct GreetingHeader: View {
    let name: String

    init(name: String) {
        self.name = name
    }

    /// Time-of-day greeting phrase, localized via the String Catalog.
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return String(localized: "greeting.morning")
        case 12..<17: return String(localized: "greeting.afternoon")
        case 17..<22: return String(localized: "greeting.evening")
        default: return String(localized: "greeting.hello")
        }
    }

    /// Full greeting line ("Good Morning, Danil") composed from the localized
    /// time-of-day phrase and the user's name. Built in code so the format
    /// key stays stable across languages.
    private var greetingLine: String {
        String(format: String(localized: "greeting.withName"), greeting, name)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(greetingLine)
                .font(.title.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            Button {
                // Mode switch placeholder — no-op for now.
            } label: {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.title3)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("header.switchAppearance.accessibility")

            Button {
                // Settings placeholder — no-op for now.
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("header.settings.accessibility")
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        GreetingHeader(name: "Danil")
        GreetingHeader(name: "Alexandra")
    }
    .padding()
}
