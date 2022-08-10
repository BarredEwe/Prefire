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
    static let scale: CGFloat = 0.6
}

struct ContentView: View {
    @State var navigationLinkTriggerer: Bool = false
    @State var selectedId: String = ""

    @State var views: [SystemViewModel] = UISystemViews.views

    @Environment(\.safeAreaInsets) private var safeAreaInsets
    
    private var sections: [String] = (NSOrderedSet(array: UISystemViews.views.compactMap { $0.name }).array as? [String]) ?? []

    var body: some View {
        VStack {
            NavigationLink(
                isActive: $navigationLinkTriggerer,
                destination: { selectedView },
                label: { EmptyView() }
            )

            ScrollView {
                ForEach(sections, id: \.self) { name in
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("SwiftUI System")
    }

    @ViewBuilder
    func componentList(for name: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach($views) { $view in
                    if view.name == name {
                        Button(action: {
                            selectedId = view.id
                            navigationLinkTriggerer.toggle()
                        }) {
                            VStack(alignment: .center, spacing: 0) {
                                miniView(for: view)
                                    .modifier(LoadingTimeModifier(completion: { loadingTime in
                                        view.renderTime = loadingTime
                                    }))
                                    .onPreferenceChange(ViewTypePreferenceKey.self, perform: { viewType in
                                        view.type = viewType
                                    })
                                    .onPreferenceChange(UserStoryPreferenceKey.self) { userStory in
                                        view.story = userStory
                                    }

                                Divider()

                                HStack(alignment: .center, spacing: 8) {
                                    Text(view.state.capitalized)
                                        .font(.caption.bold())
                                        .padding()
                                    Spacer()

//                                    if let userStory = view.story {
//                                        Text(userStory)
//                                            .font(.title2.bold())
//                                            .padding(.horizontal)
//                                            .padding(.vertical, 8)
//                                    }

                                    if let renderTime = view.renderTime {
                                        Text(renderTime)
                                            .font(.caption.bold())
                                            .padding(8)
                                    }
                                }
                                .frame(width: UIScreen.main.bounds.width * .scale)
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

    func miniView(for view: SystemViewModel) -> some View {
        view.content()
            .disabled(true)
            // change to GeoReader
            .frame(width: UIScreen.main.bounds.width)
            .transformIf(view.type == .screen) { view in
                view.frame(height: UIScreen.main.bounds.height - safeAreaInsets.top + safeAreaInsets.bottom)
            }
            .modifier(StaticContentSizeModifier(scale: .scale))
    }

    @ViewBuilder
    var selectedView: some View {
        let wrapperView = views.first(where: { $0.id == selectedId })
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


//

private struct LoadingTimeModifier: ViewModifier {
    var formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.nanosecond]
        return formatter
    }()
    @State
    var createDate: Date = Date()
    var completion: (String) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Нужно сохранять в массив средних значений по id
                let diffTime = Date().timeIntervalSince(createDate) * 1000
                completion(String(diffTime.truncatingRemainder(dividingBy: 1000).rounded()) + " ms")
            }
    }
}

private struct StaticContentSizeModifier: ViewModifier {

    @State var size: CGSize = .zero
    var scale: CGFloat = 1.0

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
            .animation(.linear(duration: 0.1), value: configuration.isPressed)
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
        (UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets ?? .zero).insets
    }
}

extension EnvironmentValues {

    var safeAreaInsets: EdgeInsets {
        self[SafeAreaInsetsKey.self]
    }
}

private extension UIEdgeInsets {

    var insets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}
