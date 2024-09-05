import Foundation
import SwiftUI

extension CGFloat {
    static let scale: CGFloat = 0.55
    static let infoViewHeight: CGFloat = 42
    static let screenHeight = UIScreen.main.bounds.height
    static let screeenWidth = UIScreen.main.bounds.width
}

/// View to show different states of components and screens
///
/// Can display Previews in two types:
/// - `isComponent: false // Sorted by Flow`
/// - `isComponent: true  // Sorted by screen or component name`
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

    public var body: some View {
        VStack {
            NavigationLink(
                isActive: $navigationLinkTriggered,
                destination: { selectedView },
                label: { EmptyView() }
            )

            ScrollView {
                VStack {
                    ForEach(sectionNames, id: \.self) { name in
                        if searchText.isEmpty || name.lowercased().contains(searchText.lowercased()) {
                            VStack(alignment: .leading) {
                                Text(isComponent ? name : "📙 \(name.capitalized)")
                                    .font(.title.bold())
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, -8)

                                componentList(for: name)

                                if sectionNames.last != name {
                                    Divider()
                                }
                            }
                        }
                    }
                }
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("SwiftUI System")
    }

    @ViewBuilder
    private func componentList(for name: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach($viewModels) { $viewModel in
                    if viewModel.name == name || viewModel.story == name {
                        VStack {
                            if !isComponent {
                                Text(viewModel.name)
                                    .font(.callout.bold())
                            }
                            PreviewView(
                                isComponent: isComponent,
                                selectedId: $selectedId,
                                navigationLinkTriggered: $navigationLinkTriggered,
                                viewModel: $viewModel,
                                viewModels: $viewModels,
                                sectionNames: $sectionNames
                            )
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    struct PreviewView: View, Identifiable {
        @inlinable
        var id: String {
            viewModel.id
        }

        let isComponent: Bool

        @Binding var selectedId: String
        @Binding var navigationLinkTriggered: Bool
        @Binding var viewModel: PreviewModel
        @Binding var viewModels: [PreviewModel]
        @Binding var sectionNames: [String]
        @Environment(\.colorScheme) private var colorScheme

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
                    .modifier(LoadingTimeModifier { loadingTime in
                        guard viewModel.renderTime == nil else { return }
                        viewModel.renderTime = loadingTime
                    })
                    .onPreferenceChange(UserStoryPreferenceKey.self) { userStory in
                        guard viewModel.story != userStory else { return }
                        viewModel.story = userStory

                        if !isComponent {
                            sectionNames = viewModels.compactMap { $0.story }.uniqued()
                        }
                    }
                    .onPreferenceChange(StatePreferenceKey.self) { state in
                        guard viewModel.state != state else { return }
                        viewModel.state = state
                    }

                    Divider()

                    InfoView(renderTime: $viewModel.renderTime, state: $viewModel.state)
                }
                .background(colorScheme == .dark ? Color(UIColor.darkGray) : Color.white)
                .cornerRadius(16)
                .shadow(color: Color.gray.opacity(0.7), radius: 8)
            }
            .buttonStyle(ScaleEffectButtonStyle())
        }
    }

    struct MiniView<Content: View>: View, Identifiable {
        let id: String
        let isScreen: Bool
        var view: Content
        @Environment(\.safeAreaInsets) private var safeAreaInsets

        var body: some View {
            view
                .allowsHitTesting(false)
                .frame(width: .screeenWidth)
                .transformIf(isScreen) { view in
                    view.frame(height: .screenHeight - safeAreaInsets.top + safeAreaInsets.bottom - .infoViewHeight)
                }
                .modifier(ScaleModifier(scale: .scale))
        }
    }

    struct InfoView: View {
        @Environment(\.colorScheme) private var colorScheme

        @Binding var renderTime: String?
        @Binding var state: PreviewModel.State?

        var body: some View {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("State")
                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                        .font(.caption.smallCaps())
                    Text((state ?? "default").capitalized)
                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                        .font(.caption.weight(.heavy))
                }
                .padding(8)

                Spacer()

                if let renderTime = renderTime {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Render time")
                            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                            .font(.caption.smallCaps())
                        Text(renderTime)
                            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                            .font(.caption.weight(.heavy))
                    }
                    .padding(8)
                }
            }
            .frame(width: UIScreen.main.bounds.width * .scale, height: .infoViewHeight)
        }
    }

    @ViewBuilder
    private var selectedView: some View {
        let wrapperView = viewModels.first(where: { $0.id == selectedId })
        VStack {
            wrapperView?.content()

            Spacer()
        }
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
                PreviewModel(id: "2", content: { AnyView(Text("Test 2").padding()) }, name: "Test 2", device: nil),
            ]
        )
    }
}
