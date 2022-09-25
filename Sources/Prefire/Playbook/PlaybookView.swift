//
//  ContentView.swift
//  Shared
//
//  Created by Maksim Grishutin on 04.08.2022.
//

import SwiftUI
import Foundation

extension CGFloat {
    static let scale: CGFloat = 0.55
    static let infoViewHeight: CGFloat = 42
}

public struct PlaybookView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var navigationLinkTriggered: Bool = false
    @State private var selectedId: String = ""
    @State private var searchText = ""
    @State private var viewModels: [PreviewModel]
    @State private var sectionNames: [String]
    @State private var safeAreaInsets = EdgeInsets()

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

            GeometryReader { geo in
                ScrollView {
                    VStack {
                        ForEach(sectionNames, id: \.self) { name in
                            if searchText.isEmpty || name.contains(searchText) {
                                VStack(alignment: .leading) {
                                    Text(isComponent ? name : "📙 " + name)
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
                .onAppear {
                    safeAreaInsets = geo.safeAreaInsets
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

                            Button(action: {
                                selectedId = viewModel.id
                                navigationLinkTriggered.toggle()
                            }) {
                                VStack(alignment: .center, spacing: 0) {
                                    miniView(for: viewModel)
                                        .modifier(LoadingTimeModifier { loadingTime in
                                            viewModel.renderTime = loadingTime
                                        })
                                        .onPreferenceChange(UserStoryPreferenceKey.self) { userStory in
                                            viewModel.story = userStory

                                            if !isComponent {
                                                sectionNames = viewModels.compactMap { $0.story }.uniqued()
                                            }
                                        }
                                        .onPreferenceChange(StatePreferenceKey.self) { state in
                                            viewModel.state = state
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
                Text((viewModel.state ?? "default").capitalized)
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
            PlaybookView(isComponent: true, previewModels: [])
        }
    }
}


// MARK: - Additional

private extension Array {
    func uniqued() -> Self {
        NSOrderedSet(array: self).array as! Self
    }
}
