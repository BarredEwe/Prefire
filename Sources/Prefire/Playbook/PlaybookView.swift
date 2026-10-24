import Foundation
import SwiftUI

#if os(iOS)

extension CGFloat {
    static let scale: CGFloat = 0.46
    static let infoViewHeight: CGFloat = 42
    static let cardCornerRadius: CGFloat = 20
    static let horizontalInset: CGFloat = 20
    @MainActor static let screenHeight = UIScreen.main.bounds.height
    @MainActor static let screenWidth = UIScreen.main.bounds.width
}

/// View to show different states of components and screens
///
/// Can display Previews in two types:
/// - `isComponent: false // Sorted by Flow`
/// - `isComponent: true  // Sorted by screen or component name`
@available(tvOS, unavailable)
public struct PlaybookView: View {
    @State private var navigationLinkTriggered: Bool = false
    @State private var selectedId: String = ""
    @State private var searchText = ""
    @State private var viewModels: [PreviewModel]
    @State private var sectionNames: [String]

    private let isComponent: Bool

    public init(isComponent: Bool, previewModels: [PreviewModel]) {
        self.isComponent = isComponent
        _viewModels = State(initialValue: previewModels)
        _sectionNames = State(initialValue: previewModels.compactMap { $0.name }.uniqued())
    }

    private var visibleSectionNames: [String] {
        guard !searchText.isEmpty else { return sectionNames }
        return sectionNames.filter { $0.lowercased().contains(searchText.lowercased()) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavigationLink(
                isActive: $navigationLinkTriggered,
                destination: { selectedView },
                label: { EmptyView() }
            )

            ScrollView {
                // Not lazy: user stories are collected from the preferences of rendered previews
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(visibleSectionNames, id: \.self) { name in
                        VStack(alignment: .leading, spacing: 4) {
                            SectionHeader(
                                title: isComponent ? name : name.capitalized,
                                isUserStory: !isComponent,
                                count: indices(for: name).count
                            )

                            componentList(for: name)
                        }
                    }

                    if visibleSectionNames.isEmpty {
                        EmptySearchView(searchText: searchText)
                    }
                }
                .padding(.vertical, 16)
            }
            .transformIf(true) { view -> AnyView in
                if #available(iOS 15.0, *) {
                    return AnyView(
                        view.searchable(
                            text: $searchText,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: isComponent ? "View name" : "User story"
                        )
                    )
                } else {
                    return AnyView(view)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(isComponent ? "Components" : "User Stories")
    }

    private func indices(for name: String) -> [Int] {
        viewModels.indices.filter { viewModels[$0].name == name || viewModels[$0].story == name }
    }

    @ViewBuilder
    private func componentList(for name: String) -> some View {
        let indices = indices(for: name)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(Array(indices.enumerated()), id: \.element) { step, index in
                    if !isComponent && step > 0 {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                            .padding(.top, 60)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if !isComponent {
                            StepLabel(step: step + 1, name: viewModels[index].name)
                        }

                        PreviewView(
                            isComponent: isComponent,
                            selectedId: $selectedId,
                            navigationLinkTriggered: $navigationLinkTriggered,
                            viewModel: $viewModels[index],
                            viewModels: $viewModels,
                            sectionNames: $sectionNames
                        )
                    }
                }
            }
            .padding(.horizontal, .horizontalInset)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    struct SectionHeader: View {
        let title: String
        let isUserStory: Bool
        let count: Int

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: isUserStory ? "book.closed.fill" : "square.on.square")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: isUserStory ? [.orange, .red] : [.purple, Color(UIColor.systemIndigo)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )

                Text(title)
                    .font(.title2.bold())
                    .lineLimit(1)

                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(UIColor.tertiarySystemFill)))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, .horizontalInset)
        }
    }

    struct StepLabel: View {
        let step: Int
        let name: String

        var body: some View {
            HStack(spacing: 6) {
                Text("\(step)")
                    .font(.caption2.weight(.heavy))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.orange))

                Text(name)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .screenWidth * .scale, alignment: .leading)
        }
    }

    struct EmptySearchView: View {
        let searchText: String

        var body: some View {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                Text("No previews match “\(searchText)”")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
        }
    }

    struct PreviewView: View, Identifiable {
        let id: String

        let isComponent: Bool

        @Binding var selectedId: String
        @Binding var navigationLinkTriggered: Bool
        @Binding var viewModel: PreviewModel
        @Binding var viewModels: [PreviewModel]
        @Binding var sectionNames: [String]

        init(isComponent: Bool, selectedId: Binding<String>, navigationLinkTriggered: Binding<Bool>, viewModel: Binding<PreviewModel>, viewModels: Binding<[PreviewModel]>, sectionNames: Binding<[String]>) {
            self.id = viewModel.wrappedValue.id
            self.isComponent = isComponent
            _selectedId = selectedId
            _navigationLinkTriggered = navigationLinkTriggered
            _viewModel = viewModel
            _viewModels = viewModels
            _sectionNames = sectionNames
        }

        var body: some View {
            Button(action: {
                selectedId = viewModel.id
                navigationLinkTriggered.toggle()
            }) {
                VStack(alignment: .center, spacing: 0) {
                    MiniView(
                        id: viewModel.id,
                        isScreen: viewModel.type == .screen,
                        view: viewModel.content()
                    )
                    .background(Color(UIColor.systemBackground))
                    .modifier(LoadingTimeModifier { loadingTime in
                        guard viewModel.renderTime == nil else { return }
                        viewModel.renderTime = loadingTime
                    })
                    .onPreferenceChange(UserStoryPreferenceKey.self) { userStory in
                        Task { @MainActor in
                            guard viewModel.story != userStory else { return }
                            viewModel.story = userStory

                            if !isComponent {
                                sectionNames = viewModels.compactMap { $0.story }.uniqued()
                            }
                        }
                    }
                    .onPreferenceChange(StatePreferenceKey.self) { state in
                        Task { @MainActor in
                            guard viewModel.state != state else { return }
                            viewModel.state = state
                        }
                    }

                    InfoView(renderTime: $viewModel.renderTime, state: $viewModel.state)
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: .cardCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: .cardCornerRadius, style: .continuous)
                        .strokeBorder(Color(UIColor.separator).opacity(0.6), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(ScaleEffectButtonStyle())
        }
    }

    struct MiniView<Content: View>: View, Identifiable {
        let id: String
        let isScreen: Bool
        var view: Content

        @State private var safeAreaInsets = UIApplication.shared.windows.first?.safeAreaInsets ?? UIEdgeInsets()

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

    struct InfoView: View {
        @Binding var renderTime: String?
        @Binding var state: PreviewModel.State?

        var body: some View {
            HStack(alignment: .center, spacing: 8) {
                StateBadge(state: state)

                Spacer(minLength: 0)

                if let renderTime = renderTime {
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                        Text(renderTime)
                            .font(Font.caption.weight(.semibold).monospacedDigit())
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: UIScreen.main.bounds.width * .scale, height: .infoViewHeight)
            .overlay(Divider().opacity(0.6), alignment: .top)
        }
    }

    struct StateBadge: View {
        let state: PreviewModel.State?

        private static let palette: [Color] = [.orange, .purple, .blue, .pink, Color(UIColor.systemTeal), .green]

        private var tint: Color? {
            guard let state, state.lowercased() != "default" else { return nil }
            let seed = state.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            return Self.palette[seed % Self.palette.count]
        }

        var body: some View {
            Text((state ?? "default").uppercased())
                .font(.system(size: 10, weight: .heavy))
                .kerning(0.6)
                .lineLimit(1)
                .foregroundColor(tint ?? .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(tint.map { $0.opacity(0.15) } ?? Color(UIColor.tertiarySystemFill))
                )
        }
    }

    @ViewBuilder
    private var selectedView: some View {
        let wrapperView = viewModels.first(where: { $0.id == selectedId })
        VStack {
            wrapperView?.content()

            Spacer()
        }
        .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all))
        .navigationTitle(wrapperView?.name ?? "")
    }
}

// MARK: - Additional

private extension Array {
    func uniqued() -> Self {
        NSOrderedSet(array: self).array as! Self
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        PlaybookView(
            isComponent: true,
            previewModels: [
                PreviewModel(id: "1", content: { AnyView(Text("Test 1").padding()) }, name: "Test 1", device: nil),
                PreviewModel(id: "2", content: { AnyView(Text("Test 2").padding()) }, name: "Test 2", device: nil)
            ]
        )
    }
}
#endif
