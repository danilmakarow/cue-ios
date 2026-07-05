//
//  TodayView.swift
//  cue
//

import SwiftData
import SwiftUI

/// The **Today** presentation — a calm, scrollable "what's my day" surface, the
/// SwiftUI render of `Today.dc.html`. It is a dedicated view (not a header bolted
/// onto the day timeline): a greeting block (date eyebrow + "Good morning, Jane" +
/// avatar), the single **Up next** hero ``TaskBox`` (the next open occurrence,
/// whole-tile tappable to open its detail), and the AI **Today's brief** — each a
/// CUE — Clean card on the white page. There is no serif "Today" H1, no today's-load
/// meter, and no "This evening" list: the greeting leads and the one next thing to
/// do is the hero.
///
/// **Data.** The Up-next hero is read from the already-synced `TaskItem` cache with
/// a `@Query` whose predicate keeps the incomplete occurrences at or after the
/// reference day's start (`occurrenceStart >= startOfDay && completedAt == nil`),
/// ascending — deliberately *not* day-windowed, so the hero can surface the genuine
/// soonest task across days (today, tomorrow, next week…). SQLite walks the
/// `occurrenceStart` index for the ordered range read; `upNextOccurrence` then picks
/// the single winner (ongoing-first, else soonest upcoming) against a live `now`.
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
    @Environment(AppNavigation.self) private var navigation

    let user: UserDTO

    /// The pool the **Up next** hero draws from — the incomplete occurrences at or
    /// after the reference day's start, ascending, spanning FUTURE days (today,
    /// tomorrow, next week…). A day-windowed query (the shape the calendar scopes
    /// use) can only ever see the reference day, so it could never surface
    /// tomorrow's next thing; this unbounded-above query is what lets the hero show
    /// the genuine soonest task across days. `completedAt == nil` drops done
    /// occurrences at the SQLite layer; occurrence-less rows coalesce to
    /// `.distantPast` and fall below `dayStart`, so they're excluded. Bounded at
    /// `dayStart` (not `now`) so an occurrence that already started earlier today but
    /// hasn't ended yet — an "ongoing" item — is still in the pool for the pick to
    /// prefer. Not capped to one row in the query: the earliest future row alone
    /// can't express "prefer an ongoing occurrence", so the single-winner pick is
    /// done at read time in `upNextOccurrence`.
    @Query private var futureOccurrences: [TaskItem]

    @State private var brief = MorningBriefStore()

    /// The occurrence whose detail is being pushed. Set by the Up-next hero's tap;
    /// drives a value-based `navigationDestination` push onto the enclosing tab
    /// stack (the same ``TaskDetailScreen`` the calendar opens).
    @State private var selectedEvent: ScheduleEvent?

    /// The reference day, captured once on appear so a long-lived screen doesn't
    /// silently roll past midnight mid-session.
    @State private var today: Date

    /// Captures the reference day once and seeds the cross-day Up-next occurrence
    /// query from its start-of-day lower bound.
    init(user: UserDTO) {
        self.user = user
        let dayStart = CalendarMath.startOfDay(.now)
        _today = State(initialValue: dayStart)
        let sentinel = Date.distantPast
        // The Up-next pool: incomplete occurrences at/after the day start, ascending,
        // with NO upper bound so it reaches into tomorrow / next week. The
        // `?? .distantPast` sentinel excludes occurrence-less rows; `completedAt == nil`
        // filters out done occurrences in SQLite. The runtime pick (`upNextOccurrence`)
        // then chooses the soonest still-relevant one against a live `now`.
        _futureOccurrences = Query(
            filter: #Predicate { task in
                (task.occurrenceStart ?? sentinel) >= dayStart &&
                task.completedAt == nil
            },
            sort: \TaskItem.occurrenceStart
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                // The greeting leads the page (per the decided order): a date
                // eyebrow + "Good morning, Jane" + avatar. The old serif "Today" H1
                // and the large nav title are gone — the greeting is the header.
                header

                if let next = upNextOccurrence {
                    // The genuine SOONEST open occurrence across days (today,
                    // tomorrow, next week…), rendered as the hero Task Box: the most
                    // actionable thing coming up, whole-tile tappable to its detail.
                    // Its relative meta reads "in 18 min" / "tomorrow" / "in 3 d"
                    // naturally via `RelativeTimeFormatter`.
                    upNextSection(next)
                } else {
                    // Genuinely nothing upcoming at all — a calm clear-day block
                    // instead of the hero (no load meter to sit beneath it any more).
                    clearDay
                }

                todaysBriefCard
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xxl)
        }
        .background(theme.background.ignoresSafeArea())
        // The greeting block is the page header now, so the nav bar carries no
        // large serif "Today" title — the CUE — Clean Today screen leads with the
        // greeting, not an H1.
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedEvent) { event in
            TaskDetailScreen(event: event)
        }
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
                    // Design (Today.dc.html line 61): the greeting is system SANS
                    // 34pt/600, tracking -0.4 — it is now the page's lead line (the
                    // serif "Today" H1 was removed). There is no sans large-title
                    // token (`.displayL`/`.displayM` are both serif), so the role is
                    // applied directly here.
                    .font(.system(.largeTitle).weight(.semibold))
                    .tracking(-0.4)
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

    // MARK: - Up next

    /// The "Up next" section: a header row (title + right-aligned ghost "See all →")
    /// over the single next-open occurrence rendered as the hero ``TaskBox``. The
    /// whole tile is tappable to open the occurrence's detail; the trailing slot
    /// keeps the functional done toggle for tasks.
    @ViewBuilder
    private func upNextSection(_ occurrence: OccurrenceVM) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // `.center` (not `.firstTextBaseline`): the smaller "See all" ghost
            // button sits vertically centered against the taller `.titleL` heading
            // in the same row, flush right via the `Spacer`.
            HStack(alignment: .center) {
                // Section heading stays system-sans (.titleL): CUE — Clean reserves
                // the IBM Plex Serif voice for display/large titles, not section
                // headings.
                Text("today.section.upNext")
                    .cueText(.titleL)
                    .foregroundStyle(theme.textPrimary)
                Spacer(minLength: Spacing.md)
                Button {
                    seeAll()
                } label: {
                    Text("today.section.seeAll")
                }
                .buttonStyle(.cue(.ghost))
                // `CueButtonStyle` stretches every label to `maxWidth: .infinity`,
                // which parks the ghost's text mid-row; `.fixedSize()` collapses it
                // back to its label so the Spacer can pin it to the right edge
                // (same counter-measure as the onboarding Skip / Not-now ghosts).
                .fixedSize()
            }

            upNextHero(occurrence)
        }
    }

    /// The hero Task Box for the next occurrence: mono time, title, and a meta line
    /// of the human-friendly time-until (``RelativeTimeFormatter``) plus the
    /// duration. Tapping anywhere opens the occurrence's detail; the trailing slot
    /// carries the done toggle for tasks.
    @ViewBuilder
    private func upNextHero(_ occurrence: OccurrenceVM) -> some View {
        TaskBox(
            style: .hero,
            time: heroTime(for: occurrence),
            title: occurrence.title,
            meta: .init(
                relative: heroRelative(for: occurrence),
                duration: durationText(for: occurrence)
            ),
            railColor: railColor(for: occurrence),
            isCompleted: occurrence.isCompleted,
            onTap: { open(occurrence) }
        ) {
            if occurrence.requiresCompletion {
                TodayAgendaRowToggle(occurrence: occurrence) {
                    toggle(occurrence)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("today.hero.accessibility \(occurrence.title)")
        )
    }

    // MARK: - Today's brief

    @ViewBuilder
    private var todaysBriefCard: some View {
        // `Spacing.lg` (not 0) so the eyebrow/author header strip and the brief
        // body carry the standard 16pt horizontal card inset — the brief was
        // rendering edge-to-edge against the card border, out of line with the
        // other content. `CueCard`'s `padding` drives both the header's horizontal
        // inset and the content's all-side inset.
        CueCard(padding: Spacing.lg, depth: .valueCut) {
            HStack(spacing: Spacing.sm) {
                Text(String(localized: "today.brief.eyebrow", defaultValue: "Today's brief"))
                    .cueText(.label)
                    .foregroundStyle(theme.textSecondary)

                // A subtle regenerate control lives beside the eyebrow only once a
                // brief exists (`.loaded`): the day auto-loads, so `.loaded` already
                // means "planned". While `.loading` the well shows its own loader
                // (no regen); on `.failed` the body keeps its retry button.
                if brief.phase == .loaded {
                    Button {
                        regenerateBrief()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityLabel(
                        Text(String(localized: "today.brief.regenerate", defaultValue: "Regenerate brief"))
                    )
                }

                Spacer()

                // The byline pushes the Brief configuration editor onto the Today
                // tab's stack — it still reads as the "Jarvis" byline (accent label)
                // with a small chevron so it registers as tappable.
                NavigationLink {
                    BriefConfigView()
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        Text(briefAuthor)
                            .cueText(.label)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(theme.accentText)
                }
                .buttonStyle(.plain)
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
            // The brief auto-loads on appear, so once `.loaded` a brief already
            // exists ("planned"); the big decisive "Plan my day" CTA was removed.
            // Regeneration now lives as the subtle header control (see
            // `todaysBriefCard`). The body is just the rendered brief.
            briefText
                // System SANS body role (matching the rest of the app), not the
                // former editorial serif. Line spacing + primary color preserved.
                .cueText(.body)
                .lineSpacing(2)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The loaded brief body: the server-generated text rendered as Markdown, or
    /// the calm localized placeholder when the day yielded nothing usable.
    ///
    /// SwiftUI's single-string Markdown collapses hard newlines, so the brief is
    /// split into lines and each rendered as its own `Text` in a leading `VStack`
    /// — preserving the paragraph / line breaks the assistant emits. Each non-empty
    /// line is parsed with the `.full` interpreted syntax (lists, emphasis, links,
    /// etc.); a line that fails to parse (or yields an empty result) falls back to
    /// its verbatim string, so a plain-text brief from the old cache still renders.
    /// Blank lines render as a small spacer to keep paragraph separation.
    @ViewBuilder
    private var briefText: some View {
        if let brief = brief.brief, !brief.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(Array(brief.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                    if line.trimmingCharacters(in: .whitespaces).isEmpty {
                        // A blank source line separates paragraphs; render a thin
                        // spacer so the gap survives (an empty `Text` collapses).
                        Color.clear.frame(height: Spacing.xxs)
                    } else {
                        Text(Self.markdown(from: line))
                    }
                }
            }
        } else {
            Text("today.brief.empty")
        }
    }

    /// Parses one line of the brief as Markdown with inline-only interpreted
    /// syntax, tolerating partial parses. Falls back to the verbatim line when
    /// parsing throws or yields an empty result — so plain-text briefs (old cache)
    /// and any unparseable line still render intact.
    ///
    /// `.inlineOnlyPreservingWhitespace` (not `.full`): `.full` is block-aware and
    /// consumes list/heading markers (`- `, `1. `, `# `) into a `presentationIntent`
    /// that plain SwiftUI `Text` cannot render, so bullets/numbers/headings vanish.
    /// Inline-only keeps the emphasis/link parsing (**bold**, *italics*, links) while
    /// leaving those block markers as literal, visible characters.
    private static func markdown(from line: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let parsed = try? AttributedString(markdown: line, options: options),
              !parsed.characters.isEmpty
        else {
            return AttributedString(line)
        }
        return parsed
    }

    /// The brief byline — the active persona's display, defaulting to "Jarvis".
    private var briefAuthor: LocalizedStringKey { "today.brief.author" }

    // MARK: - Empty / clear day

    @ViewBuilder
    private var clearDay: some View {
        EmptyStateView(
            title: String(localized: "today.empty.title"),
            message: String(localized: "today.empty.message"),
            systemImage: "circle.dashed",
            actionTitle: emptyActionTitle,
            action: { navigation.isPresentingNewEvent = true }
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    /// The clear-day CTA label. Resolved through `String(localized:defaultValue:)`
    /// so the string carries an inline default (the catalog auto-extracts the key
    /// at build time) and never renders as a bare key, then handed to the
    /// `LocalizedStringKey`-typed `actionTitle` as verbatim text.
    private var emptyActionTitle: LocalizedStringKey {
        LocalizedStringKey(
            String(localized: "today.empty.action", defaultValue: "Add to today")
        )
    }

    // MARK: - Occurrence derivation

    /// The Up-next candidate pool (mapped to ``OccurrenceVM`` with their effective
    /// task/group color), ascending by start. Drawn from `futureOccurrences`, which
    /// spans FUTURE days — so the hero can reach into tomorrow / next week, not just
    /// today. The `@Query` already filters completed + occurrence-less rows and
    /// sorts ascending; this only folds the color tokens onto each view model. The
    /// defensive re-sort guards against any adapter reordering during the optimistic
    /// SWR window.
    private var futureOccurrenceVMs: [OccurrenceVM] {
        futureOccurrences
            .compactMap { row -> OccurrenceVM? in
                guard let base = row.asOccurrenceVM() else { return nil }
                return base.withColorTokens(taskToken: row.colorToken, groupToken: row.groupColorToken)
            }
            .sorted { $0.startAt < $1.startAt }
    }

    /// The single **Up next** hero: the soonest still-relevant incomplete occurrence
    /// across days, or nil only when nothing is upcoming at all. Selection, against a
    /// live `now`:
    /// 1. **Ongoing wins** — an occurrence already underway (`startAt <= now < endAt`)
    ///    is what the user is in the middle of, so it's surfaced ahead of anything
    ///    still to come. This also naturally catches an **all-day** item earlier
    ///    today (its midnight `startAt` is in the past but its `endAt` is later),
    ///    keeping today's all-day item as the hero rather than skipping to tomorrow.
    ///    Ties break on the soonest `endAt` (the one about to free up).
    /// 2. **Soonest upcoming** — otherwise the earliest occurrence whose `startAt`
    ///    is still in the future, by `startAt`.
    ///
    /// `completedAt == nil` is already enforced by the query; the `!isCompleted`
    /// guard is a belt-and-braces re-check for the optimistic window before the
    /// query re-runs.
    private var upNextOccurrence: OccurrenceVM? {
        let now = Date.now
        let candidates = futureOccurrenceVMs.filter { !$0.isCompleted }

        let ongoing = candidates
            .filter { $0.startAt <= now && $0.endAt > now }
            .min { $0.endAt < $1.endAt }
        if let ongoing { return ongoing }

        return candidates
            .filter { $0.startAt > now }
            .min { $0.startAt < $1.startAt }
    }

    // MARK: - Actions

    /// Routes a completion tap through the shared store so the optimistic update +
    /// SWR reconciliation match the calendar's.
    private func toggle(_ occurrence: OccurrenceVM) {
        Task { await store.toggleCompletion(occurrenceKey: occurrence.id, context: modelContext) }
    }

    /// Opens the occurrence's detail — pushes the same ``TaskDetailScreen`` the
    /// calendar opens by projecting to a ``ScheduleEvent`` and driving the
    /// value-based `navigationDestination`.
    private func open(_ occurrence: OccurrenceVM) {
        selectedEvent = occurrence.asScheduleEvent
    }

    /// "See all →" on the Up next header — jumps to the Calendar tab in its flat
    /// list (TODO) presentation, the full day's agenda the Today hero summarizes.
    private func seeAll() {
        store.viewMode = .list
        navigation.selectedTab = .calendar
    }

    /// Regenerates the brief for the reference day — the subtle header control.
    /// Forces a fresh fetch through ``MorningBriefStore`` with `force: true`, which
    /// passes `refresh: true` to the daily-brief GET so the server BUSTS its per-day
    /// cache and generates anew (rather than replaying the cached copy).
    private func regenerateBrief() {
        Task { await brief.load(for: today, force: true) }
    }

    // MARK: - Formatting helpers

    /// The hero's leading time label — the start time (mono), or the "all-day"
    /// label when the occurrence spans the whole day.
    private func heroTime(for occurrence: OccurrenceVM) -> String {
        if occurrence.isAllDay {
            return String(localized: "newEvent.allDay")
        }
        return occurrence.startAt.formatted(date: .omitted, time: .shortened)
    }

    /// The hero meta's relative phrase, guarded so it never reads a nonsensical
    /// past countdown:
    /// - **all-day** items have no meaningful start-of-day countdown, so they read
    ///   the "all day" label instead of "N min ago";
    /// - an item that has **already started** (its start is at/before now, within a
    ///   one-minute grace) reads "now" rather than a negative/past value;
    /// - otherwise the future countdown ("in 18 min") via ``RelativeTimeFormatter``.
    private func heroRelative(for occurrence: OccurrenceVM) -> String {
        if occurrence.isAllDay {
            return String(localized: "today.hero.allDay", defaultValue: "All day")
        }
        // A one-minute grace so an item that just began still reads "now" instead of
        // flipping to a past phrasing the instant it starts.
        let grace: TimeInterval = 60
        if occurrence.startAt.timeIntervalSinceNow < -grace {
            return String(localized: "relativeTime.now", defaultValue: "now")
        }
        return RelativeTimeFormatter.timeUntil(occurrence.startAt)
    }

    /// The occurrence's duration in the design's "30 min" / "1 h 30 min" form
    /// (spelled-out unit, never "30m"), or nil for a zero-length occurrence.
    private func durationText(for occurrence: OccurrenceVM) -> String? {
        let minutes = Int(occurrence.endAt.timeIntervalSince(occurrence.startAt) / 60)
        guard minutes > 0 else { return nil }
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) h" : "\(hours) h \(remainder) min"
    }

    /// The hero rail color: the EFFECTIVE task color (`task ?? group ?? gray`) per
    /// the color decision, flipping to olive once the occurrence is done.
    private func railColor(for occurrence: OccurrenceVM) -> Color {
        if occurrence.isCompleted { return theme.success }
        return TaskColorResolver.effectiveColor(
            taskToken: occurrence.colorToken,
            groupToken: occurrence.groupColorToken
        )
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
        .accessibilityIdentifier("task.toggle")
        .accessibilityLabel(
            occurrence.isCompleted ? "task.toggle.markNotDone" : "task.toggle.markDone"
        )
    }
}
