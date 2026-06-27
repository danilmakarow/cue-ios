//
//  SearchView.swift
//  cue
//

import SwiftUI
import SwiftData

/// Search screen — a debounced query across the user's tasks, plus optional
/// group-filter chips and a device-local recent-search history.
///
/// Presented modally (a sheet) and reachable globally: the Calendar tab's nav-bar
/// search button flips `AppNavigation.isPresentingSearch`, which drives a `.sheet`
/// hosting this view in `RootView`. The presenting site supplies the
/// `NavigationStack`.
///
/// Layout mirrors `Search.dc.html`: a top chrome (query field + Cancel + a
/// horizontal group-filter chip rail) over a body that swaps between four phases —
/// recent searches (empty query), loading skeletons, result rows, and the
/// no-results / error states. Each result row carries a group-color spine, the
/// title (struck-through-free, since the search DTO has no completion flag), and a
/// monospaced "receipt" line (date · time · group). The query runs through
/// `SearchStore` (debounced); recents persist in `@AppStorage`.
struct SearchView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// Group filter chips, reactively sourced from the on-device group cache —
    /// the same `@Query` the Groups screen uses, so the rail tracks live edits.
    @Query(sort: \EventTaskGroup.sortOrder) private var groups: [EventTaskGroup]

    @State private var store = SearchStore()
    @State private var query: String = ""
    /// Selected group filter; nil == "All".
    @State private var selectedGroupId: String?

    /// Device-local recent-search history, newest-first, JSON-encoded in
    /// `@AppStorage`. Capped at `recentLimit` on write.
    @AppStorage("search.recentQueries") private var recentsRaw: String = "[]"

    /// Max recent searches retained.
    private let recentLimit = 8

    var body: some View {
        VStack(spacing: 0) {
            chrome
            Divider().overlay(theme.separator)
            resultsRegion
        }
        .background(theme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        // Re-run the search whenever the query or the group filter changes; the
        // store debounces and supersedes in-flight requests.
        .onChange(of: query) { runSearch() }
        .onChange(of: selectedGroupId) { runSearch() }
    }

    // MARK: - Top chrome

    @ViewBuilder
    private var chrome: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                searchField
                Button(String(localized: "common.cancel", defaultValue: "Cancel")) {
                    dismiss()
                }
                .cueText(.body)
                .foregroundStyle(theme.accentText)
            }

            if !groups.isEmpty {
                chipRail
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .background(theme.background)
    }

    private var searchFieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
    }

    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.primary)

            TextField(
                String(localized: "search.field.placeholder", defaultValue: "Search tasks"),
                text: $query
            )
            .cueText(.body)
            .foregroundStyle(theme.textPrimary)
            .tint(theme.primary)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit { commitRecent(query) }

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.textSecondary)
                }
                .accessibilityLabel(Text(String(localized: "search.clear", defaultValue: "Clear search")))
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: 42)
        .background(searchFieldShape.fill(theme.surfaceSunken))
        .contentShape(searchFieldShape)
    }

    @ViewBuilder
    private var chipRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                CueChip(
                    String(localized: "search.filter.all", defaultValue: "All"),
                    isSelected: selectedGroupId == nil
                ) {
                    selectedGroupId = nil
                }

                ForEach(groups) { group in
                    CueChip(group.name, isSelected: selectedGroupId == group.id) {
                        selectedGroupId = (selectedGroupId == group.id) ? nil : group.id
                    }
                }
            }
            .padding(.horizontal, Spacing.xxs)
        }
        .scrollClipDisabled()
    }

    // MARK: - Body phases

    @ViewBuilder
    private var resultsRegion: some View {
        switch store.phase {
        case .idle:
            recentView
        case .loading:
            loadingView
        case let .results(hits):
            resultsView(hits)
        case .empty:
            noResultsView
        case let .failed(message):
            ErrorStateView(
                title: String(localized: "search.error.title", defaultValue: "Couldn't search"),
                message: message,
                systemImage: "wifi.exclamationmark",
                retry: { runSearch(force: true) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Recent

    @ViewBuilder
    private var recentView: some View {
        let recents = decodedRecents
        if recents.isEmpty {
            EmptyStateView(
                title: String(localized: "search.empty.title", defaultValue: "Search your tasks"),
                message: String(localized: "search.placeholder.message"),
                systemImage: "magnifyingglass"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    sectionEyebrow(String(localized: "search.recent.title", defaultValue: "Recent"))

                    ForEach(recents, id: \.self) { recent in
                        recentRow(recent)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recentRow(_ recent: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(theme.textSecondary)

            Button {
                query = recent
                commitRecent(recent)
            } label: {
                Text(recent)
                    .cueText(.body)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                removeRecent(recent)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text(String(localized: "common.remove", defaultValue: "Remove")))
        }
        .padding(.horizontal, Spacing.lg)
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) {
            Divider().overlay(theme.separator)
        }
    }

    // MARK: Loading

    @ViewBuilder
    private var loadingView: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    SearchSkeletonRow()
                }
            }
            .padding(Spacing.lg)
        }
        .overlay {
            InlineLoadingRow(label: String(localized: "search.loading", defaultValue: "Searching…"))
        }
        .disabled(true)
    }

    // MARK: Results

    @ViewBuilder
    private func resultsView(_ hits: [TaskSearchResultDTO]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                resultCountReceipt(hits.count)

                LazyVStack(spacing: Spacing.md) {
                    ForEach(hits) { hit in
                        SearchResultRow(hit: hit)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
    }

    @ViewBuilder
    private func resultCountReceipt(_ count: Int) -> some View {
        let noun = count == 1
            ? String(localized: "search.count.result", defaultValue: "result")
            : String(localized: "search.count.results", defaultValue: "results")
        Text("\(count) \(noun)".uppercased())
            .cueText(.codeSmall)
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, Spacing.sm + 2)
            .padding(.vertical, Spacing.xs + 1)
            .background(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .fill(theme.surfaceSunken)
            )
    }

    // MARK: No results

    @ViewBuilder
    private var noResultsView: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        EmptyStateView(
            title: String(
                localized: "search.noResults.title",
                defaultValue: "No matches for “\(trimmed)”"
            ),
            message: selectedGroupId == nil
                ? String(localized: "search.noResults.message", defaultValue: "Try a different word.")
                : String(
                    localized: "search.noResults.message.filtered",
                    defaultValue: "Try a different word, or clear the group filter."
                ),
            systemImage: "magnifyingglass",
            actionTitle: selectedGroupId == nil
                ? nil
                : LocalizedStringKey("Clear filter"),
            action: selectedGroupId == nil ? nil : { selectedGroupId = nil }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Shared bits

    @ViewBuilder
    private func sectionEyebrow(_ title: String) -> some View {
        Text(title.uppercased())
            .cueText(.label)
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm + 2)
            .background(theme.surfaceSunken)
            .overlay(alignment: .bottom) {
                Divider().overlay(theme.separator)
            }
    }

    // MARK: - Behaviour

    /// Hands the current inputs to the store. `force` re-runs even with an
    /// unchanged query (used by the error-state retry).
    private func runSearch(force: Bool = false) {
        if force { store.reset() }
        store.search(query: query, groupId: selectedGroupId)
    }

    // MARK: - Recents persistence

    /// The decoded recent-search list, newest-first.
    private var decodedRecents: [String] {
        guard let data = recentsRaw.data(using: .utf8),
              let list = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return list
    }

    /// Persists a recent list back to `@AppStorage`.
    private func writeRecents(_ list: [String]) {
        guard let data = try? JSONEncoder().encode(list),
              let json = String(data: data, encoding: .utf8)
        else { return }
        recentsRaw = json
    }

    /// Records `term` as the newest recent search (de-duplicated, capped). Empty
    /// terms are ignored.
    private func commitRecent(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = decodedRecents.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        list.insert(trimmed, at: 0)
        if list.count > recentLimit { list = Array(list.prefix(recentLimit)) }
        writeRecents(list)
    }

    /// Removes a single recent search.
    private func removeRecent(_ term: String) {
        writeRecents(decodedRecents.filter { $0 != term })
    }
}

// MARK: - Result row

/// A single search hit: a group-color spine, the title, and a monospaced
/// receipt line (date · time · group). A recurring series shows a repeat glyph.
private struct SearchResultRow: View {
    @Environment(\.theme) private var theme

    let hit: TaskSearchResultDTO

    /// Spine color resolved from the owning group's token, falling back to clay.
    private var spineColor: Color {
        TaskColorResolver.color(from: hit.groupColorHex) ?? theme.primary
    }

    /// The monospaced "receipt" line: weekday + date, then a time (or "all-day"),
    /// rendered in the matched task's own timezone so the anchor reads truthfully.
    private var receipt: String {
        guard let start = hit.startAt else {
            return String(localized: "search.receipt.noDate", defaultValue: "No date")
        }
        var calendar = Calendar.current
        if let zone = TimeZone(identifier: hit.timezone) {
            calendar.timeZone = zone
        }
        let datePart = start.formatted(
            .dateTime
                .weekday(.abbreviated)
                .month(.abbreviated)
                .day()
                .locale(.current)
        )
        if hit.isAllDay {
            let allDay = String(localized: "search.receipt.allDay", defaultValue: "all-day")
            return "\(datePart) · \(allDay)"
        }
        let timePart = start.formatted(date: .omitted, time: .shortened)
        return "\(datePart) · \(timePart)"
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(spineColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: Spacing.xs + 3) {
                HStack(spacing: Spacing.xs + 3) {
                    if hit.isRecurring {
                        Image(systemName: "repeat")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.accentText)
                            .accessibilityLabel(Text(String(localized: "search.recurring", defaultValue: "Repeats")))
                    }
                    Text(hit.title)
                        .cueText(.headline)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                }

                Text(receipt)
                    .cueText(.code)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)

                if let notes = hit.notes, !notes.isEmpty {
                    Text(notes)
                        .italic()
                        .cueText(.callout)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, Spacing.md + 2)
            .padding(.vertical, Spacing.md + 1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(theme.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .cueDepth(.letterpress, radius: Radius.card)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Loading skeleton

/// A pulsing placeholder card matching the result-row silhouette.
private struct SearchSkeletonRow: View {
    @Environment(\.theme) private var theme
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(theme.surfaceSunken)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: Spacing.sm + 2) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(theme.surfaceSunken)
                    .frame(width: 180, height: 17)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(theme.surfaceSunken)
                    .frame(width: 120, height: 13)
            }
            .padding(Spacing.md + 1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(theme.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .cueDepth(.letterpress, radius: Radius.card)
        .opacity(pulse ? 0.55 : 0.85)
        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SearchView()
    }
    .environment(\.theme, AppPalette.kraftInk.colors)
    .modelContainer(for: EventTaskGroup.self, inMemory: true)
}
