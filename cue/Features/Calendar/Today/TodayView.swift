//
//  TodayView.swift
//  cue
//

import SwiftData
import SwiftUI

/// The **Today** presentation — a calm, scrollable "what's my day" surface, the
/// SwiftUI render of `Today.dc.html`. It is a dedicated view (not a header bolted
/// onto the day timeline): a greeting header, a "next up" hero card, a today's-load
/// summary, the agenda grouped into "up next" / "this evening", and the AI morning
/// brief — each a CUE — Clean card on the white page.
///
/// **Data.** Today's occurrences are read from the already-synced `TaskItem` cache
/// with a *day-windowed* `@Query` (the same windowed cache the calendar scopes
/// serve from) — the predicate bounds the fetch to the reference day so SQLite
/// returns one day's rows via an indexed range read rather than the whole table.
/// Completion toggles route through the shared ``CalendarStore`` (so the
/// optimistic/SWR reconciliation is identical to the calendar). The Today tab also
/// drives its own day sync on appear so it populates independently of the Calendar
/// tab being visited. The morning brief loads once per day through
/// ``MorningBriefStore`` and degrades gracefully.
struct TodayView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationStore.self) private var notifications
    @Environment(CalendarStore.self) private var store

    let user: UserDTO

    /// The reference day's occurrence rows, fetched with a day-bounded predicate so
    /// the read is an indexed range scan of a single day (mirroring
    /// ``CalendarDataAdapter`` / ``CalendarStore/pruneOccurrences``). Occurrence-less
    /// rows are coalesced to `.distantPast`, landing below the range, so they're
    /// excluded. The order matches the post-filter sort below.
    @Query private var allOccurrences: [TaskItem]

    @State private var brief = MorningBriefStore()

    /// The reference day, captured once on appear so a long-lived screen doesn't
    /// silently roll past midnight mid-session.
    @State private var today: Date

    /// Captures the reference day once and seeds the day-windowed occurrence query
    /// from its `[startOfDay, startOfNextDay)` bounds.
    init(user: UserDTO) {
        self.user = user
        let dayStart = CalendarMath.startOfDay(.now)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let dayEnd = Calendar.current.startOfDay(for: nextDay)
        _today = State(initialValue: dayStart)
        let sentinel = Date.distantPast
        _allOccurrences = Query(
            filter: #Predicate { task in
                (task.occurrenceStart ?? sentinel) >= dayStart &&
                (task.occurrenceStart ?? sentinel) < dayEnd
            },
            sort: \TaskItem.occurrenceStart
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                header

                let occurrences = todaysOccurrences
                if let next = upNext(in: occurrences) {
                    nextUpHero(next)
                }

                loadCard(occurrences: occurrences)

                if occurrences.isEmpty {
                    clearDay
                } else {
                    agendaSection(
                        title: "today.section.upNext",
                        occurrences: morning(in: occurrences)
                    )
                    agendaSection(
                        title: "today.section.evening",
                        occurrences: evening(in: occurrences)
                    )
                }

                morningBriefCard
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xxl)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(Text("today.title"))
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            // Pull-to-refresh: re-sync today's occurrences and reload the brief.
            await store.invalidateAndResync(around: today, context: modelContext)
            await brief.load(for: today, force: true)
        }
        .task {
            store.bind(notifications: notifications)
            // Drive today's sync from the Today tab itself so it populates on a
            // cold launch (the default tab) without first visiting the Calendar tab.
            await store.ensureDaySynced(today, context: modelContext)
            await brief.load(for: today)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(today.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)).uppercased())
                    .cueText(.codeSmall)
                    .foregroundStyle(theme.textSecondary)
                Text(greeting)
                    .cueText(.displayM)
                    .foregroundStyle(theme.textPrimary)
            }
            Spacer(minLength: Spacing.md)
            CueAvatar(image: avatarImage, name: displayName, size: 48)
        }
    }

    /// "Good morning, Jane" — the localized part-of-day greeting plus the user's
    /// first name when known. The name is composed through a localized pattern so
    /// the separator/order can vary per locale.
    private var greeting: String {
        let part = Self.partOfDay()
        guard let name = firstName else { return part }
        return String(format: String(localized: "today.greeting.named"), part, name)
    }

    // MARK: - Next up hero

    @ViewBuilder
    private func nextUpHero(_ occurrence: OccurrenceVM) -> some View {
        CueCard(padding: 0, depth: .valueCut) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(railColor(for: occurrence))
                    .frame(width: 4)
                    .padding(.vertical, Spacing.lg)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(occurrence.startAt.formatted(date: .omitted, time: .shortened))
                        .cueText(.code)
                        .foregroundStyle(theme.textSecondary)
                    Text(occurrence.title)
                        .cueText(.titleM)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)
                    Text(relativeLine(for: occurrence))
                        .cueText(.callout)
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.vertical, Spacing.lg)
                .padding(.horizontal, Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)

                if occurrence.requiresCompletion {
                    TodayAgendaRowToggle(occurrence: occurrence) {
                        toggle(occurrence)
                    }
                    .padding(.trailing, Spacing.lg)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("today.hero.accessibility \(occurrence.title)")
        )
    }

    // MARK: - Today's load

    @ViewBuilder
    private func loadCard(occurrences: [OccurrenceVM]) -> some View {
        let total = occurrences.count
        let done = occurrences.filter(\.isCompleted).count
        let remaining = max(0, total - done)
        let fraction = total == 0 ? 0 : Double(done) / Double(total)

        CueCard(padding: 0) {
            Text("today.load.title")
                .cueText(.label)
                .foregroundStyle(theme.textSecondary)
        } content: {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("today.load.count \(total)")
                        .cueText(.code)
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text(loadWeight(total))
                        .cueText(.callout)
                        .foregroundStyle(theme.textSecondary)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.surfaceSunken)
                        Capsule()
                            .fill(theme.primary)
                            .frame(width: proxy.size.width * fraction)
                    }
                }
                .frame(height: 8)

                HStack(spacing: Spacing.xs) {
                    Text("today.load.done \(done)")
                        .foregroundStyle(theme.success)
                    Text("today.load.remaining \(remaining)")
                        .foregroundStyle(theme.textSecondary)
                }
                .cueText(.code)
            }
        }
    }

    // MARK: - Agenda sections

    @ViewBuilder
    private func agendaSection(title: LocalizedStringKey, occurrences: [OccurrenceVM]) -> some View {
        if !occurrences.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(title)
                    .cueText(.titleL)
                    .foregroundStyle(theme.textPrimary)
                CueCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(occurrences.enumerated()), id: \.element.id) { index, occurrence in
                            TodayAgendaRow(occurrence: occurrence) {
                                toggle(occurrence)
                            }
                            if index < occurrences.count - 1 {
                                Rectangle()
                                    .fill(theme.separator)
                                    .frame(height: 1)
                                    .padding(.leading, Spacing.sm)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Morning brief

    @ViewBuilder
    private var morningBriefCard: some View {
        CueCard(padding: 0, depth: .valueCut) {
            HStack {
                Text("today.brief.title")
                    .cueText(.label)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text(briefAuthor)
                    .cueText(.label)
                    .foregroundStyle(theme.accentText)
            }
        } content: {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                briefBody
            }
        }
    }

    @ViewBuilder
    private var briefBody: some View {
        switch brief.phase {
        case .idle, .loading:
            HStack(spacing: Spacing.sm) {
                ProgressView()
                Text("today.brief.loading")
                    .cueText(.callout)
                    .foregroundStyle(theme.textSecondary)
            }
        case .failed:
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("today.brief.failed")
                    .cueText(.body)
                    .foregroundStyle(theme.textSecondary)
                Button {
                    Task { await brief.load(for: today, force: true) }
                } label: {
                    Text("today.brief.retry")
                }
                .buttonStyle(.cue(.secondary))
            }
        case .loaded:
            briefText
                .font(Typography.font(for: .headline))
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The loaded brief body: the server-generated text rendered verbatim, or the
    /// calm localized placeholder when the day yielded nothing usable.
    @ViewBuilder
    private var briefText: some View {
        if let brief = brief.brief, !brief.isEmpty {
            Text(verbatim: brief)
        } else {
            Text("today.brief.empty")
        }
    }

    /// The brief byline — the active persona's display, defaulting to "Jarvis".
    private var briefAuthor: LocalizedStringKey { "today.brief.author" }

    // MARK: - Empty / clear day

    @ViewBuilder
    private var clearDay: some View {
        EmptyStateView(
            title: String(localized: "today.empty.title"),
            message: String(localized: "today.empty.message"),
            systemImage: "circle.dashed"
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    // MARK: - Occurrence derivation

    /// Today's occurrences (mapped to ``OccurrenceVM`` with their group color),
    /// ascending by start. The `@Query` already bounds rows to the reference day,
    /// so this only maps the rows into view models.
    private var todaysOccurrences: [OccurrenceVM] {
        allOccurrences
            .compactMap { row -> OccurrenceVM? in
                guard let base = row.asOccurrenceVM() else { return nil }
                return base.withGroupColorToken(row.groupColorToken)
            }
            .sorted { $0.startAt < $1.startAt }
    }

    /// The next still-open occurrence at or after now (the hero), or nil when the
    /// day has none left.
    private func upNext(in occurrences: [OccurrenceVM]) -> OccurrenceVM? {
        let now = Date.now
        return occurrences.first { !$0.isCompleted && $0.startAt >= now }
            ?? occurrences.first { !$0.isCompleted }
    }

    /// Occurrences before the evening boundary (18:00).
    private func morning(in occurrences: [OccurrenceVM]) -> [OccurrenceVM] {
        occurrences.filter { hour(of: $0.startAt) < Self.eveningHour }
    }

    /// Occurrences at/after the evening boundary (18:00).
    private func evening(in occurrences: [OccurrenceVM]) -> [OccurrenceVM] {
        occurrences.filter { hour(of: $0.startAt) >= Self.eveningHour }
    }

    private func hour(of date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    // MARK: - Actions

    /// Routes a completion tap through the shared store so the optimistic update +
    /// SWR reconciliation match the calendar's.
    private func toggle(_ occurrence: OccurrenceVM) {
        Task { await store.toggleCompletion(occurrenceKey: occurrence.id, context: modelContext) }
    }

    // MARK: - Formatting helpers

    /// A "in 18 min · 30 min" style line for the hero — relative start plus the
    /// occurrence's duration.
    private func relativeLine(for occurrence: OccurrenceVM) -> String {
        let relative = occurrence.startAt.formatted(.relative(presentation: .named))
        let minutes = Int(occurrence.endAt.timeIntervalSince(occurrence.startAt) / 60)
        guard minutes > 0 else { return relative }
        let duration = minutes < 60
            ? "\(minutes)m"
            : "\(minutes / 60)h\(minutes % 60 == 0 ? "" : String(format: "%02d", minutes % 60))"
        return "\(relative) · \(duration)"
    }

    /// A qualitative, localized load label keyed to the day's task count.
    private func loadWeight(_ total: Int) -> String {
        switch total {
        case 0: return String(localized: "today.load.weight.light")
        case 1...4: return String(localized: "today.load.weight.moderate")
        default: return String(localized: "today.load.weight.heavy")
        }
    }

    private func railColor(for occurrence: OccurrenceVM) -> Color {
        if occurrence.isCompleted { return theme.success }
        return TaskColorResolver.color(from: occurrence.groupColorToken) ?? theme.primary
    }

    // MARK: - User

    private var displayName: String? { user.displayName }

    private var firstName: String? {
        guard let displayName, !displayName.isEmpty else { return nil }
        return displayName.split(separator: " ").first.map(String.init)
    }

    private var avatarImage: UIImage? {
        guard let base64 = user.avatarBase64,
              let data = Data(base64Encoded: base64)
        else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Constants

    /// The hour that splits "up next" from "this evening".
    private static let eveningHour = 18

    /// Maps the current hour to a localized part-of-day greeting.
    private static func partOfDay() -> String {
        switch Calendar.current.component(.hour, from: .now) {
        case 0..<12: return String(localized: "today.greeting.morning")
        case 12..<17: return String(localized: "today.greeting.afternoon")
        default: return String(localized: "today.greeting.evening")
        }
    }
}

// MARK: - Preview

#Preview("Today") {
    let sampleUser = UserDTO(
        id: "usr_preview",
        appleUserId: "apple_001",
        email: "jane.appleseed@icloud.com",
        displayName: "Jane Appleseed",
        avatarBase64: nil,
        timezone: "Europe/Berlin",
        createdAt: .now,
        updatedAt: .now
    )
    return NavigationStack {
        TodayView(user: sampleUser)
    }
    .environment(\.theme, AppPalette.kraftInk.colors)
    .environment(CalendarStore(user: sampleUser))
    .environment(NotificationStore())
    .modelContainer(for: [EventCalendar.self, TaskItem.self, EventTaskGroup.self], inMemory: true)
}

/// A standalone done toggle used by the next-up hero (the agenda row embeds its own;
/// the hero needs the same control without the row chrome). Plays the CLAY commit
/// signature over the settling olive check on each tap.
private struct TodayAgendaRowToggle: View {
    let occurrence: OccurrenceVM
    let onToggle: () -> Void
    @State private var commitTrigger = 0

    var body: some View {
        Button {
            commitTrigger += 1
            onToggle()
        } label: {
            ZStack {
                OliveCheck(isDone: occurrence.isCompleted, size: 28)
                if occurrence.isCompleted {
                    RootsCommitView(tone: .done, trigger: commitTrigger)
                        .frame(width: 34, height: 34)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: 34, height: 34)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            occurrence.isCompleted ? "task.toggle.markNotDone" : "task.toggle.markDone"
        )
    }
}
