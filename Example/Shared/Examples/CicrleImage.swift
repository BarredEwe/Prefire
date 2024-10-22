import Prefire
import SwiftUI

struct CircleImage: View {
    var body: some View {
        Image("nature")
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 4))
            .shadow(radius: 7)
    }
}

//struct CircleImage_Previews: PreviewProvider, PrefireProvider {
//    static var previews: some View {
//        CircleImage()
//            .previewLayout(.sizeThatFits)
//    }
//}

#Preview {
    CircleImage()
        .writeSnapshot()
        // rewriteSnapshot
//        .onAppear {
//            Task { @MainActor in
//                print("Run write Snapshot")
//
//                let image = ImageRenderer(content: CircleImage()).uiImage
//                //            let directory = FileManager.default.temporaryDirectory.appending(component: "prefire/test.png")
//
//                if let pngData = image?.pngData() {
//                    let url = URL(string: "file:///Users/mgrishutin/Documents/Presentations/image.png")!
//                    do {
//                        try pngData.write(to: url)
//                        print("🟢 Success: \(url)")
//                    } catch {
//                        print(error)
//                    }
//                }
//            }
//        }
}
