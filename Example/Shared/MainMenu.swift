import Prefire
import SwiftUI

struct MainMenu: View {
    #if os(iOS)
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

    #elseif os(macOS)
    var body: some View {
        Text("macOS not yet supported")
    }
    #else
    var body: some View {
        Text("tvOS not yet supported")
    }
    #endif
}

struct MainMenu_Previews: PreviewProvider {
    static var previews: some View {
        MainMenu()
    }
}
