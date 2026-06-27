//
//  SearchStore.swift
//  cue
//

import Foundation
import Observation

/// Drives the Search screen: a debounced text query against `GET /tasks/search`,
/// an optional group-id narrowing filter, and the resulting view phase.
///
/// `@Observable @MainActor` (the house pattern — no `ObservableObject`). The view
/// owns one of these as `@State` and feeds it the live `query` + `groupId`; the
/// store debounces, runs the request off the latest inputs, and exposes a single
/// `phase` the view renders. Recent searches are NOT held here — they're device
/// -local `@AppStorage` on the view, persisted on submit.
///
/// Cancellation: each input change cancels the in-flight debounce/request and
/// starts a fresh one, so only the latest query ever resolves into `phase`.
@Observable
@MainActor
final class SearchStore {
    /// What the results region should render. The view maps each case to a state
    /// component (recent list / skeletons / rows / empty / error).
    enum Phase: Equatable {
        /// No (trimmed) query yet — the view shows recent searches instead.
        case idle
        /// A debounced request is in flight.
        case loading
        /// The request resolved with at least one hit.
        case results([TaskSearchResultDTO])
        /// The request resolved with zero hits for the current query/filter.
        case empty
        /// The request failed; `message` is user-facing.
        case failed(message: String)
    }

    // MARK: Private

    private let api: APIClient

    /// Trailing-debounce + request task; cancelled and replaced on every new input.
    private var searchTask: Task<Void, Never>?

    /// Debounce window before a keystroke turns into a request (250ms).
    private let debounceNanos: UInt64 = 250_000_000

    /// Server result cap — matches the endpoint's clamp ceiling.
    private let resultLimit = 50

    // MARK: Public

    /// Current results phase. The view branches on this.
    private(set) var phase: Phase = .idle

    // MARK: Init

    init(api: APIClient = .shared) {
        self.api = api
    }

    // MARK: - Search

    /// Schedules a debounced search for `query` narrowed to `groupId`. Trims the
    /// query; an empty query short-circuits to `.idle` (the recent-searches state)
    /// and cancels any in-flight request. Call this on every change of either input.
    ///
    /// - Parameters:
    ///   - query: the raw field text (trimmed here).
    ///   - groupId: optional group to narrow to (nil = all groups).
    func search(query: String, groupId: String?) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .idle
            return
        }

        phase = .loading
        searchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: debounceNanos)
            guard !Task.isCancelled else { return }
            await run(query: trimmed, groupId: groupId)
        }
    }

    /// Re-runs `query` (narrowed to `groupId`) immediately, bypassing the debounce,
    /// and awaits the result. Used by pull-to-refresh so the system spinner stays up
    /// until the request resolves. An empty (trimmed) query short-circuits to `.idle`.
    func refresh(query: String, groupId: String?) async {
        searchTask?.cancel()
        searchTask = nil

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .idle
            return
        }

        phase = .loading
        await run(query: trimmed, groupId: groupId)
    }

    /// Clears any pending/in-flight search and returns to the idle (recent) state.
    func reset() {
        searchTask?.cancel()
        searchTask = nil
        phase = .idle
    }

    /// Executes the request and folds the outcome into `phase`. Guards
    /// cancellation after the `await` so a superseded query never overwrites a
    /// newer one's result.
    private func run(query: String, groupId: String?) async {
        do {
            let hits = try await api.searchTasks(q: query, groupId: groupId, limit: resultLimit)
            guard !Task.isCancelled else { return }
            phase = hits.isEmpty ? .empty : .results(hits)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(message: error.localizedDescription)
        }
    }
}
