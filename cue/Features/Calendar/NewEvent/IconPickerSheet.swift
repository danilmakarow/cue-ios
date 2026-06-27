//
//  IconPickerSheet.swift
//  cue
//

import SwiftUI

/// One SF Symbol option in the icon picker, grouped under a named category.
private struct IconOption: Identifiable, Hashable {
    /// The SF Symbol name persisted to `TaskDTO.icon`.
    let symbol: String
    var id: String { symbol }
}

/// A named cluster of related icons in the picker grid.
private struct IconCategory: Identifiable, Hashable {
    let name: String
    let icons: [IconOption]
    var id: String { name }
}

/// Modal grid of SF Symbols for choosing a per-task icon. Binds the selected
/// symbol name (`nil` == iconless). Categories + symbols mirror the design
/// spec's six clusters (Work / Health / Home / Travel / Social / Finance),
/// mapped from the spec's lucide set to their SF Symbol equivalents.
///
/// Searching filters every category by symbol name; a "Clear icon" affordance
/// lets the user return to iconless.
struct IconPickerSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @Binding var selection: String?

    @State private var query: String = ""

    private static let categories: [IconCategory] = [
        IconCategory(name: String(localized: "icon.category.work"), icons: [
            "briefcase", "laptopcomputer", "envelope", "phone", "clipboard", "building.2",
        ].map(IconOption.init)),
        IconCategory(name: String(localized: "icon.category.health"), icons: [
            "heart", "waveform.path.ecg", "pills", "dumbbell", "stethoscope", "leaf",
        ].map(IconOption.init)),
        IconCategory(name: String(localized: "icon.category.home"), icons: [
            "house", "bed.double", "fork.knife", "lightbulb", "wrench.and.screwdriver", "powerplug",
        ].map(IconOption.init)),
        IconCategory(name: String(localized: "icon.category.travel"), icons: [
            "airplane", "car", "mappin.and.ellipse", "suitcase", "safari", "ticket",
        ].map(IconOption.init)),
        IconCategory(name: String(localized: "icon.category.social"), icons: [
            "person.2", "cup.and.saucer", "gift", "music.note", "camera", "message",
        ].map(IconOption.init)),
        IconCategory(name: String(localized: "icon.category.finance"), icons: [
            "dollarsign.circle", "creditcard", "wallet.bifold", "chart.line.uptrend.xyaxis", "receipt", "banknote",
        ].map(IconOption.init)),
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 6)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                    if selection != nil {
                        clearRow
                    }
                    ForEach(filteredCategories) { category in
                        categorySection(category)
                    }
                    if filteredCategories.isEmpty {
                        Text("icon.search.empty")
                            .cueText(.callout)
                            .foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, Spacing.xxl)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .background(theme.surfaceElevated.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .searchable(text: $query, prompt: Text("icon.search.prompt"))
            .navigationTitle("icon.picker.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                        .tint(theme.accentText)
                }
            }
        }
    }

    // MARK: - Sections

    private var clearRow: some View {
        Button {
            selection = nil
            dismiss()
        } label: {
            Label("icon.clear", systemImage: "slash.circle")
                .cueText(.label)
                .foregroundStyle(theme.accentText)
        }
        .buttonStyle(.plain)
    }

    private func categorySection(_ category: IconCategory) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(category.name.uppercased())
                .cueText(.codeSmall)
                .foregroundStyle(theme.textSecondary)
            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(category.icons) { option in
                    iconTile(option)
                }
            }
        }
    }

    private func iconTile(_ option: IconOption) -> some View {
        let isSelected = option.symbol == selection
        return Button {
            selection = option.symbol
            dismiss()
        } label: {
            Image(systemName: option.symbol)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(isSelected ? theme.accentText : theme.textPrimary)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        .fill(isSelected ? theme.accentSoft : theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        .strokeBorder(isSelected ? theme.accentSoft : theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.symbol)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Filtering

    private var filteredCategories: [IconCategory] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return Self.categories }
        return Self.categories.compactMap { category in
            let matches = category.icons.filter { $0.symbol.lowercased().contains(trimmed) }
            return matches.isEmpty ? nil : IconCategory(name: category.name, icons: matches)
        }
    }
}

// MARK: - Icon trigger button

/// The round 44pt trigger button that opens the icon picker — shows the chosen
/// symbol (or a placeholder when iconless). Used in the Details section of both
/// the create and edit screens.
struct IconPickerButton: View {
    @Environment(\.theme) private var theme

    @Binding var selection: String?
    @State private var isPresenting = false

    var body: some View {
        Button {
            isPresenting = true
        } label: {
            Image(systemName: selection ?? "face.smiling")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(selection == nil ? theme.textSecondary : theme.accentText)
                .frame(width: 44, height: 44)
                .background(Circle().fill(theme.accentSoft))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "icon.picker.title"))
        .sheet(isPresented: $isPresenting) {
            IconPickerSheet(selection: $selection)
        }
    }
}

// MARK: - Preview

#Preview("IconPicker") {
    struct Demo: View {
        @State private var icon: String? = "briefcase"
        @Environment(\.theme) private var theme
        var body: some View {
            HStack {
                Text("Icon").cueText(.label).foregroundStyle(theme.textSecondary)
                Spacer()
                IconPickerButton(selection: $icon)
            }
            .padding(Spacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background)
        }
    }
    return Demo()
        .environment(\.theme, AppPalette.kraftInk.colors)
}
