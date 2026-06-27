//
//  NotificationsReportView.swift
//  cue
//

import SwiftUI

/// Notifications & Report settings — configure the daily report (delivery time,
/// channel) and the cross-device brief / recap opt-ins that decide what the
/// assistant sends.
///
/// Pushed from `SettingsView` ("Notifications & report" row) within the Settings
/// tab's `NavigationStack`. Owns a `ReportSettingsStore` that round-trips the two
/// settings payloads; every control is optimistic — it flips immediately, the
/// matching `PATCH` fires, and a failed save reverts the field and shows an
/// inline caption.
///
/// Layout follows `Notifications.dc.html`: a large serif title, a "Daily report"
/// master card (enable toggle + inline save state), a floating config card
/// revealed while the report is ON (channel `Push|Telegram`, send time), a
/// JetBrains-Mono timezone footnote, and the brief / recap opt-ins below.
struct NotificationsReportView: View {
    @Environment(\.theme) private var theme
    @Environment(NotificationStore.self) private var notifications

    @State private var store = ReportSettingsStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xxl)
            .animation(.snappy, value: store.enabled)
            .animation(.easeOut(duration: 0.2), value: store.showSaved)
            .animation(.easeOut(duration: 0.2), value: store.showSaveError)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("reports.notifications.title")
        .navigationBarTitleDisplayMode(.large)
        .task {
            store.bind(notifications: notifications)
            await store.load()
        }
    }

    // MARK: - Phase routing

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .idle, .loading:
            LoadingStateView(label: String(localized: "reports.loading"))
                .frame(maxWidth: .infinity, minHeight: 320)
        case .failed(let message):
            ErrorStateView(
                title: String(localized: "reports.error.loadTitle"),
                message: message,
                systemImage: "bell.slash"
            ) {
                Task { await store.load() }
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        case .loaded:
            form
        }
    }

    // MARK: - Loaded form

    @ViewBuilder
    private var form: some View {
        SectionEyebrow(title: String(localized: "reports.dailyReport.section"))
            .padding(.leading, Spacing.xs)
            .padding(.bottom, Spacing.xs)

        dailyReportCard

        if store.enabled {
            configCard
                .padding(.top, Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))

            timezoneFootnote
                .padding(.top, Spacing.xs)
                .padding(.leading, Spacing.xs)
        }

        briefRecapCard
            .padding(.top, Spacing.xl)

        morningBriefNote
            .padding(.top, Spacing.lg)
            .padding(.horizontal, Spacing.xs)
    }

    // MARK: - Daily report master card

    private var dailyReportCard: some View {
        CueCard(padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: Spacing.md) {
                    iconBadge("bell.badge")

                    Text("reports.dailyReport.row")
                        .cueText(.body)
                        .foregroundStyle(theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    savedStamp
                    enableToggle
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .frame(minHeight: 44)

                if store.showSaveError {
                    saveErrorCaption
                }
            }
        }
    }

    /// The master on/off switch. Bound through an action binding so flipping it
    /// drives the optimistic `setEnabled` round-trip rather than mutating local
    /// state silently.
    private var enableToggle: some View {
        CueToggle(
            isOn: Binding(
                get: { store.enabled },
                set: { newValue in Task { await store.setEnabled(newValue) } }
            ),
            accessibilityLabel: String(localized: "reports.dailyReport.row")
        )
    }

    /// The transient green "Saved" stamp shown beside the toggle after a save.
    @ViewBuilder
    private var savedStamp: some View {
        if store.showSaved {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                Text("reports.saved")
                    .cueText(.label)
            }
            .foregroundStyle(theme.success)
            .transition(.opacity)
        }
    }

    /// Inline "Couldn't save — reverted" caption under the master row.
    private var saveErrorCaption: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
            Text("reports.saveError")
                .cueText(.caption)
        }
        .foregroundStyle(theme.danger)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Config card (channel + time), revealed while ON

    private var configCard: some View {
        CueCard(padding: 0, depth: .valueCut) {
            VStack(spacing: 0) {
                channelRow
                Divider()
                    .overlay(theme.separator)
                    .padding(.leading, Spacing.lg)
                timeRow
            }
        }
    }

    private var channelRow: some View {
        HStack(spacing: Spacing.md) {
            Text("reports.channel")
                .cueText(.body)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            SegmentedControl(
                selection: Binding(
                    get: { store.channel },
                    set: { newValue in Task { await store.setChannel(newValue) } }
                ),
                options: [.push, .telegram],
                label: { Self.channelLabel(for: $0) }
            )
            .frame(width: 168)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 44)
    }

    private var timeRow: some View {
        InlineDateTimePicker(
            label: String(localized: "reports.time"),
            date: Binding(
                get: { store.reportTime },
                set: { store.reportTime = $0 }
            ),
            mode: .time
        )
        .padding(Spacing.md)
        .onChange(of: store.reportTime) {
            Task { await store.commitTime() }
        }
    }

    // MARK: - Timezone footnote

    private var timezoneFootnote: some View {
        Text(timezoneFootnoteText)
            .foregroundStyle(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The timezone footnote as a single `AttributedString` — a caption-font prefix,
    /// the zone identifier in the monospaced code font, and a trailing period —
    /// replacing the deprecated `Text + Text` concatenation (iOS 26).
    private var timezoneFootnoteText: AttributedString {
        var prefix = AttributedString(String(localized: "reports.timezone.prefix"))
        prefix.font = Typography.font(for: .caption)

        var identifier = AttributedString(store.timezoneIdentifier)
        identifier.font = Typography.font(for: .code)

        var period = AttributedString(".")
        period.font = Typography.font(for: .caption)

        return prefix + identifier + period
    }

    // MARK: - Brief / recap opt-ins

    private var briefRecapCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionEyebrow(title: String(localized: "reports.assistant.section"))
                .padding(.leading, Spacing.xs)

            CueCard(padding: 0) {
                VStack(spacing: 0) {
                    SettingsRow(
                        String(localized: "reports.morningBrief"),
                        subValue: String(localized: "reports.morningBrief.detail"),
                        trailing: .toggle(
                            Binding(
                                get: { store.morningBriefEnabled },
                                set: { newValue in Task { await store.setMorningBrief(newValue) } }
                            )
                        )
                    )
                    SettingsRow(
                        String(localized: "reports.eveningRecap"),
                        subValue: String(localized: "reports.eveningRecap.detail"),
                        trailing: .toggle(
                            Binding(
                                get: { store.eveningRecapEnabled },
                                set: { newValue in Task { await store.setEveningRecap(newValue) } }
                            )
                        ),
                        showsSeparator: false
                    )
                }
            }
        }
    }

    /// The static "your morning brief always appears in the app" note from the
    /// spec — a quiet reassurance that the in-app brief is unconditional.
    private var morningBriefNote: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "sun.max")
                .font(.system(size: 14))
                .foregroundStyle(theme.textSecondary)
                .padding(.top, 1)
            Text("reports.inAppBrief.note")
                .cueText(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Small pieces

    /// A 28pt rounded icon badge in the recessed gray well, clay glyph — matches
    /// the spec's leading affordance on the master row.
    private func iconBadge(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(theme.primary)
            .frame(width: 28, height: 28)
            .background(theme.surfaceSunken, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
    }

    /// VoiceOver/segment label for a delivery channel.
    private static func channelLabel(for channel: NotificationChannel) -> String {
        switch channel {
        case .push: return String(localized: "reports.channel.push")
        case .telegram: return String(localized: "reports.channel.telegram")
        }
    }
}

// MARK: - Section eyebrow

/// The small uppercased eyebrow label that titles a settings group, in the
/// secondary ink + label role. Local to this screen for now.
private struct SectionEyebrow: View {
    @Environment(\.theme) private var theme
    let title: String

    var body: some View {
        Text(title.uppercased())
            .cueText(.label)
            .foregroundStyle(theme.textSecondary)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationsReportView()
    }
    .environment(NotificationStore())
    .environment(\.theme, AppPalette.kraftInk.colors)
}
