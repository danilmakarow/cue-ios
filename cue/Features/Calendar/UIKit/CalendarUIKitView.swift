//
//  CalendarUIKitView.swift
//  cue
//

import SwiftData
import SwiftUI

/// SwiftUI bridge that hosts the UIKit ``CalendarContainerViewController`` — the
/// single zoomable year/month/day calendar surface — inside a SwiftUI view tree.
///
/// UIKit can't read SwiftUI's `@Environment`, so this representable is the seam
/// that projects the SwiftUI world down into the container:
/// - the active ``ThemeColors`` + the current `UITraitCollection` become a
///   value-type ``CalendarTheme`` (rebuilt and re-pushed via ``apply(theme:)``
///   only when either actually changes, to avoid update-loops/flicker);
/// - the `@Environment(\.modelContext)` becomes the ``CalendarDataAdapter`` the
///   scopes read through;
/// - event taps reported by the container flow back out through `onSelectEvent`,
///   which the SwiftUI host wires to a `NavigationStack` push.
///
/// The container fills its parent edge-to-edge; the host decides which safe-area
/// edges to ignore.
struct CalendarUIKitView: UIViewControllerRepresentable {
    let user: UserDTO
    let store: CalendarStore
    /// The active palette's semantic colors, passed from the host's
    /// `@Environment(\.theme)`. A change rebuilds the ``CalendarTheme``.
    let theme: ThemeColors
    /// The store's current view mode, threaded in so a host-driven toggle
    /// (timeline ⇄ list) re-triggers `update` and forwards `viewModeDidChange()`
    /// to the container. Guarded by the coordinator so it fires only on change.
    let viewMode: CalendarViewMode
    /// Forwarded event-card tap. The host maps the occurrence to a navigation
    /// push. Captured each `update` so it never goes stale.
    var onSelectEvent: (OccurrenceVM) -> Void
    /// A pending "jump to date" (deep link / programmatic Today). When non-nil,
    /// `updateUIViewController` drives `container.jump(to:)` and clears it via
    /// `onConsumeJump` so it fires exactly once.
    var pendingJump: Date?
    /// Called after a `pendingJump` has been applied, so the host can reset it
    /// to nil (a one-shot).
    var onConsumeJump: () -> Void = {}

    @Environment(\.modelContext) private var modelContext

    /// Coordinator retains the latest forwarded closure and the last-applied
    /// theme so `updateUIViewController` can early-out when nothing relevant
    /// changed (the redundant-work guard).
    @MainActor
    final class Coordinator {
        var onSelectEvent: (OccurrenceVM) -> Void
        var appliedTheme: CalendarTheme
        var appliedViewMode: CalendarViewMode

        init(
            onSelectEvent: @escaping (OccurrenceVM) -> Void,
            appliedTheme: CalendarTheme,
            appliedViewMode: CalendarViewMode
        ) {
            self.onSelectEvent = onSelectEvent
            self.appliedTheme = appliedTheme
            self.appliedViewMode = appliedViewMode
        }
    }

    /// Builds the coordinator, seeding it with the initial theme so the first
    /// `update` doesn't redundantly re-apply the same theme the VC was built with.
    func makeCoordinator() -> Coordinator {
        // Seeded with a placeholder theme; `makeUIViewController` overwrites it
        // with the real, trait-resolved one it builds for the VC.
        Coordinator(
            onSelectEvent: onSelectEvent,
            appliedTheme: CalendarTheme(colors: theme, traits: UITraitCollection.current),
            appliedViewMode: viewMode
        )
    }

    /// Builds the container with a trait-resolved theme + a data adapter, wires
    /// the event callback through the coordinator, and returns it edge-to-edge.
    func makeUIViewController(context: Context) -> CalendarContainerViewController {
        // `UITraitCollection.current` is valid on the main actor during view
        // construction; `updateUIViewController` later re-resolves from the VC's
        // own (more authoritative) `traitCollection`.
        let resolvedTheme = CalendarTheme(
            colors: theme,
            traits: UITraitCollection.current
        )
        context.coordinator.appliedTheme = resolvedTheme
        context.coordinator.appliedViewMode = viewMode

        let adapter = CalendarDataAdapter(context: modelContext, store: store)
        let container = CalendarContainerViewController(
            user: user,
            store: store,
            adapter: adapter,
            modelContext: modelContext,
            theme: resolvedTheme
        )
        // Route through the coordinator so the closure can be refreshed each
        // update without rebuilding the VC.
        container.onSelectEvent = { [weak coordinator = context.coordinator] occurrence in
            coordinator?.onSelectEvent(occurrence)
        }
        return container
    }

    /// Refreshes the forwarded closure, re-applies the theme only on a real
    /// change (palette or Dynamic Type / appearance), and consumes a pending
    /// jump. Guarded so an unrelated SwiftUI invalidation does no UIKit work.
    func updateUIViewController(_ container: CalendarContainerViewController, context: Context) {
        // Always refresh the closure — cheap, and keeps captured host state fresh.
        context.coordinator.onSelectEvent = onSelectEvent

        // Rebuild the theme from the container's *own* trait collection so a
        // Dynamic Type or userInterfaceStyle change re-scales fonts / re-resolves
        // colors. The VC's traits reflect the live environment after it's hosted.
        let rebuilt = CalendarTheme(
            colors: theme,
            traits: container.traitCollection
        )
        if rebuilt != context.coordinator.appliedTheme {
            context.coordinator.appliedTheme = rebuilt
            container.apply(theme: rebuilt)
        }

        // Forward a host-driven view-mode toggle (timeline ⇄ list) once, on
        // change. The store mutation already happened in the host; this tells
        // the day scope to re-render its visible pages in the new mode.
        if viewMode != context.coordinator.appliedViewMode {
            context.coordinator.appliedViewMode = viewMode
            container.viewModeDidChange()
        }

        // One-shot deep-link / Today jump.
        if let date = pendingJump {
            container.jump(to: date)
            onConsumeJump()
        }
    }
}
