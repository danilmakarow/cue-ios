//
//  LoadingStateView.swift
//  cue
//

import SwiftUI

/// Reusable loading affordances for content areas *inside* the app, distinct
/// from `LoadingView` (the branded full-screen splash shown only during auth
/// bootstrap).
///
/// Three sizes for three situations — see
/// `docs/specs/notifications-and-states.md` for when to reach for which:
/// - `LoadingStateView`        — a whole screen/section has no content yet.
/// - `InlineLoadingRow`        — a footer/row while more items stream in.
/// - `.loadingOverlay(_:)`     — a dimmed spinner over content already on screen
///                               during a blocking refresh.

// MARK: - Full-area loading

/// Centered progress indicator with an optional label, sized to fill its
/// container. Use as the body of a screen/section whose primary content is
/// still loading and there's nothing else to show yet.
struct LoadingStateView: View {
    /// Optional caption under the spinner, e.g. "Loading your tasks…".
    let label: String?

    /// - Parameter label: optional caption (default none).
    init(label: String? = nil) {
        self.label = label
    }

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            if let label {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label ?? String(localized: "common.loading"))
    }
}

// MARK: - Inline loading row

/// Compact horizontal spinner + label, sized for a list footer or a section
/// header while additional content streams in (pagination, background sync).
struct InlineLoadingRow: View {
    /// Caption beside the spinner.
    let label: String

    /// - Parameter label: caption text (default "Loading…").
    init(label: String = String(localized: "common.loading")) {
        self.label = label
    }

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

// MARK: - Loading overlay

private struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    let label: String?

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.08)
                            .ignoresSafeArea()
                        LoadingStateView(label: label)
                            .padding(24)
                            .glassEffect(.regular, in: .rect(cornerRadius: 20))
                            .fixedSize()
                    }
                    .transition(.opacity)
                }
            }
            .animation(.snappy, value: isLoading)
    }
}

extension View {
    /// Overlays a dimmed, glass-backed spinner while `isLoading` is true — for a
    /// blocking refresh of content that's already on screen (the user keeps
    /// their context, just can't interact until it finishes).
    /// - Parameters:
    ///   - isLoading: whether to show the overlay.
    ///   - label: optional caption under the spinner.
    func loadingOverlay(_ isLoading: Bool, label: String? = nil) -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading, label: label))
    }
}

// MARK: - Previews

#Preview("Full-area") {
    LoadingStateView(label: "Loading your tasks…")
}

#Preview("Inline row") {
    List {
        Text("Existing item")
        InlineLoadingRow(label: "Loading more…")
    }
}

#Preview("Overlay") {
    VStack {
        Text("Some content underneath")
            .font(.title)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .loadingOverlay(true, label: "Refreshing…")
}
