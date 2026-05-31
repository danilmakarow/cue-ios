//
//  NotificationStore.swift
//  cue
//

import Observation
import SwiftUI

/// App-wide notification queue. The single integration point between any code
/// that wants to surface a banner and the `NotificationHost` overlay that
/// renders them.
///
/// Inject once at the app root via `.environment(_)`, read downstream with
/// `@Environment(NotificationStore.self)`. Follows the same `@Observable` +
/// `@MainActor` shape as `AuthStore` / `CalendarStore`, so it slots into the
/// existing dependency story without singletons or Combine.
///
/// Responsibilities:
/// - Hold the ordered list of live notifications (newest first).
/// - Own each auto-dismissing notification's cancellable timer (`Task.sleep`),
///   cancelling it if the user dismisses early.
/// - Track which expandable notifications are currently expanded.
///
/// It is deliberately ignorant of *why* a notification exists — callers (the
/// API error bridge, feature stores) build `AppNotification` payloads and hand
/// them over. That keeps the design system decoupled from the network layer.
@Observable
@MainActor
final class NotificationStore {
    // MARK: Private

    /// Maximum simultaneously-visible notifications. Older ones beyond this are
    /// dropped from the bottom so the stack can't grow without bound.
    private let maxVisible: Int

    /// Per-notification auto-dismiss timers, keyed by notification id. Held so
    /// an early manual dismissal can cancel the pending removal.
    private var dismissTasks: [UUID: Task<Void, Never>] = [:]

    /// Ids of notifications currently shown in their expanded state.
    private var expandedIDs: Set<UUID> = []

    // MARK: Public

    /// Live notifications, newest first. The host renders this top-down.
    private(set) var notifications: [AppNotification] = []

    // MARK: Init

    /// - Parameter maxVisible: cap on simultaneously-shown banners (default 4).
    init(maxVisible: Int = 4) {
        self.maxVisible = maxVisible
    }

    // MARK: - Posting

    /// Enqueues a notification and, when it auto-dismisses, schedules its
    /// removal. Newest notifications appear at the top of the stack.
    ///
    /// - Parameter notification: the payload to show.
    /// - Returns: the notification's id, so callers can dismiss it later.
    @discardableResult
    func post(_ notification: AppNotification) -> UUID {
        notifications.insert(notification, at: 0)
        trimOverflow()
        scheduleAutoDismissIfNeeded(notification)
        return notification.id
    }

    // MARK: - Dismissal

    /// Removes a notification by id (e.g. user tapped the close button or swiped
    /// it away). Cancels its pending auto-dismiss timer if one was running.
    func dismiss(_ id: UUID) {
        cancelTimer(for: id)
        expandedIDs.remove(id)
        withAnimation(.snappy) {
            notifications.removeAll { $0.id == id }
        }
    }

    /// Clears every notification and cancels all pending timers. Useful on
    /// sign-out or when navigating away from a transient context.
    func dismissAll() {
        for task in dismissTasks.values {
            task.cancel()
        }
        dismissTasks.removeAll()
        expandedIDs.removeAll()
        withAnimation(.snappy) {
            notifications.removeAll()
        }
    }

    // MARK: - Expansion

    /// Whether the given expandable notification is currently expanded.
    func isExpanded(_ id: UUID) -> Bool {
        expandedIDs.contains(id)
    }

    /// Toggles the expanded/collapsed state of an expandable notification.
    /// Expanding it also cancels any auto-dismiss timer — the user is reading
    /// the detail, so it shouldn't vanish from under them. (Collapsing does not
    /// re-arm the timer; that would be surprising.)
    func toggleExpanded(_ id: UUID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
            cancelTimer(for: id)
        }
    }

    // MARK: - Helpers

    /// Schedules a cancellable auto-dismiss for notifications that opted into a
    /// timed lifetime. No-op for `.permanent`.
    private func scheduleAutoDismissIfNeeded(_ notification: AppNotification) {
        guard case .auto(let seconds) = notification.dismissal else { return }

        let id = notification.id
        dismissTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.dismiss(id)
        }
    }

    /// Cancels and forgets a notification's pending timer.
    private func cancelTimer(for id: UUID) {
        dismissTasks[id]?.cancel()
        dismissTasks[id] = nil
    }

    /// Drops the oldest notifications (and their timers) once the visible count
    /// exceeds `maxVisible`. Oldest are at the end of the array.
    private func trimOverflow() {
        guard notifications.count > maxVisible else { return }
        let overflow = notifications.suffix(notifications.count - maxVisible)
        for stale in overflow {
            cancelTimer(for: stale.id)
            expandedIDs.remove(stale.id)
        }
        notifications.removeLast(notifications.count - maxVisible)
    }
}
