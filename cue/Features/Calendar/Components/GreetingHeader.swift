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

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Hello"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(greeting), \(name)")
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
            .accessibilityLabel("Switch appearance mode")

            Button {
                // Settings placeholder — no-op for now.
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
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
