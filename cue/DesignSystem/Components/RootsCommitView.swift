//
//  RootsCommitView.swift
//  cue
//
//  The commit signature — Kraft & Ink's "roots take hold" motion. An organic
//  tendril system GROWS from two seeds (top-left + bottom-right) under a checkmark
//  mask, so the centre check stays clear while a color field floods in behind the
//  roots. The end state is a solid, masked check.
//
//  This REPLACES the old wax-seal spring-stamp as the app's commit motion. It fires
//  on the two commit moments:
//    • a SAVE event  → GREEN/olive tone (`theme.success`)
//    • a TASK done   → CLAY tone        (`theme.primary`)
//
//  Motion (from the design system's §3 motion spec):
//    • GROW ~0.78s, expo-out — cubic-bezier(.22, 1, .36, 1)
//    • each tendril's stroke trims hidden → full, staggered by a per-path delay
//      (seedA @0, seedB @30ms, secondary branches @70–140ms)
//    • a color flood ramps in over the last ~45% so the end state is a SOLID field
//    • springy whole-view reveal: scale 0 → 1.045 → 1
//    • a `.success` haptic fires on trigger
//    • Reduce Motion → a same-duration cross-fade straight to the filled check
//
//  Replay by changing the bound `trigger` value; the view re-runs from frame 0.
//

import SwiftUI

// MARK: - Tone

/// Which commit moment this signature represents — selects the field color.
enum RootsCommitTone {
    /// Save event — olive/green roots (`theme.success`).
    case save
    /// Task completion — clay roots (`theme.primary`).
    case done

    /// Resolves the tendril + flood color for this tone against the active theme.
    func color(in theme: ThemeColors) -> Color {
        switch self {
        case .save: return theme.success
        case .done: return theme.primary
        }
    }
}

// MARK: - Tendril model

/// One root path on the canonical 220×220 frame: a cubic-Bézier spine plus the
/// stroke width and the stagger delay (in seconds) before it starts growing.
private struct Tendril {
    let start: CGPoint
    let control1: CGPoint
    let control2: CGPoint
    let end: CGPoint
    let width: CGFloat
    /// Fraction of the total run [0, 1) at which this tendril starts to grow.
    let delay: Double
}

// MARK: - RootsCommitView

/// The commit signature animation. Mount it where the confirmation should appear
/// (e.g. a 56–120pt square) and bump `trigger` to play it.
///
/// - The `tone` picks GREEN (save) vs CLAY (done).
/// - `trigger` is any `Equatable`; changing it remounts the run from frame 0. Pass
///   a counter you increment, or a fresh `UUID`, on each commit.
struct RootsCommitView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tone: RootsCommitTone
    private let trigger: AnyHashable

    /// Drives the whole run [0, 1]. Animated with the expo-out curve on appear and
    /// on every `trigger` change.
    @State private var progress: CGFloat = 0
    /// Monotonic play counter. Bumped on every `play()` (appear + each `trigger`
    /// change) so it can drive both the keyframe reveal and the haptic — neither
    /// of which can key off `trigger` alone, since that misses the initial mount.
    @State private var playCount: Int = 0

    /// Total grow duration, shared by the trim, flood and reveal.
    private let duration: Double = 0.78

    /// - Parameters:
    ///   - tone: save (olive) or done (clay).
    ///   - trigger: change this value to replay from frame 0.
    init(tone: RootsCommitTone, trigger: some Hashable) {
        self.tone = tone
        self.trigger = AnyHashable(trigger)
    }

    var body: some View {
        ZStack {
            if reduceMotion {
                reducedField
            } else {
                // Controlled springy reveal: a keyframe ramp that peaks at exactly
                // 1.045 then settles to 1.0 — no uncontrolled spring overshoot.
                // Keyed on `playCount` so it restarts from frame 0 on every play.
                rootsField
                    .keyframeAnimator(initialValue: revealStart, trigger: playCount) { content, scale in
                        content.scaleEffect(scale)
                    } keyframes: { _ in
                        revealKeyframes
                    }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
        // Fire the haptic on every play (appear + each trigger change), not only
        // on `trigger` changes — which would skip the initial mount.
        .sensoryFeedback(.success, trigger: playCount)
        .onAppear { play() }
        .onChange(of: trigger) { _, _ in play() }
    }

    /// The reveal scale's resting/start value. The keyframe run begins here and
    /// ends here (1.0); the overshoot to 1.045 happens in between.
    private var revealStart: CGFloat { reduceMotion ? 1 : 0 }

    /// Keyframe track for the springy reveal: grow 0 → 1.045 across the grow
    /// duration, then ease the 4.5% overshoot back down to a settled 1.0.
    @KeyframeTrackContentBuilder<CGFloat>
    private var revealKeyframes: some KeyframeTrackContent<CGFloat> {
        // Grow to the controlled peak over the ~0.78s grow timing (expo-out feel).
        CubicKeyframe(1.045, duration: duration)
        // Settle the overshoot back to rest.
        SpringKeyframe(1.0, duration: 0.22, spring: .snappy)
    }

    // MARK: Sub-views

    /// The animated tendril + flood field, clipped to the checkmark mask.
    private var rootsField: some View {
        let color = tone.color(in: theme)
        return GeometryReader { proxy in
            let scale = proxy.size.width / RootsGeometry.frame

            ZStack {
                // Flood — fills the gaps so the end state is a solid field. It scales
                // up from the centre as it ramps in over the last ~45% of the run.
                Rectangle()
                    .fill(color)
                    .opacity(floodOpacity)
                    .scaleEffect(0.45 + 0.55 * floodProgress)

                // Tendrils — each trims hidden → full, staggered by its delay.
                ForEach(Array(RootsGeometry.tendrils.enumerated()), id: \.offset) { _, tendril in
                    TendrilShape(tendril: tendril)
                        .trim(from: 0, to: tendrilTrim(for: tendril))
                        .stroke(
                            color,
                            style: StrokeStyle(
                                lineWidth: tendril.width * scale,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }
            }
            .mask {
                CheckMaskShape()
                    .scaleEffect(x: scale, y: scale, anchor: .topLeading)
            }
        }
    }

    /// Reduce-Motion fallback — a same-duration opacity cross-fade to the solid,
    /// masked, filled check (no growth, no overshoot).
    private var reducedField: some View {
        let color = tone.color(in: theme)
        return GeometryReader { proxy in
            let scale = proxy.size.width / RootsGeometry.frame
            Rectangle()
                .fill(color)
                .mask {
                    CheckMaskShape()
                        .scaleEffect(x: scale, y: scale, anchor: .topLeading)
                }
                .opacity(progress)
        }
    }

    // MARK: Animation math

    /// Per-tendril trim end. Each tendril grows over `growSpan` of the run, starting
    /// at its `delay`; before that it is hidden, after it is full.
    private func tendrilTrim(for tendril: Tendril) -> CGFloat {
        let growSpan: CGFloat = 0.56 // 0.44s of a 0.78s run
        let local = (progress - CGFloat(tendril.delay)) / growSpan
        return min(max(local, 0), 1)
    }

    /// Normalized flood ramp over the last ~45% of the run.
    private var floodProgress: CGFloat {
        let start: CGFloat = 0.55
        return min(max((progress - start) / (1 - start), 0), 1)
    }

    /// Flood opacity — eased toward solid so the field is fully covered at the end.
    private var floodOpacity: Double {
        Double(floodProgress)
    }

    // MARK: Driving the run

    /// Resets to frame 0 and animates the run with the expo-out curve. Bumping
    /// `playCount` restarts the keyframe reveal and fires the haptic; the trim +
    /// flood ride `progress`. Works on appear and on every `trigger` change.
    private func play() {
        playCount += 1

        guard !reduceMotion else {
            progress = 0
            withAnimation(.easeOut(duration: duration)) { progress = 1 }
            return
        }

        progress = 0
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: duration)) {
            progress = 1
        }
    }
}

// MARK: - Geometry

/// Canonical roots geometry on a 220×220 frame, ported from the design system's
/// motion spec (§3, the roots commit). Two seeds — top-left (16,16) and
/// bottom-right (204,204) — each fan thick primary roots, with thinner secondaries
/// forking off them. `delay` is the stagger as a fraction of the total run.
private enum RootsGeometry {
    static let frame: CGFloat = 220

    static let tendrils: [Tendril] = [
        // ---- seed A · top-left (thick → thin) ----
        Tendril(start: CGPoint(x: 16, y: 16), control1: CGPoint(x: 40, y: 50),
                control2: CGPoint(x: 56, y: 70), end: CGPoint(x: 72, y: 98),
                width: 9, delay: 0.0),
        Tendril(start: CGPoint(x: 16, y: 16), control1: CGPoint(x: 62, y: 22),
                control2: CGPoint(x: 110, y: 26), end: CGPoint(x: 152, y: 31),
                width: 8, delay: 0.0),
        Tendril(start: CGPoint(x: 16, y: 16), control1: CGPoint(x: 20, y: 56),
                control2: CGPoint(x: 26, y: 102), end: CGPoint(x: 30, y: 150),
                width: 8, delay: 0.0),
        Tendril(start: CGPoint(x: 60, y: 80), control1: CGPoint(x: 74, y: 72),
                control2: CGPoint(x: 94, y: 66), end: CGPoint(x: 116, y: 60),
                width: 5, delay: 0.09),
        Tendril(start: CGPoint(x: 66, y: 88), control1: CGPoint(x: 60, y: 112),
                control2: CGPoint(x: 56, y: 134), end: CGPoint(x: 50, y: 160),
                width: 4.5, delay: 0.15),
        Tendril(start: CGPoint(x: 122, y: 29), control1: CGPoint(x: 142, y: 50),
                control2: CGPoint(x: 152, y: 72), end: CGPoint(x: 160, y: 94),
                width: 5, delay: 0.12),
        Tendril(start: CGPoint(x: 28, y: 122), control1: CGPoint(x: 50, y: 132),
                control2: CGPoint(x: 74, y: 140), end: CGPoint(x: 94, y: 150),
                width: 4.5, delay: 0.17),
        // ---- seed B · bottom-right (thick → thin) ----
        Tendril(start: CGPoint(x: 204, y: 204), control1: CGPoint(x: 180, y: 170),
                control2: CGPoint(x: 164, y: 150), end: CGPoint(x: 148, y: 122),
                width: 9, delay: 0.04),
        Tendril(start: CGPoint(x: 204, y: 204), control1: CGPoint(x: 158, y: 198),
                control2: CGPoint(x: 110, y: 194), end: CGPoint(x: 68, y: 189),
                width: 8, delay: 0.04),
        Tendril(start: CGPoint(x: 204, y: 204), control1: CGPoint(x: 200, y: 164),
                control2: CGPoint(x: 194, y: 118), end: CGPoint(x: 190, y: 70),
                width: 8, delay: 0.04),
        Tendril(start: CGPoint(x: 160, y: 140), control1: CGPoint(x: 146, y: 148),
                control2: CGPoint(x: 126, y: 154), end: CGPoint(x: 104, y: 160),
                width: 5, delay: 0.13),
        Tendril(start: CGPoint(x: 154, y: 191), control1: CGPoint(x: 150, y: 168),
                control2: CGPoint(x: 154, y: 146), end: CGPoint(x: 160, y: 124),
                width: 4.5, delay: 0.18),
        Tendril(start: CGPoint(x: 192, y: 98), control1: CGPoint(x: 172, y: 90),
                control2: CGPoint(x: 150, y: 84), end: CGPoint(x: 128, y: 78),
                width: 5, delay: 0.16),
    ]
}

// MARK: - Shapes

/// A single tendril's cubic-Bézier spine, drawn on the canonical 220×220 frame and
/// scaled to the view via `GeometryReader`. Trimmable so its stroke can grow.
private struct TendrilShape: Shape {
    let tendril: Tendril

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / RootsGeometry.frame
        func point(_ source: CGPoint) -> CGPoint {
            CGPoint(x: source.x * scale, y: source.y * scale)
        }
        var path = Path()
        path.move(to: point(tendril.start))
        path.addCurve(
            to: point(tendril.end),
            control1: point(tendril.control1),
            control2: point(tendril.control2)
        )
        return path
    }
}

/// The checkmark used as the reveal mask — a thick, round-capped stroke punched
/// through the field so the centre check stays clear. Drawn on the 220×220 frame;
/// the caller scales it to match the field.
private struct CheckMaskShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Stroke width 21 on the 220 frame, round caps/joins.
        var spine = Path()
        spine.move(to: CGPoint(x: 62, y: 116))
        spine.addLine(to: CGPoint(x: 96, y: 150))
        spine.addLine(to: CGPoint(x: 160, y: 74))
        return spine.strokedPath(
            StrokeStyle(lineWidth: 21, lineCap: .round, lineJoin: .round)
        )
    }
}

// MARK: - Preview

#Preview("RootsCommitView") {
    struct Demo: View {
        @State private var saveTrigger = 0
        @State private var doneTrigger = 0

        var body: some View {
            VStack(spacing: 32) {
                HStack(spacing: 28) {
                    VStack(spacing: 12) {
                        RootsCommitView(tone: .save, trigger: saveTrigger)
                            .frame(width: 118, height: 118)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(.gray.opacity(0.2), lineWidth: 1)
                            )
                        Button("Replay save") { saveTrigger += 1 }
                    }
                    VStack(spacing: 12) {
                        RootsCommitView(tone: .done, trigger: doneTrigger)
                            .frame(width: 118, height: 118)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(.gray.opacity(0.2), lineWidth: 1)
                            )
                        Button("Replay done") { doneTrigger += 1 }
                    }
                }
                RootsCommitView(tone: .save, trigger: 0)
                    .frame(width: 44, height: 44)
            }
            .padding(40)
        }
    }
    return Demo()
        .environment(\.theme, AppPalette.kraftInk.colors)
}
