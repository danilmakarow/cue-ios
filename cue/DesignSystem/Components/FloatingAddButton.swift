//
//  FloatingAddButton.swift
//  cue
//

import SwiftUI

/// Circular floating add button rendered with iOS 26 liquid-glass material.
/// Place with `.overlay(alignment: .bottomTrailing)` on the host view.
struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 56, height: 56)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .accessibilityLabel("newEvent.title")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        FloatingAddButton(action: {})
    }
}
