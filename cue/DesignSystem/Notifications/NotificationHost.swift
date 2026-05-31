//
//  NotificationHost.swift
//  cue
//

import SwiftUI

/// Overlay that renders the live notification stack above all app content.
/// Mounted once near the app root (see `RootView`) via the `.notificationHost()`
/// modifier. Reads the queue from `NotificationStore` in the environment and
/// renders newest-on-top, anchored to the top safe area.
///
/// It is purely a renderer: every behavior decision (timing, expansion,
/// ordering, overflow) lives in the store. Swipe-up and the per-banner close
/// button both call back into the store to dismiss.
struct NotificationHost: View {
    @Environment(NotificationStore.self) private var store

    var body: some View {
        VStack(spacing: 10) {
            ForEach(store.notifications) { notification in
                NotificationBanner(
                    notification: notification,
                    isExpanded: store.isExpanded(notification.id),
                    onToggleExpand: { store.toggleExpanded(notification.id) },
                    onDismiss: { store.dismiss(notification.id) }
                )
                .gesture(swipeToDismiss(notification.id))
                .transition(
                    .move(edge: .top)
                    .combined(with: .opacity)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.snappy, value: store.notifications.map(\.id))
        // The overlay must not eat touches where there are no banners, or it
        // would block the whole app. Only the rendered banners are hit-testable.
        .allowsHitTesting(!store.notifications.isEmpty)
    }

    /// Upward drag past a small threshold dismisses the banner — the natural
    /// gesture for a top-anchored notification.
    private func swipeToDismiss(_ id: UUID) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                guard value.translation.height < -30 else { return }
                store.dismiss(id)
            }
    }
}

// MARK: - View modifier

private struct NotificationHostModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay {
            NotificationHost()
        }
    }
}

extension View {
    /// Mounts the global `NotificationHost` overlay on top of the receiver.
    /// Apply once at the app root, above the content that should be covered by
    /// notifications but inside the `NotificationStore` environment injection.
    func notificationHost() -> some View {
        modifier(NotificationHostModifier())
    }
}

// MARK: - Preview

#Preview {
    /// Drives a live store so the preview shows real post / dismiss behavior.
    struct DemoHost: View {
        @State private var store = NotificationStore()

        var body: some View {
            ZStack {
                LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Button("Post info") {
                        store.post(.info("Synced", message: "Your calendar is up to date."))
                    }
                    Button("Post error (expandable)") {
                        store.post(.error(
                            "Request failed",
                            message: "Couldn't load your tasks.",
                            detail: "HTTP 500\nInternal Server Error\n\nunderlying: The request timed out."
                        ))
                    }
                    Button("Clear all") { store.dismissAll() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.2))
            }
            .environment(store)
            .notificationHost()
        }
    }

    return DemoHost()
}
