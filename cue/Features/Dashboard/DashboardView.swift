//
//  DashboardView.swift
//  cue
//

import SwiftUI
import SwiftData

/// Dashboard tab — a completion report: "what you finished in the last N days".
///
/// Reads the already-synced `TaskItem` cache with `@Query` (the windowed
/// occurrences the calendar sync keeps fresh) for the *completions*, and pairs
/// them with `GET /tasks/daily-counts` (via `DailyCountsStore`) for the
/// *scheduled* total so the report can frame a completion rate. A `SegmentedControl`
/// switches the window between 7 / 30 / 90 days. Tiles use `CueCard`; the body
/// keeps the reporting voice — quiet, receipt-like, celebratory only in the count.
struct DashboardView: View {
    @Environment(\.theme) private var theme
    @Environment(NotificationStore.self) private var notifications

    /// All completed occurrences in the cache, newest completion first. The cache
    /// is window-bounded by the calendar sync, so the in-memory window filter
    /// below has a small set to scan.
    @Query(
        filter: #Predicate<TaskItem> { $0.completedAt != nil },
        sort: \TaskItem.completedAt,
        order: .reverse
    )
    private var completedTasks: [TaskItem]

    /// Default calendar (lowest `sortOrder`) — its id seeds the daily-counts
    /// denominator fetch.
    @Query(sort: \EventCalendar.sortOrder) private var calendars: [EventCalendar]

    @State private var counts = DailyCountsStore()
    @State private var range: ReportRange = .week

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                rangePicker

                let completions = completionsInWindow
                if completions.isEmpty {
                    emptyState
                } else {
                    summaryGrid(completions: completions)
                    recentList(completions: completions)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xxl)
            .animation(.snappy, value: range)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("dashboard.title")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            // Pull-to-refresh: re-fetch the scheduled-occurrence denominator for the
            // active window (the completed `@Query` reacts to SwiftData on its own).
            await refreshDenominator()
        }
        .task(id: range) {
            counts.bind(notifications: notifications)
            await refreshDenominator()
        }
    }

    // MARK: - Derived data

    /// The cutoff date for the active window (start of the day N days back).
    private var windowStart: Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -(range.days - 1), to: start) ?? start
    }

    /// Completed occurrences whose completion falls inside the active window.
    private var completionsInWindow: [TaskItem] {
        let cutoff = windowStart
        return completedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= cutoff
        }
    }

    /// The default calendar's id, or nil when no calendar has synced yet.
    private var calendarId: String? {
        calendars.first?.id
    }

    /// Re-fetches the scheduled-occurrence denominator for the active window.
    private func refreshDenominator() async {
        let calendar = Calendar.current
        let to = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        await counts.load(calendarId: calendarId, from: windowStart, to: to)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("dashboard.report.subtitle")
                .cueText(.label)
                .foregroundStyle(theme.textSecondary)
            Text(String(format: String(localized: "dashboard.report.title"), range.days))
                .cueText(.displayM)
                .foregroundStyle(theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rangePicker: some View {
        SegmentedControl(
            selection: $range,
            options: ReportRange.allCases,
            label: { $0.label }
        )
    }

    // MARK: - States

    private var emptyState: some View {
        EmptyStateView(
            title: String(localized: "dashboard.empty.title"),
            message: String(localized: "dashboard.empty.message"),
            systemImage: "checkmark.seal"
        )
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    // MARK: - Summary tiles

    @ViewBuilder
    private func summaryGrid(completions: [TaskItem]) -> some View {
        let stats = ReportStats(completions: completions, window: range, scheduled: counts.scheduledTotal)

        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)],
            spacing: Spacing.md
        ) {
            metricTile(
                value: "\(stats.completedCount)",
                title: String(localized: "dashboard.tile.completed"),
                caption: String(localized: "dashboard.tile.completedCaption"),
                tint: theme.success
            )
            metricTile(
                value: stats.busiestDayLabel,
                title: String(localized: "dashboard.tile.busiestDay"),
                caption: String(localized: "dashboard.tile.busiestDayCaption"),
                tint: theme.primary
            )
            metricTile(
                value: "\(stats.activeDays)",
                title: String(localized: "dashboard.tile.streak"),
                caption: String(localized: "dashboard.tile.streakCaption"),
                tint: theme.primary
            )
            if let rate = stats.completionRateLabel {
                metricTile(
                    value: rate,
                    title: String(localized: "dashboard.tile.rate"),
                    caption: String(localized: "dashboard.tile.rateCaption"),
                    tint: theme.success
                )
            }
        }
    }

    /// One report tile: a large mono value (the receipt voice), a body title, and
    /// a quiet caption — in a letterpress `CueCard`.
    private func metricTile(value: String, title: String, caption: String, tint: Color) -> some View {
        CueCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(value)
                    .font(Typography.font(for: .displayM))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(title)
                    .cueText(.bodyEmphasis)
                    .foregroundStyle(theme.textPrimary)
                Text(caption)
                    .cueText(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Recent completions

    @ViewBuilder
    private func recentList(completions: [TaskItem]) -> some View {
        let recent = Array(completions.prefix(8))
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(String(localized: "dashboard.recent.section").localizedUppercase)
                .cueText(.label)
                .foregroundStyle(theme.textSecondary)
                .padding(.leading, Spacing.xs)

            CueCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.occurrenceKey) { index, task in
                        completedRow(task, showsSeparator: index < recent.count - 1)
                    }
                }
            }
        }
    }

    /// A single completed-task row: an olive check, the title, and the completion
    /// timestamp in the receipt voice.
    private func completedRow(_ task: TaskItem, showsSeparator: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                OliveCheck(isDone: true)
                    .allowsHitTesting(false)

                Text(task.title)
                    .cueText(.body)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let completedAt = task.completedAt {
                    Text(completedAt.formatted(.dateTime.day().month(.abbreviated)))
                        .cueText(.code)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            if showsSeparator {
                Rectangle()
                    .fill(theme.separator)
                    .frame(height: 1)
                    .padding(.leading, Spacing.lg)
            }
        }
    }
}

// MARK: - Range

/// The dashboard's lookback window. Backs the `SegmentedControl`.
private enum ReportRange: CaseIterable, Hashable {
    case week
    case month
    case quarter

    /// The window length in days.
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }

    /// Segment label.
    var label: String {
        switch self {
        case .week: return String(localized: "dashboard.range.7")
        case .month: return String(localized: "dashboard.range.30")
        case .quarter: return String(localized: "dashboard.range.90")
        }
    }
}

// MARK: - Stats

/// Pure value-type roll-up of the window's completions, computed once per render.
/// Keeps the view body declarative — no arithmetic inline.
private struct ReportStats {
    let completedCount: Int
    let activeDays: Int
    let busiestDayLabel: String
    let completionRateLabel: String?

    /// - Parameters:
    ///   - completions: the in-window completed occurrences.
    ///   - window: the active range (unused arithmetic placeholder for future
    ///     per-day series; kept for call-site clarity).
    ///   - scheduled: total scheduled occurrences in the same window (the rate
    ///     denominator); a zero or sub-count value hides the rate tile.
    init(completions: [TaskItem], window: ReportRange, scheduled: Int) {
        let calendar = Calendar.current
        completedCount = completions.count

        // Bucket completions by their local day to find the active-day count and
        // the single busiest day.
        var perDay: [Date: Int] = [:]
        for task in completions {
            guard let completedAt = task.completedAt else { continue }
            let day = calendar.startOfDay(for: completedAt)
            perDay[day, default: 0] += 1
        }
        activeDays = perDay.count

        if let busiest = perDay.max(by: { $0.value < $1.value })?.key {
            busiestDayLabel = busiest.formatted(.dateTime.weekday(.abbreviated))
        } else {
            busiestDayLabel = String(localized: "dashboard.busiestDay.none")
        }

        // Rate only when the denominator is at least the completed count — a
        // sparse/failed denominator would otherwise read as a nonsensical >100%.
        if scheduled >= completedCount, scheduled > 0 {
            let fraction = Double(completedCount) / Double(scheduled)
            completionRateLabel = fraction.formatted(.percent.precision(.fractionLength(0)))
        } else {
            completionRateLabel = nil
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(NotificationStore())
    .environment(\.theme, AppPalette.kraftInk.colors)
    .modelContainer(for: [EventCalendar.self, TaskItem.self, EventTaskGroup.self], inMemory: true)
}
