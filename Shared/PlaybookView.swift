//
//  ContentView.swift
//  Shared
//
//  Created by Maksim Grishutin on 04.08.2022.
//

import SwiftUI
import Foundation
import SwiftUISystem

extension CGFloat {
    static let scale: CGFloat = 0.55
    static let infoViewHeight: CGFloat = 42
}

public struct PlaybookView: View {
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @Environment(\.colorScheme) private var colorScheme

    @State private var navigationLinkTriggered: Bool = false
    @State private var selectedId: String = ""
    @State private var searchText = ""
    @State private var viewModels: [PreviewModel] = PreviewModels.models
    @State private var sections: [String] = PreviewModels.models.compactMap { $0.name }.uniqued()

    private let isComponent: Bool

    public init(isComponent: Bool) {
        self.isComponent = isComponent
    }

    public var body: some View {
        VStack {
            NavigationLink(
                isActive: $navigationLinkTriggered,
                destination: { selectedView },
                label: { EmptyView() }
            )

            ScrollView {
                ForEach(sections, id: \.self) { name in
                    if searchText.isEmpty || name.contains(searchText) {
                        VStack(alignment: .leading) {
                            Text(isComponent ? name : "📙 " + name)
                                .font(.title.bold())
                                .padding(.horizontal, 16)
                                .padding(.bottom, -8)

                            componentList(for: name)

                            if sections.last != name {
                                Divider()
                            }
                        }
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: isComponent ? "View name" : "User story"
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("SwiftUI System")
    }

    @ViewBuilder
    private func componentList(for name: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach($viewModels) { $viewModel in
                    if viewModel.name == name || viewModel.story == name {
                        VStack {
                            if !isComponent {
                                Text(viewModel.name)
                                    .font(.callout.bold().monospaced())
                            }

                            Button(action: {
                                selectedId = viewModel.id
                                navigationLinkTriggered.toggle()
                            }) {
                                VStack(alignment: .center, spacing: 0) {
                                    miniView(for: viewModel)
                                        .modifier(LoadingTimeModifier { loadingTime in
                                            viewModel.renderTime = loadingTime
                                        })
                                        .onPreferenceChange(ViewTypePreferenceKey.self) { viewType in
                                            viewModel.type = viewType
                                        }
                                        .onPreferenceChange(UserStoryPreferenceKey.self) { userStory in
                                            viewModel.story = userStory

                                            if !isComponent {
                                                sections = viewModels.compactMap { $0.story }.uniqued()
                                            }
                                        }

                                    Divider()

                                    infoView(for: viewModel)
                                }
                                .background(colorScheme == .dark ? Color(UIColor.darkGray) : Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.gray.opacity(0.7), radius: 8)
                            }
                            .buttonStyle(ScaleEffectButtonStyle())
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func miniView(for viewModel: PreviewModel) -> some View {
        viewModel.content()
            .disabled(true)
            .frame(width: UIScreen.main.bounds.width)
            .transformIf(viewModel.type == .screen) { view in
                view.frame(height: UIScreen.main.bounds.height - safeAreaInsets.top + safeAreaInsets.bottom - .infoViewHeight)
            }
            .modifier(ScaleModifier(scale: .scale))
    }

    @ViewBuilder
    private func infoView(for viewModel: PreviewModel) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text("State")
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                    .font(.caption.smallCaps())
                Text(viewModel.state.capitalized)
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                    .font(.caption.weight(.heavy))
            }
            .padding(8)

            Spacer()

            if let renderTime = viewModel.renderTime {
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PlaybookView(isComponent: true)
        }
    }
}


// MARK: - Additional

private extension Array {
    func uniqued() -> Self {
        NSOrderedSet(array: self).array as! Self
    }
}

struct ScaleEffectButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.linear(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    @ViewBuilder
    func transformIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
