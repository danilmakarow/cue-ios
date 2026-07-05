//
//  OnboardingPages.swift
//  cue
//

import SwiftUI
import UserNotifications

// MARK: - Layout constants

/// The shared content frame for an onboarding page: top-aligned column with the
/// page header and an illustrative card, leaving room for the chrome (Skip,
/// dots, buttons) the container overlays.
private enum OnboardingLayout {
    static let topInset: CGFloat = Spacing.huge + Spacing.xxl
    static let horizontalInset: CGFloat = Spacing.xxxl
}

// MARK: - Page 1 · Calendar value

/// "Your day, in one timeline." A miniature agenda card previewing unified
/// tasks/events, with feature chips.
struct OnboardingCalendarPage: View {
    @Environment(\.theme) private var theme

    let page: OnboardingPage

    var body: some View {
        OnboardingPageScaffold {
            OnboardingHeader(page: page)

            VStack(spacing: 0) {
                agendaRow(
                    icon: "person.2.fill",
                    tint: theme.success,
                    washOpacity: 0.14,
                    title: LocalizedStringResource("onboarding.calendar.row1", defaultValue: "Standup with design"),
                    time: "9:00"
                )
                agendaRow(
                    icon: "stethoscope",
                    tint: theme.warning,
                    washOpacity: 0.18,
                    title: LocalizedStringResource("onboarding.calendar.row2", defaultValue: "Dentist — Dr. Reyes"),
                    time: "11:30"
                )
                agendaRow(
                    icon: "doc.text.fill",
                    tint: theme.accentText,
                    washOpacity: 0.12,
                    title: LocalizedStringResource("onboarding.calendar.row3", defaultValue: "Submit Q3 expense report"),
                    time: "16:00"
                )

                Divider()
                    .overlay(theme.separator)
                    .padding(.horizontal, Spacing.md)

                HStack(spacing: Spacing.sm) {
                    CueChip(String(localized: "onboarding.chip.recurring", defaultValue: "Recurring"), isSelected: false) {}
                    CueChip(String(localized: "onboarding.chip.allDay", defaultValue: "All-day"), isSelected: false) {}
                    CueChip(String(localized: "onboarding.chip.telegram", defaultValue: "Telegram"), isSelected: false) {}
                }
                .allowsHitTesting(false)
                .padding(Spacing.md)
            }
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .cueDepth(.valueCut, radius: Radius.card)
        }
    }

    /// A single agenda preview row: tinted icon tile, title, and a mono time.
    private func agendaRow(
        icon: String,
        tint: Color,
        washOpacity: Double,
        title: LocalizedStringResource,
        time: String
    ) -> some View {
        HStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.opacity(washOpacity))
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }

            Text(title)
                .cueText(.body)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: Spacing.sm)

            Text(verbatim: time)
                .cueText(.code)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
    }
}

// MARK: - Page 2 · Telegram assistant (the wax-seal moment)

/// "Just tell Cue what's next." A Telegram message parsed into a stamped,
/// committed task — the spec's committed-task moment, landing on the canonical
/// ``OliveCheck`` done marker (olive fill + white check) with its built-in stamp
/// spring.
struct OnboardingTelegramPage: View {
    @Environment(\.theme) private var theme

    let page: OnboardingPage

    @State private var stamped = false

    var body: some View {
        OnboardingPageScaffold {
            OnboardingHeader(page: page)

            VStack(spacing: Spacing.md) {
                // Inbound message bubble.
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(String(localized: "onboarding.telegram.channel", defaultValue: "Telegram · @cue_bot"))
                        .cueText(.codeSmall)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.textSecondary)
                    Text(String(localized: "onboarding.telegram.message", defaultValue: "“Lunch with Priya Fri 1pm, remind me 30 min before”"))
                        .cueText(.callout)
                        .foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .background(theme.surfaceSunken)
                .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))

                // Parsed indicator.
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .bold))
                    Text(String(localized: "onboarding.telegram.parsed", defaultValue: "Parsed"))
                        .cueText(.codeSmall)
                        .textCase(.uppercase)
                }
                .foregroundStyle(theme.accentText)

                // Committed task — the canonical olive done-check stamp. Reuses
                // ``OliveCheck`` (success-fill circle + white check), whose own
                // spring/overshoot animates the stamp as `stamped` flips true; no
                // hand-rolled scale/rotate/opacity motion.
                HStack(spacing: Spacing.md) {
                    OliveCheck(isDone: stamped, size: 56)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(String(localized: "onboarding.telegram.taskTitle", defaultValue: "Lunch with Priya"))
                            .cueText(.titleM)
                            .foregroundStyle(theme.textPrimary)
                        Text(String(localized: "onboarding.telegram.taskWhen", defaultValue: "Fri · 13:00"))
                            .cueText(.code)
                            .foregroundStyle(theme.textSecondary)
                        Text(String(localized: "onboarding.telegram.taskReminder", defaultValue: "reminder −30m"))
                            .cueText(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(Spacing.md)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                .cueDepth(.letterpress, radius: Radius.large)
            }
            .padding(Spacing.md)
            .background(theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .cueDepth(.valueCut, radius: Radius.card)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                stamped = true
            }
        }
    }
}

// MARK: - Page 3 · Notifications permission

/// "Gentle nudges, never noise." Explains the two notification kinds and offers
/// Allow / Not now. Allow requests system authorization, registers for remote
/// notifications, and — once an APNs token is available — registers the device
/// with the backend. Already-granted shows a confirmation chip and a Continue.
struct OnboardingNotificationsPage: View {
    @Environment(\.theme) private var theme

    let page: OnboardingPage
    /// Advances the carousel to the next step (sign-in).
    var onContinue: () -> Void

    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var isRequesting = false

    private var alreadyGranted: Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    var body: some View {
        OnboardingPageScaffold {
            OnboardingHeader(page: page)

            if alreadyGranted {
                grantedChip
            }

            VStack(spacing: 0) {
                permissionRow(
                    icon: "bell.fill",
                    tint: theme.accentText,
                    washOpacity: 0.12,
                    title: LocalizedStringResource("onboarding.notifications.task.title", defaultValue: "Task reminders"),
                    detail: LocalizedStringResource("onboarding.notifications.task.detail", defaultValue: "30 min before Dentist"),
                    showsToggle: false
                )
                Divider()
                    .overlay(theme.separator)
                    .padding(.horizontal, Spacing.md)
                permissionRow(
                    icon: "sun.max.fill",
                    tint: theme.warning,
                    washOpacity: 0.18,
                    title: LocalizedStringResource("onboarding.notifications.brief.title", defaultValue: "Morning brief & evening recap"),
                    detail: LocalizedStringResource("onboarding.notifications.brief.detail", defaultValue: "Delivered in-app and on Telegram"),
                    showsToggle: true
                )
            }
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .cueDepth(.valueCut, radius: Radius.card)
        } footer: {
            VStack(spacing: Spacing.sm) {
                OnboardingProgressDots(activeIndex: 2)
                    .padding(.bottom, Spacing.sm)

                Button(action: handlePrimary) {
                    Text(alreadyGranted
                         ? String(localized: "onboarding.continue", defaultValue: "Continue")
                         : String(localized: "onboarding.notifications.allow", defaultValue: "Allow Notifications"))
                }
                .buttonStyle(.cue(.decisive))
                .disabled(isRequesting)

                Button(action: onContinue) {
                    Text(String(localized: "onboarding.notifications.notNow", defaultValue: "Not now"))
                }
                .buttonStyle(.cue(.ghost))
                .fixedSize()
            }
        }
        .task {
            status = await OnboardingNotificationPermission.currentStatus()
        }
    }

    /// "Notifications already on" confirmation chip shown when the OS already
    /// granted authorization before this step.
    private var grantedChip: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
            Text(String(localized: "onboarding.notifications.alreadyOn", defaultValue: "Notifications already on"))
                .cueText(.codeSmall)
                .textCase(.uppercase)
        }
        .foregroundStyle(theme.success)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs + 1)
        .background(theme.successSoft)
        .clipShape(Capsule(style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A row describing one notification kind. The brief row carries a decorative
    /// on-state toggle mirroring the spec (the real toggle lives in Settings).
    private func permissionRow(
        icon: String,
        tint: Color,
        washOpacity: Double,
        title: LocalizedStringResource,
        detail: LocalizedStringResource,
        showsToggle: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.opacity(washOpacity))
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .cueText(.titleM)
                    .foregroundStyle(theme.textPrimary)
                Text(detail)
                    .cueText(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.sm)

            if showsToggle {
                Capsule(style: .continuous)
                    .fill(theme.success)
                    .frame(width: 46, height: 28)
                    .overlay(alignment: .trailing) {
                        Circle()
                            .fill(theme.onAccent)
                            .frame(width: 22, height: 22)
                            .padding(2)
                    }
                    .accessibilityHidden(true)
            }
        }
        .padding(Spacing.md)
    }

    // MARK: - Actions

    /// Allow → request authorization, then advance. Continue (already granted) →
    /// advance immediately.
    private func handlePrimary() {
        if alreadyGranted {
            onContinue()
            return
        }
        Task { await requestPermission() }
    }

    /// Requests notification authorization, registers the device with the backend
    /// if an APNs token is already available, and advances regardless of outcome
    /// (the user can change their mind later in Settings).
    private func requestPermission() async {
        isRequesting = true
        defer { isRequesting = false }

        let outcome = await OnboardingNotificationPermission.request()
        if outcome == .granted {
            await registerDeviceIfTokenAvailable()
        }
        onContinue()
    }

    /// Registers the device with the backend when an APNs token has already been
    /// delivered to `PushTokenInbox`. Best-effort and silent: a missing token
    /// (the common first-run case until an app delegate captures it) or a network
    /// failure must not block onboarding.
    private func registerDeviceIfTokenAvailable() async {
        guard let token = PushTokenInbox.shared.latestToken else { return }
        do {
            _ = try await APIClient.shared.registerDevice(token: token, platform: .ios)
        } catch {
            // Silent: device registration retries from Settings / next launch.
        }
    }
}

// MARK: - Page 4 · Sign in (terminal)

/// The terminal onboarding page: the Cue wordmark over the live Sign in with
/// Apple control supplied by `AuthView`. No Skip, no dots — this is the commit.
struct OnboardingSignInPage: View {
    @Environment(\.theme) private var theme

    var signIn: () -> AnyView

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            BrandMark(size: 96)

            Text(verbatim: "Cue")
                .font(.custom(Typography.serifFamily, size: 50, relativeTo: .largeTitle))
                .tracking(-1)
                .foregroundStyle(theme.textPrimary)

            Text("auth.tagline")
                .cueText(.callout)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
            Spacer()

            signIn()

            Text("auth.disclaimer")
                .cueText(.caption)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(.horizontal, OnboardingLayout.horizontalInset)
        .padding(.bottom, Spacing.huge)
    }
}

// MARK: - Page scaffold

/// Shared top-aligned scaffold: positions the page content beneath the status
/// area with consistent insets, and hosts an optional footer (used by the
/// notifications page for its Allow / Not now stack). The container overlays Skip
/// + dots on top; value pages leave `footer` empty.
struct OnboardingPageScaffold<Content: View, Footer: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.content = content
        self.footer = footer
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Header → illustrative-card gap is 24-26px in the Clean spec
            // (`margin-top: 26px`/`24px`); map to `Spacing.xxl` (24).
            VStack(spacing: Spacing.xxl) {
                content()
            }
            .padding(.top, OnboardingLayout.topInset)
            .padding(.horizontal, OnboardingLayout.horizontalInset)

            Spacer(minLength: Spacing.lg)

            footer()
                .padding(.horizontal, OnboardingLayout.horizontalInset)
                .padding(.bottom, Spacing.huge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

extension OnboardingPageScaffold where Footer == EmptyView {
    /// Convenience for value pages that have no page-owned footer (the container
    /// renders their dots + Continue).
    init(@ViewBuilder content: @escaping () -> Content) {
        self.init(content: content, footer: { EmptyView() })
    }
}

/// The eyebrow + serif title + body block shared by every value page, beneath
/// the brand seal.
struct OnboardingHeader: View {
    @Environment(\.theme) private var theme

    let page: OnboardingPage

    var body: some View {
        VStack(spacing: Spacing.xl) {
            BrandMark(size: 96)

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(page.eyebrow)
                    .cueText(.codeSmall)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.textSecondary)

                Text(page.title)
                    .cueText(.displayM)
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.body)
                    .cueText(.body)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Previews

#Preview("Calendar page") {
    OnboardingCalendarPage(page: OnboardingPage(
        eyebrow: "One place for everything",
        title: "Your day, in one timeline.",
        body: "Tasks and to-dos live together — all-day, timed, or repeating."
    ))
    .background(Color(hex: 0xFFFFFF))
}

#Preview("Telegram page") {
    OnboardingTelegramPage(page: OnboardingPage(
        eyebrow: "Your assistant, on Telegram",
        title: "Just tell Cue what's next.",
        body: "Message the bot in plain words and it schedules, reminds, and reports back."
    ))
    .background(Color(hex: 0xFFFFFF))
}

#Preview("Notifications page") {
    OnboardingNotificationsPage(
        page: OnboardingPage(
            eyebrow: "Stay one step ahead",
            title: "Gentle nudges, never noise.",
            body: "Reminders before tasks, plus your optional morning brief and evening shutdown."
        ),
        onContinue: {}
    )
    .background(Color(hex: 0xFFFFFF))
}
