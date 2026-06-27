//
//  CalendarDataAdapter.swift
//  cue
//

import Foundation
import Observation
import SwiftData

/// The read-side bridge between SwiftData and the UIKit calendar scopes.
///
/// The UIKit scopes do not use SwiftUI `@Query`. Instead each one asks this
/// adapter for a windowed slice of occurrences (mapped to `Sendable`
/// ``OccurrenceVM`` values) and re-runs that fetch whenever ``CalendarStore``'s
/// `revision` changes — observed via ``observeRevision(_:)`` (the reactive
/// replacement for `@Query`'s live updates). The adapter holds the injected
/// `ModelContext` (writes still go through `CalendarStore`) and a reference to
/// the store purely to observe `revision`.
@MainActor
final class CalendarDataAdapter {
    private let context: ModelContext
    private let store: CalendarStore

    /// - Parameters:
    ///   - context: the SwiftData context the scopes read through (same one the
    ///     store writes to).
    ///   - store: the calendar store whose `revision` signals data changes.
    init(context: ModelContext, store: CalendarStore) {
        self.context = context
        self.store = store
    }

    // MARK: - Windowed fetch

    /// Occurrences in the half-open window `[from, to)`, ascending by
    /// `occurrenceStart`. Occurrence-less rows are excluded (the optional start
    /// is coalesced to `.distantPast`, landing below any real range), matching
    /// the store's prune predicate.
    func occurrences(from: Date, to: Date) -> [OccurrenceVM] {
        // Coalesce the optional start to a captured sentinel so the predicate
        // stays a single expression (the macro's requirement), exactly as the
        // store's windowed prune does.
        let sentinel = Date.distantPast
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { task in
                (task.occurrenceStart ?? sentinel) >= from &&
                (task.occurrenceStart ?? sentinel) < to
            },
            sortBy: [SortDescriptor(\.occurrenceStart, order: .forward)]
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.compactMap { row in
            // `asOccurrenceVM()` (in the shared Models mapping) doesn't carry the
            // group color token, so enrich the value here — the adapter owns the
            // read path and `TaskItem.groupColorToken` is local. This is what lets
            // the day rails and month chips/dots paint by GROUP.
            guard let base = row.asOccurrenceVM() else { return nil }
            return base.withGroupColorToken(row.groupColorToken)
        }
    }

    /// Occurrences in `[from, to)` grouped by `CalendarMath.startOfDay`, each
    /// day's bucket sorted ascending by `startAt`. Days with no occurrences are
    /// absent from the dictionary.
    func occurrencesByDay(from: Date, to: Date) -> [Date: [OccurrenceVM]] {
        var buckets: [Date: [OccurrenceVM]] = [:]
        for occurrence in occurrences(from: from, to: to) {
            let day = CalendarMath.startOfDay(occurrence.startAt)
            buckets[day, default: []].append(occurrence)
        }
        for (day, list) in buckets {
            buckets[day] = list.sorted { $0.startAt < $1.startAt }
        }
        return buckets
    }

    /// Per-day occurrence counts for the month containing `forMonth`, keyed by
    /// `CalendarMath.startOfDay`. Drives the month grid's per-day event
    /// indicators. Days with no occurrences are absent from the dictionary.
    func indicatorsByDay(forMonth month: Date) -> [Date: Int] {
        let (from, to) = CalendarMath.monthBounds(month)
        var counts: [Date: Int] = [:]
        for occurrence in occurrences(from: from, to: to) {
            let day = CalendarMath.startOfDay(occurrence.startAt)
            counts[day, default: 0] += 1
        }
        return counts
    }

    // MARK: - Reactivity

    /// Calls `onChange` whenever ``CalendarStore``'s `revision` changes, then
    /// re-arms itself so it keeps firing for every subsequent change.
    ///
    /// `withObservationTracking` is a *one-shot* observation — its `onChange`
    /// fires exactly once. To get continuous updates the registration must be
    /// re-established each cycle. We read `revision` inside the tracked
    /// `apply` block (establishing the dependency) and, in `onChange`, first
    /// re-register, then invoke the caller's closure. Forgetting to re-arm is
    /// the classic bug that makes reactivity die after the first change.
    ///
    /// Returns nothing: the observation lives as long as the store keeps
    /// mutating `revision` and `onChange` keeps re-registering. A scope holds
    /// this adapter for its lifetime, which keeps the chain alive.
    func observeRevision(_ onChange: @escaping () -> Void) {
        withObservationTracking {
            // Establish the dependency on `revision` without acting on the value.
            _ = store.revision
        } onChange: { [weak self] in
            // `onChange` runs when `revision` is about to change. Re-arm first so
            // the NEXT change is also observed, then notify on the main actor
            // (Observation may invoke this off the registering context).
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observeRevision(onChange)
                onChange()
            }
        }
    }
}
