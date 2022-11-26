//
//  SnapshotAppSwiftUIApp.swift
//  Shared
//
//  Created by Maksim Grishutin on 04.08.2022.
//

import SwiftUI

@main
struct PrefireExampleApp: App {
    var body: some Scene {
        WindowGroup {
            MainMenu()
                .preferredColorScheme(.light)
        }
    }
}
