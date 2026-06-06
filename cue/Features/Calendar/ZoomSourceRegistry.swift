//
//  ZoomSourceRegistry.swift
//  cue
//

import Foundation
import Observation

/// Tracks which day-source cells (`MonthDayCell.matchedTransitionSource`) are
/// currently realized on screen in the month scope, so a programmatic
/// deep-link can wait until a given day's zoom source actually exists before
/// pushing the day scope on top of it.
///
/// Why this exists: the interactive zoom-*out* (Day → Month) only engages when
/// the parent month scope currently has a `.matchedTransitionSource(id:)` cell
/// for the same day realized in its view tree. Those cells live in a *lazy*
/// grid, so an off-screen day's source is never registered. Manual drill-in
/// works because the user literally rendered the cell; programmatic opens
/// (cold launch, "go to today") must instead wait for the cell to mount.
///
/// Injected via `.environment(...)` exactly like `CalendarStore`. `present` is
/// kept `private` and is read *only* inside the async wait — never from a
/// SwiftUI `body` — because it churns constantly as the user scrolls the month
/// list, and tracking it in `body` would thrash view updates.
@MainActor
@Observable
final class ZoomSourceRegistry {
    /// Day keys (`startOfDay`-normalized, matching each cell's matched-source
    /// id) whose source cells are currently on screen.
    private var present: Set<Date> = []

    /// One frame at 60 Hz — the poll interval while waiting for a cell.
    private static let pollInterval: Duration = .milliseconds(16)
    /// Safety cap on the wait (~1s) so a deep-link can never hang if a cell
    /// never appears; the caller proceeds in a degraded-but-functional state.
    private static let maxPollIterations = 60

    /// Marks `day`'s source cell as on screen. Call from the cell's `onAppear`
    /// with the same `Date` used as its `matchedTransitionSource` id.
    func markPresent(_ day: Date) {
        present.insert(day)
    }

    /// Marks `day`'s source cell as off screen. Call from the cell's
    /// `onDisappear` with the same `Date` used as its `matchedTransitionSource`
    /// id.
    func markAbsent(_ day: Date) {
        present.remove(day)
    }

    /// Suspends until `day`'s source cell is realized on screen, then returns.
    ///
    /// Returns immediately if the cell is already present. Otherwise polls the
    /// real presence flag once per frame, so it resumes the instant the cell
    /// genuinely mounts (deterministic w.r.t. the actual layout — unlike a
    /// blind fixed sleep). Gives up after ``maxPollIterations`` (~1s) and
    /// returns anyway so the deep-link can still proceed.
    func waitUntilPresent(_ day: Date) async {
        var iterations = 0
        while !present.contains(day) {
            guard iterations < Self.maxPollIterations else { return }
            iterations += 1
            try? await Task.sleep(for: Self.pollInterval)
        }
    }
}
