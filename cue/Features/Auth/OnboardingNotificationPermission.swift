//
//  OnboardingNotificationPermission.swift
//  cue
//

import SwiftUI
import UIKit
import UserNotifications

/// Result of the onboarding notification-permission step.
enum NotificationPermissionOutcome: Sendable {
    /// The user granted (or had already granted) notification authorization.
    case granted
    /// The user denied, or the system prompt was dismissed without granting.
    case denied
    /// The request couldn't complete (system error).
    case failed
}

/// Drives the onboarding "Allow Notifications" step: reads the current
/// authorization status, requests it when undetermined, and — once granted —
/// asks the system to register for remote (APNs) notifications.
///
/// React analogy: a tiny side-effect hook (`usePushPermission`) that wraps the
/// imperative permission API behind an `async` call the view can `await`.
///
/// Device registration with the backend (`APIClient.registerDevice`) happens
/// once the APNs token arrives. The token is delivered to
/// `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`, which
/// requires an app delegate the app does not yet own; until that plumbing lands,
/// `registerForRemoteNotifications()` is still called here so the OS-level
/// registration is primed, and `PushTokenInbox` forwards any token that does
/// arrive to the backend. See the spec note in `OnboardingView`.
@MainActor
enum OnboardingNotificationPermission {
    /// The current notification authorization status.
    static func currentStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Requests notification authorization (alert + sound + badge) when it is
    /// still undetermined, then registers for remote notifications on success.
    /// Idempotent: an already-granted status short-circuits to `.granted` and
    /// re-arms remote registration; an already-denied status returns `.denied`.
    static func request() async -> NotificationPermissionOutcome {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus

        switch status {
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            break
        @unknown default:
            break
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return .denied }
            UIApplication.shared.registerForRemoteNotifications()
            return .granted
        } catch {
            return .failed
        }
    }
}

/// A lightweight relay for the APNs device token. When an app delegate is added
/// and receives `didRegisterForRemoteNotificationsWithDeviceToken`, it can post
/// the token here; `OnboardingView` observes it and registers the device with
/// the backend. Until that delegate exists this stays dormant — no token is
/// fabricated, and the backend is never called with a placeholder.
@MainActor
@Observable
final class PushTokenInbox {
    /// The shared inbox, so a future app delegate and the onboarding flow can
    /// rendezvous on the same instance without threading it through init.
    static let shared = PushTokenInbox()

    /// The most recent APNs device token (hex string), or `nil` if none yet.
    private(set) var latestToken: String?

    private init() {}

    /// Records an APNs token delivered by the app delegate, exposing it to any
    /// observer (the onboarding flow) so it can be registered with the backend.
    func receive(token: String) {
        latestToken = token
    }
}
