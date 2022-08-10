//
//  MainMenu.swift
//  SnapshotAppSwiftUI (iOS)
//
//  Created by Maksim Grishutin on 08.08.2022.
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
