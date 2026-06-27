//
//  SettingsRow.swift
//  cue
//
//  The reusable settings / detail list row. One layout — leading label (+ an
//  optional mono sub-value in the receipt voice) and a trailing slot — used by
//  Settings, Account, Notifications, and detail screens. React analogy: a
//  `<ListRow>` primitive with a polymorphic `trailing` slot.
//

import SwiftUI

/// What sits at the trailing edge of a `SettingsRow`.
enum SettingsRowTrailing {
    /// A navigation affordance — a tertiary `chevron.right`. The whole row is a
    /// tappable destination.
    case navigation
    /// A read-only mono value (IDs, dates, counts) in the receipt voice.
    case value(String)
    /// A binary control bound to `isOn`. Renders an olive (ON) system toggle.
    case toggle(Binding<Bool>)
    /// A status stamp.
    case badge(text: String, tone: CueBadgeTone)
    /// Nothing — a plain informational row.
    case plain
}

/// A single grouped-list row. The leading column is a `body` label with an
/// optional `code`-voice sub-value beneath it; the trailing column is one of the
/// `SettingsRowTrailing` slots. A 1px separator hairline sits under the row
/// unless suppressed (the last row in a group drops it).
///
/// For a `.navigation` row, wrap the `SettingsRow` in a `Button` (or a
/// `NavigationLink`) at the call site — the row renders the chevron but stays
/// presentation-only, so it composes with either.
struct SettingsRow: View {
    @Environment(\.theme) private var theme

    private let label: String
    private let subValue: String?
    private let trailing: SettingsRowTrailing
    private let showsSeparator: Bool

    /// - Parameters:
    ///   - label: the primary row label.
    ///   - subValue: an optional mono sub-value rendered under the label.
    ///   - trailing: the trailing slot (default `.plain`).
    ///   - showsSeparator: whether to draw the bottom hairline (default `true`;
    ///     pass `false` for the final row in a group).
    init(
        _ label: String,
        subValue: String? = nil,
        trailing: SettingsRowTrailing = .plain,
        showsSeparator: Bool = true
    ) {
        self.label = label
        self.subValue = subValue
        self.trailing = trailing
        self.showsSeparator = showsSeparator
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(label)
                        .cueText(.body)
                        .foregroundStyle(theme.textPrimary)
                    if let subValue {
                        Text(subValue)
                            .cueText(.code)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                trailingView
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md + 1)

            if showsSeparator {
                Rectangle()
                    .fill(theme.separator)
                    .frame(height: 1)
                    .padding(.leading, Spacing.lg)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var trailingView: some View {
        switch trailing {
        case .navigation:
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
        case let .value(text):
            Text(text)
                .cueText(.code)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        case let .toggle(isOn):
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(theme.success)
        case let .badge(text, tone):
            CueBadge(text, tone: tone)
        case .plain:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview("SettingsRow") {
    struct Demo: View {
        @Environment(\.theme) private var theme
        @State private var notifications = true
        @State private var mondayStart = false

        var body: some View {
            VStack(spacing: 0) {
                SettingsRow("Account", subValue: "sofia@kraftink.co", trailing: .navigation)
                SettingsRow("Notifications", trailing: .toggle($notifications))
                SettingsRow("Week starts Monday", trailing: .toggle($mondayStart))
                SettingsRow("Calendar ID", trailing: .value("CAL-2F9A"))
                SettingsRow("Telegram", trailing: .badge(text: "Linked", tone: .done))
                SettingsRow("Sync", trailing: .badge(text: "Pending", tone: .pending))
                SettingsRow("Version", trailing: .value("1.0.0"), showsSeparator: false)
            }
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .cueDepth(.letterpress, radius: Radius.card)
            .padding(Spacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.surfaceGrouped)
        }
    }
    return Demo()
        .environment(\.theme, AppPalette.kraftInk.colors)
}
