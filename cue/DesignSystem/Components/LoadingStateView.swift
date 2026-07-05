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
    @Environment(\.theme) private var theme

    /// Optional caption under the spinner, e.g. "Loading your tasks…".
    let label: String?

    /// - Parameter label: optional caption (default none).
    init(label: String? = nil) {
        self.label = label
    }

    var body: some View {
        VStack(spacing: 16) {
            RingSpinner(size: 34, lineWidth: 3)

            if let label {
                Text(label)
                    .cueText(.callout)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label ?? String(localized: "common.loading"))
    }
}

// MARK: - Ring spinner

/// A single rotating-ring spinner matching the States-kit loading specimen: a
/// faint warm-gray full track (`surfaceSunken`) with a clay (`primary`) arc on
/// top that spins continuously. Replaces the system multi-spoke
/// `ProgressView` so the loading mark reads as the design-kit's thin ring.
private struct RingSpinner: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Outer diameter of the ring in points.
    let size: CGFloat
    /// Stroke thickness of both the track and the arc.
    let lineWidth: CGFloat

    @State private var isRotating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.surfaceSunken, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    theme.primary,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(
                    reduceMotion
                        ? nil
                        : .linear(duration: 0.9).repeatForever(autoreverses: false),
                    value: isRotating
                )
        }
        .frame(width: size, height: size)
        .onAppear { isRotating = true }
        .accessibilityHidden(true)
    }
}

// MARK: - Inline loading row

/// Compact horizontal spinner + label, sized for a list footer or a section
/// header while additional content streams in (pagination, background sync).
struct InlineLoadingRow: View {
    @Environment(\.theme) private var theme

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
                .tint(theme.primary)
            Text(label)
                .cueText(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

// MARK: - Loading overlay

private struct LoadingOverlayModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let isLoading: Bool
    let label: String?

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    ZStack {
                        // Soft ink scrim (theme.textPrimary at 8%) rather than
                        // pure black — sits more naturally over the page, per the
                        // States kit "Loading · overlay" specimen.
                        theme.textPrimary.opacity(0.08)
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
