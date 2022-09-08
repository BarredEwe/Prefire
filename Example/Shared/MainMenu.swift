//
//  MainMenu.swift
//  SnapshotAppSwiftUI (iOS)
//
//  Created by Maksim Grishutin on 08.08.2022.
//

import SwiftUI
import PreFire

struct MainMenu: View {
    var body: some View {
        NavigationView {
            Form {
                NavigationLink {
                    PlaybookView(isComponent: true, previewModels: PreviewModels.models)
                } label: {
                    Label("Views", systemImage: "shippingbox")
                        .foregroundColor(.black)
                }

                NavigationLink {
                    PlaybookView(isComponent: false, previewModels: PreviewModels.models)
                } label: {
                    Label("User stories", systemImage: "character.book.closed")
                        .foregroundColor(.black)
                }
            }
            .navigationTitle("SwiftUI System")
        }
    }
}

struct MainMenu_Previews: PreviewProvider {
    static var previews: some View {
        MainMenu()
    }
}
