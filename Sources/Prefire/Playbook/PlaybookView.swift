import Foundation
import SwiftUI

#if os(iOS)
import UIKit

extension CGFloat {
    static let scale: CGFloat = 0.55
    static let infoViewHeight: CGFloat = 48
    @MainActor static let screenHeight = UIScreen.main.bounds.height
    @MainActor static let screenWidth = UIScreen.main.bounds.width
}

@available(tvOS, unavailable)
public struct PlaybookView: View {
    enum DisplayMode: String, CaseIterable, Identifiable {
        case components
        case flows

        var id: String { rawValue }

        var title: String {
            switch self {
            case .components:
                return "Components"
            case .flows:
                return "Stories"
            }
        }

        var prompt: String {
            switch self {
            case .components:
                return "Search components, states, stories"
            case .flows:
                return "Search user stories or screens"
            }
        }

        var symbol: String {
            switch self {
            case .components:
                return "🧩"
            case .flows:
                return "📙"
            }
        }
    }

    enum LayoutFilter: String, CaseIterable, Identifiable {
        case all
        case screens
        case components

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "All layouts"
            case .screens:
                return "Screens"
            case .components:
                return "Components"
            }
        }

        var icon: String {
            switch self {
            case .all:
                return "rectangle.3.offgrid"
            case .screens:
                return "iphone"
            case .components:
                return "square.grid.2x2"
            }
        }

        func matches(_ type: PreviewModel.LayoutType) -> Bool {
            switch self {
            case .all:
                return true
            case .screens:
                return type == .screen
            case .components:
                return type == .component
            }
        }
    }

    struct Filters {
        var searchText: String = ""
        var story: PreviewModel.UserStory?
        var state: PreviewModel.State?
        var deviceIdentifier: String?
        var layout: LayoutFilter = .all

        var hasActiveFilters: Bool {
            story != nil || state != nil || deviceIdentifier != nil || layout != .all || isSearchApplied
        }

        var hasFilterBadges: Bool {
            story != nil || state != nil || deviceIdentifier != nil || layout != .all
        }

        var isSearchApplied: Bool {
            !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    struct Section: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let indices: [Int]
    }

    @State private var navigationLinkTriggered = false
    @State private var selectedId: String = ""
    @State private var viewModels: [PreviewModel]
    @State private var displayMode: DisplayMode
    @State private var filters = Filters()

    private let initialMode: DisplayMode

    public init(isComponent: Bool, previewModels: [PreviewModel]) {
        let mode: DisplayMode = isComponent ? .components : .flows
        self.initialMode = mode
        _displayMode = State(initialValue: mode)
        _viewModels = State(initialValue: previewModels)
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavigationLink(isActive: isPresentingDetail, destination: { selectedView }) {
                EmptyView()
            }
            .hidden()

            FilterBar(
                displayMode: $displayMode,
                filters: $filters,
                availableStories: availableStories,
                availableStates: availableStates,
                availableDevices: availableDevices,
                showInlineSearchField: showInlineSearchField,
                showReset: filters.hasActiveFilters || displayMode != initialMode,
                resetAction: resetFilters
            )

            if filteredSections.isEmpty {
                EmptyStateView(searchText: filters.searchText, hasFilters: filters.hasActiveFilters)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 64)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 32) {
                        ForEach(filteredSections) { section in
                            SectionView(
                                section: section,
                                displayMode: displayMode,
                                viewModels: $viewModels,
                                selectedId: $selectedId,
                                navigationLinkTriggered: $navigationLinkTriggered
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Prefire Playbook")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if filters.hasActiveFilters || displayMode != initialMode {
                    Button(action: resetFilters) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
        .transformIf(true) { view -> AnyView in
            if #available(iOS 15.0, *) {
                return AnyView(
                    view.searchable(
                        text: Binding(
                            get: { filters.searchText },
                            set: { filters.searchText = $0 }
                        ),
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: displayMode.prompt
                    )
                )
            } else {
                return AnyView(view)
            }
        }
    }

    private var isPresentingDetail: Binding<Bool> {
        Binding(
            get: { navigationLinkTriggered && !selectedId.isEmpty },
            set: { newValue in
                navigationLinkTriggered = newValue
                if !newValue {
                    selectedId = ""
                }
            }
        )
    }

    private var showInlineSearchField: Bool {
        if #available(iOS 15.0, *) {
            return false
        } else {
            return true
        }
    }

    private var availableStories: [PreviewModel.UserStory] {
        viewModels.compactMap { $0.story }.uniqued().sortedCaseInsensitive()
    }

    private var availableStates: [PreviewModel.State] {
        viewModels.compactMap { $0.state }.uniqued().sortedCaseInsensitive()
    }

    private var availableDevices: [String] {
        viewModels.compactMap { $0.device?.rawValue }.uniqued().sortedCaseInsensitive()
    }

    private var filteredSections: [Section] {
        struct Accumulator {
            var title: String
            var subtitle: String?
            var indices: [Int]
        }

        var groups: [String: Accumulator] = [:]
        var orderedKeys: [String] = []

        for (index, model) in viewModels.enumerated() where matchesFilters(model) {
            let key = groupKey(for: model)
            if groups[key] == nil {
                orderedKeys.append(key)
                groups[key] = Accumulator(
                    title: sectionTitle(for: model, key: key),
                    subtitle: sectionSubtitle(for: model),
                    indices: [index]
                )
            } else {
                groups[key]?.indices.append(index)
            }
        }

        return orderedKeys.compactMap { key in
            guard let accumulator = groups[key] else { return nil }
            return Section(id: key, title: accumulator.title, subtitle: accumulator.subtitle, indices: accumulator.indices)
        }
    }

    private func matchesFilters(_ model: PreviewModel) -> Bool {
        if !filters.layout.matches(model.type) { return false }
        if let story = filters.story, model.story != story { return false }
        if let state = filters.state, model.state != state { return false }
        if let device = filters.deviceIdentifier, model.device?.rawValue != device { return false }

        guard !filters.isSearchApplied else {
            let query = filters.searchText.lowercased()
            let haystack = [
                model.name.lowercased(),
                model.story?.lowercased(),
                model.state?.lowercased(),
                model.device?.rawValue.lowercased()
            ].compactMap { $0 }

            return haystack.contains(where: { $0.contains(query) })
        }

        return true
    }

    private func groupKey(for model: PreviewModel) -> String {
        switch displayMode {
        case .components:
            return model.name
        case .flows:
            return model.story ?? "Ungrouped"
        }
    }

    private func sectionTitle(for model: PreviewModel, key: String) -> String {
        switch displayMode {
        case .components:
            return "\(displayMode.symbol) \(model.name)"
        case .flows:
            let base = key.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(displayMode.symbol) \((base.isEmpty ? "General" : base).capitalized)"
        }
    }

    private func sectionSubtitle(for model: PreviewModel) -> String? {
        switch displayMode {
        case .components:
            if let story = model.story, !story.isEmpty {
                return story.capitalized
            }
            return model.type.displayLabel
        case .flows:
            return model.name
        }
    }

    private func resetFilters() {
        displayMode = initialMode
        filters = Filters()
    }

    @ViewBuilder
    private var selectedView: some View {
        if let index = viewModels.firstIndex(where: { $0.id == selectedId }) {
            PlaybookDetailView(viewModel: $viewModels[index])
        } else {
            EmptyView()
        }
    }
}

private struct FilterBar: View {
    @Binding var displayMode: PlaybookView.DisplayMode
    @Binding var filters: PlaybookView.Filters

    let availableStories: [PreviewModel.UserStory]
    let availableStates: [PreviewModel.State]
    let availableDevices: [String]
    let showInlineSearchField: Bool
    let showReset: Bool
    let resetAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Picker("Mode", selection: $displayMode) {
                    ForEach(PlaybookView.DisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())

                if showReset {
                    Button(action: resetAction) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }

            if showInlineSearchField {
                TextField(displayMode.prompt, text: $filters.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    layoutMenu
                    if !availableStories.isEmpty {
                        storyMenu
                    }
                    if !availableStates.isEmpty {
                        stateMenu
                    }
                    if !availableDevices.isEmpty {
                        deviceMenu
                    }
                }
                .padding(.vertical, 4)
            }

            if filters.hasFilterBadges || filters.isSearchApplied {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let story = filters.story {
                            FilterChip(title: "Story: \(story)", icon: "book.fill") {
                                filters.story = nil
                            }
                        }
                        if let state = filters.state {
                            FilterChip(title: "State: \(state)", icon: "square.stack.3d.down.right.fill") {
                                filters.state = nil
                            }
                        }
                        if let device = filters.deviceIdentifier {
                            FilterChip(title: device, icon: "iphone") {
                                filters.deviceIdentifier = nil
                            }
                        }
                        if filters.layout != .all {
                            FilterChip(title: filters.layout.title, icon: filters.layout.icon) {
                                filters.layout = .all
                            }
                        }
                        if filters.isSearchApplied {
                            FilterChip(title: filters.searchText, icon: "magnifyingglass") {
                                filters.searchText = ""
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var layoutMenu: some View {
        Menu {
            ForEach(PlaybookView.LayoutFilter.allCases) { option in
                Button {
                    filters.layout = option
                } label: {
                    menuRow(title: option.title, icon: option.icon, isSelected: filters.layout == option)
                }
            }
        } label: {
            menuLabel(title: "Layout", value: filters.layout == .all ? "Any" : filters.layout.title, icon: "slider.horizontal.3")
        }
    }

    private var storyMenu: some View {
        Menu {
            Button {
                filters.story = nil
            } label: {
                menuRow(title: "All stories", icon: "book", isSelected: filters.story == nil)
            }

            ForEach(availableStories, id: \.self) { story in
                Button {
                    filters.story = story
                } label: {
                    menuRow(title: story, icon: "book", isSelected: filters.story == story)
                }
            }
        } label: {
            menuLabel(title: "Story", value: filters.story ?? "Any", icon: "book")
        }
    }

    private var stateMenu: some View {
        Menu {
            Button {
                filters.state = nil
            } label: {
                menuRow(title: "All states", icon: "square.stack.3d.down.right", isSelected: filters.state == nil)
            }

            ForEach(availableStates, id: \.self) { state in
                Button {
                    filters.state = state
                } label: {
                    menuRow(title: state, icon: "square.stack.3d.down.right", isSelected: filters.state == state)
                }
            }
        } label: {
            menuLabel(title: "State", value: filters.state ?? "Any", icon: "square.stack.3d.down.right")
        }
    }

    private var deviceMenu: some View {
        Menu {
            Button {
                filters.deviceIdentifier = nil
            } label: {
                menuRow(title: "All devices", icon: "iphone", isSelected: filters.deviceIdentifier == nil)
            }

            ForEach(availableDevices, id: \.self) { device in
                Button {
                    filters.deviceIdentifier = device
                } label: {
                    menuRow(title: device, icon: "iphone", isSelected: filters.deviceIdentifier == device)
                }
            }
        } label: {
            menuLabel(title: "Device", value: filters.deviceIdentifier ?? "Any", icon: "iphone")
        }
    }

    @ViewBuilder
    private func menuRow(title: String, icon: String, isSelected: Bool) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }

    private func menuLabel(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
            VStack(alignment: .leading, spacing: 0) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.primary)
            }
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

private struct FilterChip: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
                Image(systemName: "xmark.circle.fill")
                    .font(.caption.weight(.semibold))
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.15))
            .foregroundColor(Color.accentColor)
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct SectionView: View {
    let section: PlaybookView.Section
    let displayMode: PlaybookView.DisplayMode

    @Binding var viewModels: [PreviewModel]
    @Binding var selectedId: String
    @Binding var navigationLinkTriggered: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.title2.weight(.semibold))
                if let subtitle = section.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(section.indices, id: \.self) { index in
                    PlaybookCard(
                        displayMode: displayMode,
                        selectedId: $selectedId,
                        navigationLinkTriggered: $navigationLinkTriggered,
                        viewModel: $viewModels[index]
                    )
                }
            }
        }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 20, alignment: .top)]
    }
}

private struct PlaybookCard: View, Identifiable {
    let id: String
    let displayMode: PlaybookView.DisplayMode

    @Binding var selectedId: String
    @Binding var navigationLinkTriggered: Bool
    @Binding var viewModel: PreviewModel

    @Environment(\.colorScheme) private var colorScheme

    init(
        displayMode: PlaybookView.DisplayMode,
        selectedId: Binding<String>,
        navigationLinkTriggered: Binding<Bool>,
        viewModel: Binding<PreviewModel>
    ) {
        self.id = viewModel.wrappedValue.id
        self.displayMode = displayMode
        _selectedId = selectedId
        _navigationLinkTriggered = navigationLinkTriggered
        _viewModel = viewModel
    }

    var body: some View {
        Button(action: openDetail) {
            VStack(spacing: 0) {
                if #available(iOS 15.0, *) {
                    miniViewSection
                }

                Divider()

                InfoView(
                    renderTime: $viewModel.renderTime,
                    state: $viewModel.state,
                    story: viewModel.story,
                    device: viewModel.device,
                    layoutType: viewModel.type
                )
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(selectedId == viewModel.id ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 2)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12),
                radius: 16,
                x: 0,
                y: 12
            )
        }
        .buttonStyle(ScaleEffectButtonStyle())
    }

    private func openDetail() {
        selectedId = viewModel.id
        navigationLinkTriggered = true
    }

    @available(iOS 15.0, *)
    private var miniViewSection: some View {
        MiniView(
            id: viewModel.id,
            isScreen: viewModel.type == .screen,
            view: viewModel.content()
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .modifier(LoadingTimeModifier { loadingTime in
            guard viewModel.renderTime == nil else { return }
            viewModel.renderTime = loadingTime
        })
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 6) {
                if let state = viewModel.state {
                    CapsuleLabel(text: state.capitalized, icon: "square.stack.3d.down.right")
                }
                if let story = viewModel.story, displayMode == .components {
                    CapsuleLabel(text: story.capitalized, icon: "book")
                }
            }
            .padding(12)
        }
        .overlay(alignment: .topTrailing) {
            if let device = viewModel.device?.rawValue {
                CapsuleLabel(text: device, icon: "iphone")
                    .padding(12)
            }
        }
        .onPreferenceChange(UserStoryPreferenceKey.self) { userStory in
            guard viewModel.story != userStory else { return }
            viewModel.story = userStory
        }
        .onPreferenceChange(StatePreferenceKey.self) { state in
            guard viewModel.state != state else { return }
            viewModel.state = state
        }
        .padding([.horizontal, .top], 16)
    }
}

private struct MiniView<Content: View>: View, Identifiable {
    let id: String
    let isScreen: Bool
    var view: Content

    @State private var safeAreaInsets: UIEdgeInsets = UIApplication.shared.firstKeyWindow?.safeAreaInsets ?? .zero

    var body: some View {
        view
            .allowsHitTesting(false)
            .frame(width: .screenWidth)
            .transformIf(isScreen) { view in
                view.frame(height: .screenHeight - safeAreaInsets.top + safeAreaInsets.bottom - .infoViewHeight)
            }
            .modifier(ScaleModifier(scale: .scale))
    }
}

private struct InfoView: View {
    @Binding var renderTime: String?
    @Binding var state: PreviewModel.State?

    let story: PreviewModel.UserStory?
    let device: PreviewDevice?
    let layoutType: PreviewModel.LayoutType

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                CapsuleLabel(text: layoutType.displayLabel, icon: layoutType.iconName, style: .accent)

                if let state = state {
                    CapsuleLabel(text: state.capitalized, icon: "square.stack.3d.down.right")
                }

                if let story = story, layoutType == .component {
                    CapsuleLabel(text: story.capitalized, icon: "book")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                MetadataRow(icon: "clock", label: "Render", value: renderTime ?? "—")

                if let device = device?.rawValue {
                    MetadataRow(icon: "iphone", label: "Device", value: device)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.callout.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
        }
    }
}

private struct CapsuleLabel: View {
    enum Style {
        case accent
        case neutral
    }

    let text: String
    let icon: String
    let style: Style

    init(text: String, icon: String, style: Style = .neutral) {
        self.text = text
        self.icon = icon
        self.style = style
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(background)
        .foregroundColor(foreground)
        .clipShape(Capsule())
    }

    private var background: Color {
        switch style {
        case .accent:
            return Color.accentColor.opacity(0.18)
        case .neutral:
            return Color(UIColor.secondarySystemBackground)
        }
    }

    private var foreground: Color {
        switch style {
        case .accent:
            return Color.accentColor
        case .neutral:
            return Color.primary
        }
    }
}

private struct EmptyStateView: View {
    let searchText: String
    let hasFilters: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(32)
    }

    private var title: String {
        hasFilters ? "No matches" : "Playbook is empty"
    }

    private var message: String {
        if hasFilters {
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Try adjusting filters to find your preview states."
            } else {
                return "No previews matched \"\(searchText)\". Try a wider search or reset filters."
            }
        } else {
            return "Add Prefire previews to your project and they will appear here automatically."
        }
    }
}

private struct PlaybookDetailView: View {
    @Binding var viewModel: PreviewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                viewModel.content()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 16)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Details")
                        .font(.title3.bold())

                    MetadataRow(icon: "square.stack.3d.down.right", label: "State", value: viewModel.state?.capitalized ?? "Default")
                    MetadataRow(icon: "book", label: "Story", value: viewModel.story ?? "—")
                    MetadataRow(icon: "iphone", label: "Device", value: viewModel.device?.rawValue ?? "Automatic")
                    MetadataRow(icon: "speedometer", label: "Render time", value: viewModel.renderTime ?? "Pending")
                    MetadataRow(icon: "square.grid.2x2", label: "Layout", value: viewModel.type.displayLabel)
                    MetadataRow(icon: "doc.on.doc", label: "Identifier", value: viewModel.id)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(viewModel.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension PreviewModel.LayoutType {
    var displayLabel: String {
        switch self {
        case .screen:
            return "Screen"
        case .component:
            return "Component"
        }
    }

    var iconName: String {
        switch self {
        case .screen:
            return "iphone"
        case .component:
            return "square.grid.2x2"
        }
    }
}

private extension UIApplication {
    var firstKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

#endif

// MARK: - Helpers

private extension Array where Element == String {
    func sortedCaseInsensitive() -> [String] {
        sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

private extension Array {
    func uniqued() -> Self {
        NSOrderedSet(array: self).array as! Self
    }
}
