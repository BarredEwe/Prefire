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

struct ContentView: View {
    @State private var navigationLinkTriggered: Bool = false
    @State private var selectedId: String = ""
    @State private var searchText = ""
    @State private var viewModels: [SystemViewModel] = UISystemViews.views
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    
    private var sections: [String] = (NSOrderedSet(array: UISystemViews.views.compactMap { $0.name }).array as? [String]) ?? []

    var body: some View {
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
                            Text(name)
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
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "View name")
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("SwiftUI System")
    }

    @ViewBuilder
    private func componentList(for name: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach($viewModels) { $viewModel in
                    if viewModel.name == name {
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
                                    }

                                Divider()

                                infoView(for: viewModel)
                            }
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(radius: 8)
                        }
                        .buttonStyle(ScaleEffectButtonStyle())
                    }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func miniView(for viewModel: SystemViewModel) -> some View {
        viewModel.content()
            .disabled(true)
            // change to GeoReader
            .frame(width: UIScreen.main.bounds.width)
            .transformIf(viewModel.type == .screen) { view in
                view.frame(height: UIScreen.main.bounds.height - safeAreaInsets.top + safeAreaInsets.bottom - .infoViewHeight)
            }
            .modifier(StaticContentSizeModifier(scale: .scale))
    }

    @ViewBuilder
    private func infoView(for viewModel: SystemViewModel) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text("State")
                    .font(.caption.smallCaps())
                Text(viewModel.state.capitalized)
                    .font(.caption.weight(.heavy))
            }
            .padding(8)

            Spacer()

//                                    if let userStory = viewModel.story {
//                                        Text(userStory)
//                                            .font(.title2.bold())
//                                            .padding(.horizontal)
//                                            .padding(.vertical, 8)
//                                    }

            if let renderTime = viewModel.renderTime {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("Render time")
                        .font(.caption.smallCaps())
                    Text(renderTime)
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
            ContentView()
        }
        //        MainMenu()
    }
}


// MARK: - Additionals

private struct StaticContentSizeModifier: ViewModifier {
    @State var size: CGSize = .zero
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            size = proxy.size
                        }
                }
            }
            .scaleEffect(scale)
            .frame(width: size.width * scale, height: size.height * scale)
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
    /// Проверяет правдивость condition и если true, применяет изменения к View.
    @ViewBuilder
    func transformIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

private struct SafeAreaInsetsKey: EnvironmentKey {
    static var defaultValue: EdgeInsets {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.swiftUiInsets ?? EdgeInsets()
    }
}

public extension EnvironmentValues {
    /// Отступы, которые используется для определения безопасной области для этого представления.
    var safeAreaInsets: EdgeInsets {
        self[SafeAreaInsetsKey.self]
    }
}

private extension UIEdgeInsets {
    var swiftUiInsets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}
