//
//  WaxSeal.swift
//  cue
//
//  An irregular, hand-pressed clay seal — deliberately NOT a clean circle; the
//  jittered edge is what reads as human and not machine-stamped. Its role has
//  NARROWED to a brand / save mark. It is no longer the task-done marker (that is
//  now `OliveCheck` — an olive circle + white check) and the spring-stamp commit
//  motion has moved to `RootsCommitView` (organic roots growing under a check
//  mask). This view keeps the blob shape for brand and save surfaces.
//

import SwiftUI

/// The irregular seal outline. A smooth closed blob built from jittered points
/// (deterministic — no per-frame randomness), so it reads as hand-pressed wax.
struct WaxSealShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let count = 16
        // Deterministic per-vertex radius jitter (±~5%).
        let jitter: [CGFloat] = [0.03, -0.045, 0.02, -0.03, 0.05, -0.02, 0.035, -0.05,
                                 0.025, -0.035, 0.045, -0.025, 0.03, -0.04, 0.02, -0.03]
        let points: [CGPoint] = (0..<count).map { index in
            let angle = (CGFloat(index) / CGFloat(count)) * 2 * .pi
            let scaled = radius * (1 + jitter[index % jitter.count])
            return CGPoint(x: center.x + cos(angle) * scaled,
                           y: center.y + sin(angle) * scaled)
        }
        func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
            CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
        }
        var path = Path()
        path.move(to: midpoint(points[count - 1], points[0]))
        for index in 0..<count {
            let next = (index + 1) % count
            path.addQuadCurve(to: midpoint(points[index], points[next]), control: points[index])
        }
        path.closeSubpath()
        return path
    }
}

/// The wax-seal visual — a clay (`secondary`) blob with a white (`onAccent`)
/// glyph, used as a brand / save mark. When `isStamped`, the seal presses in with
/// a single spring; otherwise an empty dashed "seal-well" awaits. NOTE: the app's
/// task-done marker is now `OliveCheck`, and the commit/save celebration motion
/// lives in `RootsCommitView` — this is no longer the completion stamp.
struct WaxSeal: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let isStamped: Bool
    private let size: CGFloat
    private let systemImage: String

    init(isStamped: Bool, size: CGFloat = 56, systemImage: String = "checkmark") {
        self.isStamped = isStamped
        self.size = size
        self.systemImage = systemImage
    }

    var body: some View {
        ZStack {
            WaxSealShape()
                .stroke(theme.border, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .opacity(isStamped ? 0 : 0.9)

            ZStack {
                WaxSealShape()
                    .fill(theme.secondary)
                WaxSealShape()
                    .stroke(theme.primaryPressed.opacity(0.4), lineWidth: 1.5)
                    .blendMode(.multiply)
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(theme.onAccent)
            }
            // Under Reduce Motion the stamp fades in at rest size — no scale-up or
            // tilt — mirroring OliveCheck / RootsCommitView's opacity-only fallback.
            .scaleEffect(reduceMotion ? 1 : (isStamped ? 1 : 0.4))
            .opacity(isStamped ? 1 : 0)
            .rotationEffect(.degrees(reduceMotion ? 0 : (isStamped ? 0 : -8)))
        }
        .frame(width: size, height: size)
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.18)
                : .spring(response: 0.42, dampingFraction: 0.62),
            value: isStamped
        )
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview("WaxSeal") {
    HStack(spacing: Spacing.xxl) {
        WaxSeal(isStamped: false)
        WaxSeal(isStamped: true)
    }
    .padding(Spacing.xxl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(hex: 0xFFFFFF))
    .environment(\.theme, AppPalette.kraftInk.colors)
}
