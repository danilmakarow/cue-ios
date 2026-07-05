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
    @State private var timePickerExpanded = false

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
        .accessibilityIdentifier("notificationsReport.screen")
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
            loadingScaffold
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

    // MARK: - Loading scaffold

    /// Loading phase that PRESERVES the form scaffold per `Notifications.dc.html`'s
    /// `loading` mode: the section eyebrow, the master "Daily report" card (with a
    /// thin ring spinner where the toggle sits), and the revealed config card with
    /// shimmer placeholders for the channel control and time pill — rather than a
    /// generic full-area centered spinner.
    @ViewBuilder
    private var loadingScaffold: some View {
        SectionEyebrow(title: String(localized: "reports.dailyReport.section"))
            .padding(.leading, Spacing.xs)
            .padding(.bottom, Spacing.xs)

        CueCard(padding: 0) {
            HStack(alignment: .center, spacing: Spacing.md) {
                iconBadge("bell.badge")

                Text("reports.dailyReport.row")
                    .cueText(.body)
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                NotificationsRingSpinner()
                    .accessibilityLabel(Text("reports.loading"))
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: 44)
        }

        CueCard(padding: 0, depth: .valueCut) {
            VStack(spacing: 0) {
                HStack(spacing: Spacing.md) {
                    Text("reports.channel")
                        .cueText(.body)
                        .foregroundStyle(theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    NotificationsShimmerBlock(width: 152, height: 38, cornerRadius: Radius.small)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .frame(minHeight: 44)

                Divider()
                    .overlay(theme.separator)
                    .padding(.leading, Spacing.lg)

                HStack(spacing: Spacing.md) {
                    Text("reports.time")
                        .cueText(.body)
                        .foregroundStyle(theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    NotificationsShimmerBlock(width: 64, height: 30, cornerRadius: Radius.small)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .frame(minHeight: 44)
            }
        }
        .padding(.top, Spacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("reports.loading"))
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
            .padding(.top, Spacing.xl)
            .padding(.horizontal, Spacing.xs)
    }

    // MARK: - Daily report master card

    private var dailyReportCard: some View {
        CueCard(padding: 0) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: Spacing.md) {
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

    /// Inline "Couldn't save — reverted" caption under the master row. The warning
    /// triangle stays `danger`-colored (NOT white/`onAccent`): unlike the round row
    /// icons it sits directly on the white card surface, where a white glyph would be
    /// invisible — the "white to match siblings" rule only applies to glyphs on a
    /// colored tile, of which this screen has none.
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

                if timePickerExpanded {
                    timeWheelTray
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.md)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.16), value: timePickerExpanded)
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
            .frame(width: 152)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 44)
    }

    /// The Time row mirrors the Channel row's "label + trailing control" rhythm
    /// (same `Spacing.lg` inset): a left `Time` body label and a trailing compact
    /// pill button showing the send time in the mono receipt voice, which toggles
    /// the inline wheel tray below — replacing the full-width `InlineDateTimePicker`
    /// well per `Notifications.dc.html` L90-101.
    private var timeRow: some View {
        HStack(spacing: Spacing.md) {
            Text("reports.time")
                .cueText(.body)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            NotificationsTimePill(
                time: store.reportTime,
                isExpanded: timePickerExpanded
            ) {
                timePickerExpanded.toggle()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 44)
    }

    /// The inline wheel tray revealed below the Time row when the pill is tapped —
    /// a recessed elevated card holding a `.wheel` `DatePicker`, matching the spec's
    /// inline picker tray (no sheet, no navigation).
    private var timeWheelTray: some View {
        DatePicker(
            String(localized: "reports.time"),
            selection: Binding(
                get: { store.reportTime },
                set: { store.reportTime = $0 }
            ),
            displayedComponents: [.hourAndMinute]
        )
        .labelsHidden()
        .datePickerStyle(.wheel)
        .tint(theme.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .fill(theme.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1)
                )
        )
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
                .font(.system(size: 16))
                .foregroundStyle(theme.textSecondary)
                .padding(.top, 1)
            Text("reports.inAppBrief.note")
                .cueText(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Small pieces

    /// A 28pt rounded icon badge — the design's round row icon (design-spec §6):
    /// a neutral `surfaceSunken` tile with a centered CLAY (`primary`) glyph. The
    /// container's fixed 28×28 frame plus the centered overlay (and the row's own
    /// `.center` alignment) guarantee the glyph is vertically centered within its
    /// row.
    private func iconBadge(_ systemName: String) -> some View {
        RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
            .fill(theme.surfaceSunken)
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(theme.primary)
            }
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

/// The small eyebrow label that titles a settings group, in the secondary ink +
/// label role. Local to this screen for now. Casing is parameterized so each
/// screen can match its design (Clean wants sentence-case "Daily report" here).
private struct SectionEyebrow: View {
    /// How the eyebrow renders its title text.
    enum TextCase {
        /// Render the title verbatim (sentence/title case as authored).
        case asProvided
        /// Force-uppercase the title.
        case uppercased
    }

    @Environment(\.theme) private var theme
    let title: String
    var textCase: TextCase = .asProvided

    /// The title transformed for the chosen casing.
    private var renderedTitle: String {
        switch textCase {
        case .asProvided: return title
        case .uppercased: return title.uppercased()
        }
    }

    var body: some View {
        Text(renderedTitle)
            .cueText(.label)
            .foregroundStyle(theme.textSecondary)
    }
}

// MARK: - Time pill

/// A compact trailing pill button showing the daily-report send time in the mono
/// receipt voice, with a rotating chevron. Mirrors the spec's Time-row trailing
/// control (`surfaceSunken` fill, 1px border, `Radius.small`=10 radius, mono time)
/// and toggles the inline wheel tray — the page-local replacement for the
/// full-width `InlineDateTimePicker` well on this screen.
private struct NotificationsTimePill: View {
    @Environment(\.theme) private var theme

    let time: Date
    let isExpanded: Bool
    let action: () -> Void

    /// The send time in the mono receipt format (hour + minute), matching the
    /// well's `.time` receipt rendering.
    private var receipt: String {
        time.formatted(.dateTime.hour().minute())
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(receipt)
                    .cueText(.code)
                    .foregroundStyle(theme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
            .background(shape.fill(theme.surfaceSunken))
            .overlay(shape.strokeBorder(isExpanded ? theme.primary : theme.border, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("reports.time"))
        .accessibilityValue(Text(receipt))
    }
}

// MARK: - Loading primitives

/// A thin 18pt ring spinner (2pt stroke, clay leading arc on a faint track) that
/// stands in for the master toggle while settings load — mirroring the spec's
/// `cue-spin` ring rather than a heavyweight petal `ProgressView`.
private struct NotificationsRingSpinner: View {
    @Environment(\.theme) private var theme
    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(theme.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .background(
                Circle().stroke(theme.separator, lineWidth: 2)
            )
            .frame(width: 18, height: 18)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
    }
}

/// A recessed shimmer placeholder block standing in for a control (segmented
/// control, time pill) while settings load — a `surfaceSunken` fill pulsing its
/// opacity, matching the spec's `cue-shimmer` keyframe.
private struct NotificationsShimmerBlock: View {
    @Environment(\.theme) private var theme
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = Radius.small

    @State private var pulsing = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(theme.surfaceSunken)
            .frame(width: width, height: height)
            .opacity(pulsing ? 0.9 : 0.55)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
            .accessibilityHidden(true)
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
