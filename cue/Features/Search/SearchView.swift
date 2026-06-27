//
//  SearchView.swift
//  cue
//

import SwiftUI

/// Search screen — a query field plus results across tasks and events.
///
/// Presented modally (a sheet) and reachable globally: the Calendar tab's nav-bar
/// search button flips `AppNavigation.isPresentingSearch`, which drives a `.sheet`
/// hosting this view in `RootView`. The presenting site supplies the
/// `NavigationStack` and a "Done" dismiss control, so the body is just the field
/// and results.
///
// TODO(4c): Search workstream builds this out — a `CueField` query bound to a
// debounced search, sectioned results (tasks / events) tapping through to detail,
// and the empty / no-results / loading states (`EmptyStateView`,
// `LoadingStateView`). Wire the query through the search store/endpoint.
struct SearchView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        EmptyStateView(
            title: String(localized: "search.title"),
            message: String(localized: "search.placeholder.message"),
            systemImage: "magnifyingglass"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("search.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
    .environment(\.theme, AppPalette.kraftInk.colors)
}
