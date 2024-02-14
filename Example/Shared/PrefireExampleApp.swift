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
