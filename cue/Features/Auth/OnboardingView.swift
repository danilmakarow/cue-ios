//
//  OnboardingView.swift
//  cue
//

import SwiftUI

// MARK: - Onboarding completion gate

/// Device-local flag recording whether the intro carousel has been seen. Stored
/// in `UserDefaults` via `@AppStorage` so the carousel shows exactly once per
/// install, independent of auth state (it persists across sign-out / sign-in).
///
/// React analogy: a `localStorage`-backed boolean read once on mount to decide
/// whether to render the first-run tour.
enum OnboardingFlags {
    /// `UserDefaults` key for "the intro carousel has been completed or skipped".
    static let completedKey = "onboarding.completed.v1"
}

// MARK: - Onboarding page model

/// One intro page in the onboarding carousel. The terminal page (`signIn`) is
/// not data-driven — it renders the live Sign in with Apple control — so it is
/// represented as its own case rather than an `OnboardingPage` value.
private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case calendar
    case telegram
    case notifications
    case signIn

    var id: Int { rawValue }

    /// Total number of progress dots (the sign-in page hides the dots).
    static var dotCount: Int { allCases.count - 1 }
}

/// The static content of a value-proposition page (the first three steps).
/// File-internal (not `private`) so the page structs in `OnboardingPages.swift`
/// can consume it.
///
/// Copy is carried as `LocalizedStringResource` with inline `defaultValue`s — the
/// codebase's pattern (see `PersonaStore`) for strings that render correct
/// English immediately and auto-extract into `Localizable.xcstrings` for
/// translation later, without this workstream editing the shared catalog.
struct OnboardingPage {
    let eyebrow: LocalizedStringResource
    let title: LocalizedStringResource
    let body: LocalizedStringResource
}

// MARK: - OnboardingView

/// First-run intro carousel: three value pages, a notifications-permission step,
/// and a terminal Sign in with Apple page. Honors Skip (jumps straight to
/// sign-in) and persists completion device-locally so it shows once.
///
/// Hosted by `AuthView` while `OnboardingFlags.completedKey` is unset; the final
/// page reuses the existing Sign in with Apple path, so onboarding and auth are a
/// single continuous flow rather than two screens to coordinate.
struct OnboardingView: View {
    @Environment(\.theme) private var theme

    /// The live sign-in control, supplied by `AuthView` so the terminal page
    /// drives the real auth path without duplicating it. Returns a type-erased
    /// view because it crosses from `AuthView` into the page tree.
    var signIn: () -> AnyView

    /// Marks onboarding complete (carousel dismisses, sign-in screen remains).
    var onFinished: () -> Void

    @State private var step: OnboardingStep = .calendar

    private static let calendarPage = OnboardingPage(
        eyebrow: LocalizedStringResource("onboarding.calendar.eyebrow", defaultValue: "One place for everything"),
        title: LocalizedStringResource("onboarding.calendar.title", defaultValue: "Your day, in one timeline."),
        body: LocalizedStringResource("onboarding.calendar.body", defaultValue: "Tasks and to-dos live together — all-day, timed, or repeating.")
    )

    private static let telegramPage = OnboardingPage(
        eyebrow: LocalizedStringResource("onboarding.telegram.eyebrow", defaultValue: "Your assistant, on Telegram"),
        title: LocalizedStringResource("onboarding.telegram.title", defaultValue: "Just tell Cue what's next."),
        body: LocalizedStringResource("onboarding.telegram.body", defaultValue: "Message the bot in plain words and it schedules, reminds, and reports back — morning brief, evening recap.")
    )

    private static let notificationsPage = OnboardingPage(
        eyebrow: LocalizedStringResource("onboarding.notifications.eyebrow", defaultValue: "Stay one step ahead"),
        title: LocalizedStringResource("onboarding.notifications.title", defaultValue: "Gentle nudges, never noise."),
        body: LocalizedStringResource("onboarding.notifications.body", defaultValue: "Reminders before tasks, plus your optional morning brief and evening shutdown — in Cue and on Telegram.")
    )

    var body: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()

            // One page at a time, cross-faded with a horizontal slide so advancing
            // reads as moving forward through the deck (the spec's pageSlide).
            Group {
                switch step {
                case .calendar:
                    OnboardingCalendarPage(page: Self.calendarPage)
                        .transition(pageSlide)
                case .telegram:
                    OnboardingTelegramPage(page: Self.telegramPage)
                        .transition(pageSlide)
                case .notifications:
                    OnboardingNotificationsPage(
                        page: Self.notificationsPage,
                        onContinue: advance
                    )
                    .transition(pageSlide)
                case .signIn:
                    OnboardingSignInPage(signIn: signIn)
                        .transition(pageSlide)
                }
            }
            .id(step)

            VStack {
                topBar
                Spacer()
                footer
            }
        }
        .animation(.easeInOut(duration: 0.28), value: step)
        .onAppear(perform: persistImmediatelyIfTerminal)
    }

    // MARK: - Chrome

    /// The Skip affordance, hidden on the terminal sign-in page (there is nothing
    /// left to skip). Skipping persists completion and jumps to sign-in.
    @ViewBuilder
    private var topBar: some View {
        HStack {
            Spacer()
            if step != .signIn {
                Button(action: skip) {
                    Text(String(localized: "onboarding.skip", defaultValue: "Skip ›"))
                }
                .buttonStyle(.cue(.ghost))
                .fixedSize()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    /// Progress dots + primary advance button for the value pages. The
    /// notifications page owns its own buttons (Allow / Not now) and the sign-in
    /// page owns the Apple button, so the footer is empty for those.
    @ViewBuilder
    private var footer: some View {
        switch step {
        case .calendar, .telegram:
            VStack(spacing: Spacing.lg) {
                OnboardingProgressDots(activeIndex: step.rawValue)
                Button(action: advance) {
                    Text(String(localized: "onboarding.continue", defaultValue: "Continue"))
                }
                .buttonStyle(.cue(.decisive))
            }
            .padding(.horizontal, Spacing.xxxl)
            .padding(.bottom, Spacing.huge)
        case .notifications, .signIn:
            EmptyView()
        }
    }

    // MARK: - Motion

    /// Forward-moving slide: new page enters from the trailing edge, old page
    /// leaves toward the leading edge, both fading — the spec's pageSlide.
    private var pageSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    // MARK: - Actions

    /// Advances to the next step in order. Landing on the terminal sign-in page
    /// records completion so the intro never replays on a later launch.
    private func advance() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        step = next
        if next == .signIn { persistCompleted() }
    }

    /// Skips the remaining intro, persists completion, and jumps to the terminal
    /// sign-in page so the user can still authenticate.
    private func skip() {
        persistCompleted()
        step = .signIn
    }

    /// Persists the completion flag so the tour never reappears, and notifies the
    /// host. The host snapshots its branch on mount, so this does NOT yank the
    /// user off the carousel's terminal sign-in page — it only takes effect on
    /// the next launch.
    private func persistCompleted() {
        UserDefaults.standard.set(true, forKey: OnboardingFlags.completedKey)
        onFinished()
    }

    /// If the view appears already on the terminal page (e.g. re-entry), record
    /// completion so a later relaunch goes straight to sign-in.
    private func persistImmediatelyIfTerminal() {
        if step == .signIn { persistCompleted() }
    }
}

// MARK: - Progress dots

/// The horizontal run of progress dots. The active dot widens into an olive pill;
/// the rest are neutral separator dots — matching the spec's active-pill motif.
/// File-internal (not `private`) so the notifications page can render its own row.
struct OnboardingProgressDots: View {
    @Environment(\.theme) private var theme

    let activeIndex: Int

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<OnboardingStep.dotCount, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == activeIndex ? theme.success : theme.separator)
                    .frame(width: index == activeIndex ? 18 : 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: activeIndex)
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Carousel") {
    OnboardingView(
        signIn: { AnyView(Button("Sign in with Apple") {}.buttonStyle(.cue(.primary))) },
        onFinished: {}
    )
}

#Preview("Progress dots") {
    VStack(spacing: 24) {
        OnboardingProgressDots(activeIndex: 0)
        OnboardingProgressDots(activeIndex: 1)
        OnboardingProgressDots(activeIndex: 2)
    }
    .padding(40)
    .background(Color(hex: 0xFFFFFF))
}
