//
//  QuickCreateWell.swift
//  cue
//

import SwiftUI

/// The natural-language quick-create well at the top of the create screen. The
/// user types one line ("Standup every weekday 9:30am 15m #Work"), taps Parse,
/// and `APIClient.parseTask(text:)` returns a structured ``TaskDraftDTO`` preview.
/// Confirming with **Use** hands the draft to the host to prefill the form;
/// **Dismiss** clears the preview.
///
/// Pure presentation + a single async call — the host owns the draft application
/// (it knows how to map the draft onto its own view-model fields).
struct QuickCreateWell: View {
    @Environment(\.theme) private var theme

    /// Invoked when the user accepts a parsed draft.
    let onUse: (TaskDraftDTO) -> Void

    @State private var text: String = ""
    @State private var draft: TaskDraftDTO?
    @State private var isParsing = false
    @State private var parseFailed = false

    private let api: APIClient = .shared

    var body: some View {
        CueCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                inputRow
                if let draft {
                    Divider().overlay(theme.separator)
                    previewRow(draft)
                } else if parseFailed {
                    Divider().overlay(theme.separator)
                    failureRow
                }
            }
        }
    }

    // MARK: - Input row

    private var inputRow: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(theme.textSecondary)
            TextField(text: $text) {
                Text("quickCreate.placeholder")
            }
            .textInputAutocapitalization(.sentences)
            .cueText(.callout)
            .foregroundStyle(theme.textPrimary)
            .submitLabel(.go)
            .onSubmit { parse() }

            if isParsing {
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.primary)
            } else {
                Button(String(localized: "quickCreate.parse")) { parse() }
                    .cueText(.label)
                    .foregroundStyle(theme.accentText)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Preview row

    private func previewRow(_ draft: TaskDraftDTO) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            FlowChips(chips: draftChips(draft))
            HStack(spacing: Spacing.md) {
                Spacer(minLength: 0)
                Button {
                    onUse(draft)
                    reset()
                } label: {
                    Label("quickCreate.use", systemImage: "checkmark")
                        .cueText(.label)
                        .foregroundStyle(theme.accentText)
                }
                .buttonStyle(.plain)
                Button {
                    withAnimation(.snappy) { self.draft = nil }
                } label: {
                    Label("quickCreate.dismiss", systemImage: "xmark")
                        .cueText(.label)
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var failureRow: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(theme.warning)
            Text("quickCreate.failed")
                .cueText(.caption)
                .foregroundStyle(theme.textSecondary)
            Spacer(minLength: 0)
            Button(String(localized: "common.retry")) { parse() }
                .cueText(.label)
                .foregroundStyle(theme.accentText)
        }
    }

    // MARK: - Draft → chips

    /// Builds the small summary chips that preview what the parse resolved.
    private func draftChips(_ draft: TaskDraftDTO) -> [PreviewChip] {
        var chips: [PreviewChip] = [PreviewChip(symbol: "textformat", text: draft.title)]
        if let start = draft.start, let date = Self.parseISO(start) {
            chips.append(PreviewChip(symbol: "calendar", text: date.formatted(.dateTime.day().month(.abbreviated).hour().minute())))
        }
        if let minutes = draft.durationMinutes {
            chips.append(PreviewChip(symbol: "timer", text: Self.durationLabel(minutes)))
        }
        if draft.recurrence != nil {
            chips.append(PreviewChip(symbol: "repeat", text: String(localized: "quickCreate.chip.repeats")))
        }
        return chips
    }

    // MARK: - Actions

    private func parse() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isParsing else { return }
        isParsing = true
        parseFailed = false
        Task {
            do {
                let result = try await api.parseTask(text: trimmed)
                withAnimation(.snappy) { draft = result }
            } catch {
                withAnimation(.snappy) { parseFailed = true }
            }
            isParsing = false
        }
    }

    private func reset() {
        text = ""
        draft = nil
        parseFailed = false
    }

    // MARK: - Helpers

    /// Leniently parses the draft's ISO-8601 start string (the DTO stores it as a
    /// display string to dodge the shared decoder's fractional-seconds strategy).
    static func parseISO(_ value: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    private static func durationLabel(_ minutes: Int) -> String {
        if minutes % 60 == 0 {
            return String(format: String(localized: "quickCreate.duration.hours"), minutes / 60)
        }
        return String(format: String(localized: "quickCreate.duration.minutes"), minutes)
    }
}

/// A single preview chip in the quick-create draft summary.
private struct PreviewChip: Identifiable, Hashable {
    let id = UUID()
    let symbol: String
    let text: String
}

/// Wrapping row of small summary chips.
private struct FlowChips: View {
    @Environment(\.theme) private var theme
    let chips: [PreviewChip]

    var body: some View {
        FlowLayout(spacing: Spacing.xs) {
            ForEach(chips) { chip in
                HStack(spacing: Spacing.xs) {
                    Image(systemName: chip.symbol)
                        .font(.system(size: 11, weight: .regular))
                    Text(chip.text)
                        .cueText(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: Radius.tight, style: .continuous)
                        .fill(theme.surfaceSunken)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tight, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1)
                )
            }
        }
    }
}

/// Minimal wrapping layout for the preview chips (avoids a horizontal scroll).
private struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var pointX = bounds.minX
        var pointY = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if pointX + size.width > bounds.maxX, pointX > bounds.minX {
                pointX = bounds.minX
                pointY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: pointX, y: pointY), proposal: ProposedViewSize(size))
            pointX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview("QuickCreateWell") {
    struct Demo: View {
        @Environment(\.theme) private var theme
        var body: some View {
            VStack {
                QuickCreateWell { _ in }
                Spacer()
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background)
        }
    }
    return Demo()
        .environment(\.theme, AppPalette.kraftInk.colors)
}
