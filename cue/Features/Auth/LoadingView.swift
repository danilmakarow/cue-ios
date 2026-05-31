//
//  LoadingView.swift
//  cue
//

import SwiftUI

/// Initial splash shown while `AuthStore.bootstrap()` validates any persisted
/// session. Intentionally quiet — the app logo and a subtle progress ring.
struct LoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.25), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "calendar.badge.clock")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text("Cue")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                ProgressView()
                    .controlSize(.regular)
                    .tint(.accentColor)
                    .padding(.top, 8)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("loading.accessibility")
        }
    }
}

#Preview {
    LoadingView()
}
