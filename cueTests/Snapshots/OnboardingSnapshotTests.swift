//
//  OnboardingSnapshotTests.swift
//  cueTests
//
//  Storybook-style snapshot tests for the first-run onboarding carousel
//  (Onboarding.dc.html). The carousel is a single `OnboardingView` that swaps
//  between four pages; each page is also a standalone view that takes a sample
//  `OnboardingPage` value. We snapshot each page individually so a regression on
//  any one card is isolated, plus the full assembled carousel on its first step.
//  Pages render purely from their injected `OnboardingPage` copy and the theme —
//  no SwiftData reads — but we still host them over a fresh in-memory container
//  via `ScreenHost.wrap` so the full app environment (theme, stores) is present,
//  exactly as in the app. The notifications page fires a `.task` to read the OS
//  authorization status; that is async + best-effort and does not block the
//  synchronous capture, which renders the default `.notDetermined` state.
//
//  States (one carousel page each):
//    • calendar      — "Your day, in one timeline." agenda-preview card + chips
//    • telegram      — parsed Telegram message → stamped committed task
//    • notifications — "Gentle nudges, never noise." two permission rows + CTAs
//    • signIn        — terminal Cue wordmark over the Sign in with Apple control
//    • carousel      — the full OnboardingView on its first (calendar) step
//

import SwiftData
import SwiftUI
import Testing
@testable import cue

@MainActor
struct OnboardingSnapshotTests {
    /// Sample copy for the calendar value page (mirrors the app's static page).
    private static let calendarPage = OnboardingPage(
        eyebrow: LocalizedStringResource("onboarding.calendar.eyebrow", defaultValue: "One place for everything"),
        title: LocalizedStringResource("onboarding.calendar.title", defaultValue: "Your day, in one timeline."),
        body: LocalizedStringResource("onboarding.calendar.body", defaultValue: "Tasks and to-dos live together — all-day, timed, or repeating.")
    )

    /// Sample copy for the Telegram assistant page.
    private static let telegramPage = OnboardingPage(
        eyebrow: LocalizedStringResource("onboarding.telegram.eyebrow", defaultValue: "Your assistant, on Telegram"),
        title: LocalizedStringResource("onboarding.telegram.title", defaultValue: "Just tell Cue what's next."),
        body: LocalizedStringResource("onboarding.telegram.body", defaultValue: "Message the bot in plain words and it schedules, reminds, and reports back — morning brief, evening recap.")
    )

    /// Sample copy for the notifications-permission page.
    private static let notificationsPage = OnboardingPage(
        eyebrow: LocalizedStringResource("onboarding.notifications.eyebrow", defaultValue: "Stay one step ahead"),
        title: LocalizedStringResource("onboarding.notifications.title", defaultValue: "Gentle nudges, never noise."),
        body: LocalizedStringResource("onboarding.notifications.body", defaultValue: "Reminders before tasks, plus your optional morning brief and evening shutdown — in Cue and on Telegram.")
    )

    /// A stand-in for the live Sign in with Apple control supplied by `AuthView`,
    /// styled like the real button so the terminal page reads correctly.
    private static func signInControl() -> AnyView {
        AnyView(
            Button("Sign in with Apple") {}
                .buttonStyle(.cue(.decisive))
        )
    }

    /// Page 1 — the calendar value card: brand seal, eyebrow/title/body, and the
    /// miniature agenda preview with feature chips.
    @Test func calendar() {
        let container = MockData.container()

        let page = OnboardingCalendarPage(page: Self.calendarPage)

        #expect(
            SnapshotHarness.record(
                ScreenHost.wrap(page, container: container, authenticated: false),
                named: "onboarding-calendar"
            ) != nil
        )
    }

    /// Page 2 — the Telegram assistant card: a parsed inbound message landing on
    /// the stamped, committed task (olive done-check).
    @Test func telegram() {
        let container = MockData.container()

        let page = OnboardingTelegramPage(page: Self.telegramPage)

        #expect(
            SnapshotHarness.record(
                ScreenHost.wrap(page, container: container, authenticated: false),
                named: "onboarding-telegram"
            ) != nil
        )
    }

    /// Page 3 — the notifications-permission card: two permission rows plus the
    /// Allow / Not now footer. Renders the default `.notDetermined` state (the
    /// `.task` status read is async and does not block capture).
    @Test func notifications() {
        let container = MockData.container()

        let page = OnboardingNotificationsPage(
            page: Self.notificationsPage,
            onContinue: {}
        )

        #expect(
            SnapshotHarness.record(
                ScreenHost.wrap(page, container: container, authenticated: false),
                named: "onboarding-notifications"
            ) != nil
        )
    }

    /// Page 4 — the terminal sign-in page: Cue wordmark, tagline, and the Sign in
    /// with Apple control over the disclaimer.
    @Test func signIn() {
        let container = MockData.container()

        let page = OnboardingSignInPage(signIn: Self.signInControl)

        #expect(
            SnapshotHarness.record(
                ScreenHost.wrap(page, container: container, authenticated: false),
                named: "onboarding-signin"
            ) != nil
        )
    }

    /// The full assembled carousel on its first step (calendar) — exercises the
    /// chrome the container overlays: the Skip affordance, progress dots, and the
    /// Continue button beneath the value card.
    @Test func carousel() {
        let container = MockData.container()

        let screen = OnboardingView(
            signIn: Self.signInControl,
            onFinished: {}
        )

        #expect(
            SnapshotHarness.record(
                ScreenHost.wrap(screen, container: container, authenticated: false),
                named: "onboarding-carousel"
            ) != nil
        )
    }
}
