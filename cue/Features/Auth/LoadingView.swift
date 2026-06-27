//
//  LoadingView.swift
//  cue
//

import SwiftUI

/// Initial splash shown while `AuthStore.bootstrap()` validates any persisted
/// session. Intentionally quiet — the clay seal on flat kraft, the wordmark in
/// Fraunces, and a subtle progress ring.
struct LoadingView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                BrandMark(size: 96)

                Text(verbatim: "Cue")
                    .font(.custom(Typography.serifFamily, size: 46, relativeTo: .largeTitle).weight(.semibold))
                    .foregroundStyle(theme.textPrimary)

                ProgressView()
                    .controlSize(.regular)
                    .tint(theme.primary)
                    .padding(.top, Spacing.sm)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("loading.accessibility")
        }
    }
}

#Preview {
    LoadingView()
}
