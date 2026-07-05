//
//  TaskBox.swift
//  cue
//
//  The reusable "Task Box" — the slightly floating white card that is the app's
//  identity motif on SwiftUI surfaces. The universal form is a floating shell
//  (white fill, 12pt continuous corner, soft float shadow) that renders ANY
//  caller-provided content, optionally whole-tile tappable. React analogy:
//  `<TaskBox>{children}</TaskBox>`.
//
//  The task-shaped forms the app is known for (`hero` / `compact`: a 4pt colored
//  left rail + time + title + trailing affordance) are convenience initializers
//  that render the task anatomy inside the same shell. See design-spec §1
//  "Task Box".
//

import SwiftUI

/// Which of the two task-shaped Task Box forms to render.
///
/// - `hero`: the tall "Next" box at the top of Today — a mono time, an 18pt title,
///   and a meta line (relative + duration), with an optional trailing slot.
/// - `compact`: the 60pt list row — a 72pt right-aligned mono time gutter, a
///   single-line ellipsised title, and an optional trailing slot.
enum TaskBoxStyle: Equatable {
    case hero
    case compact
}

/// The meta line shown under the title in the `hero` form: a sans relative
/// phrase (e.g. "in 18 min") plus an optional mono duration (e.g. "30 min"),
/// joined by " · ". `duration` is omitted when nil.
struct TaskBoxMeta: Equatable {
    let relative: String
    let duration: String?

    init(relative: String, duration: String? = nil) {
        self.relative = relative
        self.duration = duration
    }
}

/// The universal Task Box — a slightly floating surface card. In its base form
/// it takes and displays ANY content (`TaskBox { … }`): white `surface` fill, a
/// 12pt `Radius.card` continuous corner, `Spacing.lg` inner padding, and the
/// `.valueCut` floating depth (hairline border + layered soft shadow). Pass
/// `onTap` to make the whole tile a plain-styled button; when nil the box is
/// inert (the caller may wrap it in its own `Button`).
///
/// The task-shaped initializers (`style:time:title:…`) render the classic rail +
/// time + title anatomy inside the same shell; there `Content` is the trailing
/// affordance slot (WaxSeal / OliveCheck / recurring glyph / `EmptyView`), and
/// the rail color is the EFFECTIVE task color (`task ?? group ?? gray`) resolved
/// via ``TaskColorResolver/effectiveColor(taskToken:groupToken:)`` unless the
/// caller passes an explicit `railColor` (e.g. to flip to olive when done).
struct TaskBox<Content: View>: View {
    @Environment(\.theme) private var theme

    /// Which anatomy the box renders. `universal` shows `content` as the body;
    /// `task` shows the rail + time/title layout with `content` as the trailing
    /// slot.
    private enum BoxForm {
        case universal(padding: CGFloat, minHeight: CGFloat?, depth: Depth)
        case task(TaskDescriptor)
    }

    /// The fields of the task-shaped anatomy, bundled so the enum payload stays
    /// readable.
    private struct TaskDescriptor {
        let style: TaskBoxStyle
        let time: String
        let title: String
        let meta: TaskBoxMeta?
        let railColor: Color
        let isCompleted: Bool
    }

    private let form: BoxForm
    private let onTap: (() -> Void)?
    private let content: () -> Content

    /// The universal shell: a floating box around any content.
    /// - Parameters:
    ///   - padding: inner padding around the content (default `Spacing.lg`).
    ///   - minHeight: optional minimum tile height.
    ///   - depth: elevation treatment (default `.valueCut`, the floating shadow).
    ///   - onTap: whole-tile tap handler; nil renders an inert box.
    ///   - content: the box body — anything.
    init(
        padding: CGFloat = Spacing.lg,
        minHeight: CGFloat? = nil,
        depth: Depth = .valueCut,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.form = .universal(padding: padding, minHeight: minHeight, depth: depth)
        self.onTap = onTap
        self.content = content
    }

    /// The task-shaped Task Box with an explicit rail color.
    /// - Parameters:
    ///   - style: `hero` or `compact` layout.
    ///   - time: the leading time label (mono). Use "all-day" for all-day items.
    ///   - title: the task title (single-line ellipsised).
    ///   - meta: the hero meta line (relative + duration); ignored in `compact`.
    ///   - railColor: the left-rail fill (pass the resolved color directly; use
    ///     the token convenience init for the effective-color common case).
    ///   - isCompleted: fades the tile and strikes the title when true.
    ///   - onTap: whole-tile tap handler; when nil the box is inert.
    ///   - trailing: the trailing affordance (WaxSeal / OliveCheck / recurring
    ///     glyph / `EmptyView`).
    init(
        style: TaskBoxStyle,
        time: String,
        title: String,
        meta: TaskBoxMeta? = nil,
        railColor: Color,
        isCompleted: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Content = { EmptyView() }
    ) {
        self.form = .task(
            TaskDescriptor(
                style: style,
                time: time,
                title: title,
                meta: meta,
                railColor: railColor,
                isCompleted: isCompleted
            )
        )
        self.onTap = onTap
        self.content = trailing
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { card }
                    .buttonStyle(.plain)
            } else {
                card
            }
        }
    }

    // MARK: - Card

    @ViewBuilder
    private var card: some View {
        switch form {
        case let .universal(padding, minHeight, depth):
            shell(
                content()
                    .padding(padding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: minHeight),
                depth: depth,
                fadeOpacity: 1
            )
        case let .task(task):
            shell(
                HStack(spacing: 0) {
                    rail(task)
                    taskContent(task)
                }
                .frame(minHeight: task.style == .hero ? 100 : 60),
                depth: task.style == .hero ? .valueCut : .letterpress,
                fadeOpacity: task.isCompleted ? 0.62 : 1
            )
        }
    }

    /// The floating shell chrome shared by both forms: surface fill, continuous
    /// card corner, depth treatment, the completed fade, and the tap hit-shape.
    private func shell(_ box: some View, depth: Depth, fadeOpacity: Double) -> some View {
        box
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .cueDepth(depth, radius: Radius.card)
            .opacity(fadeOpacity)
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    // MARK: - Task anatomy

    /// The 4pt full-height-inset rail — a floating pill (radius 2) inset by the
    /// form's vertical padding so it clears the card corners: 16pt hero, 14pt
    /// compact.
    private func rail(_ task: TaskDescriptor) -> some View {
        RoundedRectangle(cornerRadius: Radius.tight, style: .continuous)
            .fill(task.railColor)
            .frame(width: 4)
            .frame(maxHeight: .infinity)
            .padding(.vertical, task.style == .hero ? Spacing.lg : 14)
    }

    @ViewBuilder
    private func taskContent(_ task: TaskDescriptor) -> some View {
        switch task.style {
        case .hero: heroContent(task)
        case .compact: compactContent(task)
        }
    }

    /// Hero: time / title / meta stacked, padding 16×14, with the trailing slot on
    /// the right at padding 0/16.
    private func heroContent(_ task: TaskDescriptor) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(task.time)
                    .cueText(.code)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .padding(.bottom, Spacing.sm)

                Text(task.title)
                    .cueText(.titleM)
                    .foregroundStyle(task.isCompleted ? theme.textSecondary : theme.textPrimary)
                    .strikethrough(task.isCompleted, color: theme.textSecondary)
                    .lineLimit(2)

                if let meta = task.meta {
                    metaLine(meta)
                        .padding(.top, Spacing.sm)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.lg)
            .padding(.leading, 14)

            trailingSlot
                .padding(.horizontal, Spacing.lg)
        }
    }

    /// Compact: a 72pt right-aligned mono time gutter, a single-line title, then
    /// the trailing slot.
    private func compactContent(_ task: TaskDescriptor) -> some View {
        HStack(spacing: 0) {
            Text(task.time)
                .cueText(.code)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
                .frame(width: 72, alignment: .trailing)
                .padding(.horizontal, Spacing.md)

            Text(task.title)
                .cueText(.body)
                .foregroundStyle(task.isCompleted ? theme.textSecondary : theme.textPrimary)
                .strikethrough(task.isCompleted, color: theme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Spacing.md)

            trailingSlot
                .padding(.leading, Spacing.sm)
                .padding(.trailing, Spacing.lg)
        }
    }

    /// The meta line: sans relative phrase + optional " · " mono duration.
    private func metaLine(_ meta: TaskBoxMeta) -> some View {
        HStack(spacing: 0) {
            Text(meta.relative)
                .cueText(.callout)
                .foregroundStyle(theme.textSecondary)
            if let duration = meta.duration {
                Text(verbatim: " · ")
                    .cueText(.callout)
                    .foregroundStyle(theme.textSecondary)
                Text(duration)
                    .cueText(.code)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .lineLimit(1)
    }

    /// Wraps the caller's trailing view; when it is `EmptyView` nothing renders
    /// (SwiftUI collapses it, so no phantom padding gap is introduced).
    private var trailingSlot: some View {
        content()
    }
}

// MARK: - Effective-color convenience

extension TaskBox {
    /// Builds a task-shaped Task Box whose rail is the EFFECTIVE task color
    /// resolved from the `(taskToken, groupToken)` pair (`task ?? group ?? gray`)
    /// — the common case. Pass the explicit-`railColor` initializer instead when
    /// the caller needs to override (e.g. flip to olive when done).
    init(
        style: TaskBoxStyle,
        time: String,
        title: String,
        meta: TaskBoxMeta? = nil,
        taskToken: String?,
        groupToken: String?,
        isCompleted: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Content = { EmptyView() }
    ) {
        self.init(
            style: style,
            time: time,
            title: title,
            meta: meta,
            railColor: TaskColorResolver.effectiveColor(taskToken: taskToken, groupToken: groupToken),
            isCompleted: isCompleted,
            onTap: onTap,
            trailing: trailing
        )
    }
}

// MARK: - Preview

#Preview("TaskBox") {
    ScrollView {
        VStack(spacing: Spacing.md) {
            TaskBox {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Universal shell")
                        .cueText(.titleM)
                    Text("The floating box takes any content — this card is a plain VStack.")
                        .cueText(.callout)
                }
            }

            // `trailing:` is labeled (not a bare trailing closure) in these
            // onTap-less calls: the forward scan would otherwise bind the closure
            // to the earlier `onTap` parameter and fall back to the deprecated
            // backward matching, warning on every build.
            TaskBox(
                style: .hero,
                time: "09:30",
                title: "Design review with the team",
                meta: .init(relative: "in 18 min", duration: "30 min"),
                taskToken: nil,
                groupToken: "BLUE",
                trailing: { WaxSeal(isStamped: false, size: 44) }
            )

            TaskBox(
                style: .compact,
                time: "11:00",
                title: "Dentist appointment on the far side of town",
                taskToken: nil,
                groupToken: "GREEN",
                trailing: { OliveCheck(isDone: false, size: 22) }
            )

            TaskBox(
                style: .compact,
                time: "all-day",
                title: "Pay invoices",
                taskToken: nil,
                groupToken: nil,
                isCompleted: true,
                trailing: { OliveCheck(isDone: true, size: 22) }
            )

            TaskBox(
                style: .compact,
                time: "14:00",
                title: "Weekly standup",
                taskToken: "PURPLE",
                groupToken: "BLUE",
                trailing: {
                    Image(systemName: "repeat")
                        .font(.system(size: 13, weight: .semibold))
                }
            )
        }
        .padding(Spacing.lg)
    }
    .background(Color(hex: 0xFFFFFF))
    .environment(\.theme, AppPalette.kraftInk.colors)
}
