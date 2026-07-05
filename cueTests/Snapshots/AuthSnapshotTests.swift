//
//  AuthSnapshotTests.swift
//  cueTests
//
//  Design-fidelity snapshots for the "auth" screen (AuthView). AuthView branches
//  at init on the device-local `OnboardingFlags.completedKey` UserDefaults flag:
//  when set, it renders the standalone Sign in with Apple screen; when unset, it
//  hosts the intro onboarding carousel whose terminal page carries the same
//  sign-in control. We exercise both by writing the flag BEFORE constructing the
//  view (the init snapshots it once, so live mutation afterwards is irrelevant).
//
//  Reference: states-kit/project/Onboarding.dc.html (terminal sign-in).
//

import SwiftUI
import Testing
@testable import cue

@MainActor
struct AuthSnapshotTests {
    /// Sets the onboarding-completed flag so `AuthView` lands on the standalone
    /// sign-in screen, runs `work`, then restores the prior value so suites don't
    /// leak global UserDefaults state into each other.
    private func withOnboardingCompleted(_ completed: Bool, _ work: () -> Void) {
        let key = OnboardingFlags.completedKey
        let previous = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(completed, forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        work()
    }

    /// Standalone sign-in screen — onboarding already completed. White Clean
    /// canvas, clay BrandMark, "Cue" serif wordmark, tagline, Sign in with Apple
    /// button + disclaimer. This is the design's terminal sign-in state.
    @Test
    func signInScreen() {
        withOnboardingCompleted(true) {
            let view = ScreenHost.wrap(
                AuthView(),
                container: MockData.container(),
                authenticated: false
            )
            #expect(SnapshotHarness.record(view, named: "auth-sign-in") != nil)
        }
    }

    /// First-run flow — onboarding carousel hosting the sign-in path. Renders the
    /// intro carousel's first page (the entry point of the continuous
    /// onboarding-to-auth flow).
    @Test
    func onboardingHosted() {
        withOnboardingCompleted(false) {
            let view = ScreenHost.wrap(
                AuthView(),
                container: MockData.container(),
                authenticated: false
            )
            #expect(SnapshotHarness.record(view, named: "auth-onboarding") != nil)
        }
    }
}
