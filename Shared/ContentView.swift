//
//  ContentView.swift
//  Shared
//
//  Created by Maksim Grishutin on 04.08.2022.
//

import SwiftUI
import SwiftUISystem

struct MainMenu: View {
    @State var navigationViewsTriggerer: Bool = false
    @State var navigationUserStoriesTriggerer: Bool = false

    var body: some View {
        NavigationView {
            Form {
                NavigationLink {
                    ContentView()
                } label: {
                    Label("Views", systemImage: "shippingbox")
                                            .foregroundColor(.black)
                }

                NavigationLink {
                    ContentView()
                } label: {
                    Label("User stories", systemImage: "character.book.closed")
                        .foregroundColor(.black)
                }
            }
            .navigationTitle("SwiftUI System")
        }
    }
}

class SystemViews: ObservableObject {
    @Published
    var views: [SystemView] = UISystemViews.views
}

struct ContentView: View {
    @State var navigationLinkTriggerer: Bool = false
    @State var selectedView: AnyView = AnyView(EmptyView())

    @State var views: [SystemView] = UISystemViews.views

    @Namespace var screenNameSpace

//    @StateObject var systemView = SystemViews()

//    @State var userStories: [SystemView.UserStory] = []
//    @State var loadedView: [WrapperView] = UISystemViews.views.map { $0.content() }

    init() {

    }

    var body: some View {
        VStack {
//            NavigationLink(
//                isActive: $navigationLinkTriggerer,
//                destination: { selectedView },
//                label: { EmptyView() }
//            )

                if navigationLinkTriggerer {
                    VStack {
                        Spacer()

                        selectedView
                            .onTapGesture {
                                withAnimation(.spring().speed(0.2)) {
                                    navigationLinkTriggerer.toggle()
                                }
                            }

                        Spacer()
                    }
                    .matchedGeometryEffect(id: "Screen" + "TestViewWithoutStatedefault", in: screenNameSpace)
                } else {
                    ScrollView {
                        componentList
                    }
                }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("SwiftUI System")
    }

    @ViewBuilder
    var componentList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach($views) { $view in
                    VStack(alignment: .center, spacing: 8) {
                        view.content()
                            .frame(width: UIScreen.main.bounds.width) // change to GeoReader
                            .modifier(StaticContentSizeModifier(scale: 0.8))
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(radius: 8)
                            .onPreferenceChange(UserStoryPreferenceKey.self) { userStory in
                                view.story = userStory
                            }
                            .onTapGesture {
                                selectedView = AnyView(
                                    view.content()
//                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
//                                        .matchedGeometryEffect(id: "Screen" + view.id, in: screenNameSpace)
                                )
                                withAnimation(.spring().speed(0.2)) {
                                    navigationLinkTriggerer.toggle()
                                }
                            }
                            .matchedGeometryEffect(id: "Screen" + view.id, in: screenNameSpace)

                        HStack(alignment: .top, spacing: 8) {
                            Text(view.state.capitalized)
                                .font(.callout)
                            Spacer()

                            if let userStory = view.story {
                                Text(userStory)
                                    .font(.title)
                            }
                        }
                    }

                }
            }
            .padding(16)

//            Spacer()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
//        NavigationView {
//            ContentView()
//        }
        MainMenu()
    }
}


//

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
