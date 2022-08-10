//
//  SnapshotAppSwiftUIApp.swift
//  Shared
//
//  Created by Maksim Grishutin on 04.08.2022.
//

import SwiftUI

@main
struct SnapshotAppSwiftUIApp: App {
    var body: some Scene {
        WindowGroup {
//            ContentView()
            MainMenu()
                .preferredColorScheme(.light)
        }
    }
}
