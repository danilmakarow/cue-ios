//
//  SettingsView.swift
//  cue
//

import SwiftUI
import UIKit

/// Settings tab — profile summary, appearance, and sign-out.
struct SettingsView: View {
    @Environment(ThemeSettings.self) private var theme
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        @Bindable var theme = theme

        Form {
            if case .authenticated(let user) = authStore.state {
                Section {
                    UserProfileRow(user: user)
                }
            }

            Section("Appearance") {
                Picker("Theme", selection: $theme.appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Accent Color")
                    AccentColorPicker(selection: $theme.accentColor)
                }
                .padding(.vertical, 4)
            }

            if case .authenticated = authStore.state {
                Section {
                    Button(role: .destructive) {
                        authStore.signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Log Out")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .safeAreaInset(edge: .bottom) {
            AppTabBar()
        }
    }
}

// MARK: - User profile row

/// Avatar + name + email row rendered at the top of Settings.
private struct UserProfileRow: View {
    let user: UserDTO

    var body: some View {
        HStack(spacing: 14) {
            avatar
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.headline)
                    .lineLimit(1)
                if let email = user.email, !email.isEmpty {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        let trimmed = user.displayName?.trimmingCharacters(in: .whitespaces)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return "Signed in"
    }

    @ViewBuilder
    private var avatar: some View {
        if let image = decodedAvatar {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(.circle)
                .overlay {
                    Circle().strokeBorder(.tint, lineWidth: 1.5)
                }
                .accessibilityLabel("Your profile photo")
        } else {
            Circle()
                .fill(.secondary.opacity(0.15))
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .overlay {
                    Circle().strokeBorder(.tint, lineWidth: 1.5)
                }
                .accessibilityLabel("Default profile avatar")
        }
    }

    private var decodedAvatar: UIImage? {
        guard let avatarBase64 = user.avatarBase64, !avatarBase64.isEmpty,
              let data = Data(base64Encoded: avatarBase64),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
}

// MARK: - Accent color picker

/// Row of tappable colored circles — replaces SwiftUI's palette-style picker,
/// which drops per-option tint inside a Form and renders every swatch black.
private struct AccentColorPicker: View {
    @Binding var selection: AppAccentColor

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AppAccentColor.allCases) { accent in
                swatch(for: accent)
            }
        }
    }

    private func swatch(for accent: AppAccentColor) -> some View {
        let isSelected = selection == accent
        return Button {
            selection = accent
        } label: {
            Circle()
                .fill(accent.color)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .strokeBorder(.primary, lineWidth: isSelected ? 2 : 0)
                        .padding(-3)
                }
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accent.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(ThemeSettings())
    .environment(AppNavigation())
    .environment(AuthStore())
}
