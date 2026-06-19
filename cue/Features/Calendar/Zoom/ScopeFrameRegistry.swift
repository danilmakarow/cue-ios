//
//  ScopeFrameRegistry.swift
//  cue
//

import Foundation
import Observation
internal import CoreGraphics

/// Tracks the on-screen frames of the calendar's zoomable cells — day cells in
/// the month scope and month cells in the year scope — in the zoom container's
/// named coordinate space.
///
/// `CalendarZoomContainer` consults it for two things:
/// - the **anchor frame** a zoom scales toward/from (the selected day's cell,
///   or a month's mini-grid cell), and
/// - **hit-testing** a pinch-open gesture's start location to pick the cell
///   being zoomed into.
///
/// All storage is `@ObservationIgnored`: frames churn on every scrolled frame
/// of the month/year lists, and nothing may observe them from a view `body` —
/// they are read imperatively at gesture time only. The class is `@Observable`
/// solely so it can ride the `.environment(_:)` / `@Environment` plumbing used
/// by every other shared calendar object.
@MainActor
@Observable
final class ScopeFrameRegistry {
    /// The named coordinate space (declared by `CalendarZoomContainer`) that
    /// all reported frames are measured in.
    static let coordinateSpaceName = "calendar-zoom"

    @ObservationIgnored private var dayFrames: [Date: CGRect] = [:]
    @ObservationIgnored private var monthFrames: [Date: CGRect] = [:]

    // MARK: - Day cells (month scope)

    func setDayFrame(_ frame: CGRect, for day: Date) {
        dayFrames[day] = frame
    }

    func clearDayFrame(for day: Date) {
        dayFrames.removeValue(forKey: day)
    }

    func dayFrame(for day: Date) -> CGRect? {
        dayFrames[day]
    }

    /// The day whose cell contains (or is nearest to) `point`.
    func day(at point: CGPoint) -> Date? {
        key(at: point, in: dayFrames)
    }

    // MARK: - Month cells (year scope)

    func setMonthFrame(_ frame: CGRect, for month: Date) {
        monthFrames[month] = frame
    }

    func clearMonthFrame(for month: Date) {
        monthFrames.removeValue(forKey: month)
    }

    func monthFrame(for month: Date) -> CGRect? {
        monthFrames[month]
    }

    /// The month whose cell contains (or is nearest to) `point`.
    func month(at point: CGPoint) -> Date? {
        key(at: point, in: monthFrames)
    }

    // MARK: - Hit testing

    private func key(at point: CGPoint, in frames: [Date: CGRect]) -> Date? {
        if let hit = frames.first(where: { $0.value.contains(point) }) {
            return hit.key
        }
        // No direct hit (gesture started on a gap) — nearest cell center wins.
        return frames.min { lhs, rhs in
            distanceSquared(from: point, to: lhs.value) < distanceSquared(from: point, to: rhs.value)
        }?.key
    }

    private func distanceSquared(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = point.x - rect.midX
        let dy = point.y - rect.midY
        return dx * dx + dy * dy
    }
}
