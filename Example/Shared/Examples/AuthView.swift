import Prefire
import SwiftUI

struct AuthView: View {
    @State var login: String
    @State var password: String

    var body: some View {
        ScrollView {
            PrefireView()
                .padding()

            VStack {
                TextField("Login", text: $login)
                    .padding(.vertical)

                TextField("Password", text: $password)
                    .textContentType(.password)
                    .padding(.vertical)
            }
            .padding()

            VStack {
                Button {

                } label: {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
                .tint(.black.opacity(0.9))
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(login.isEmpty && password.isEmpty)

                Button {

                } label: {
                    Text("Registration")
                        .frame(maxWidth: .infinity)
                }
                .tint(.accentColor)
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()

            Text("More about product")
                .font(.headline)
                .padding()
        }
    }
}

extension PreviewModel.State {
    static let auth = "auth"
}

//struct AuthView_Preview: PreviewProvider, PrefireProvider {
//    static var previews: some View {
//        Group {
//            AuthView(login: "", password: "")
//
//            AuthView(login: "FireUser", password: "FirePassword")
//        }
//        .previewUserStory(.auth)
//    }
//}

#Preview {
    AuthView(login: "123", password: "123")
        .writeSnapshot()
//        .onAppear {
//            Task { @MainActor in
//                print("Run write Snapshot")
//
////                let image = ImageRenderer(content: 
////                                            AuthView(login: "123", password: "123")
////                    .background(Color.red)
////                    .frame(width: 500, height: 500)
//                let viewController = UIHostingController(rootView: AuthView(login: "123", password: "123"))
////                let maxSize = CGSize(width: 0.0, height: 0.0)
////                viewController.sizeThatFits(in: maxSize)
//
//                let renderer = UIGraphicsImageRenderer(bounds: UIScreen.main.bounds)
//
//                let pngData = renderer.pngData { context in
//                    viewController.view.layer.render(in: context.cgContext)
//                }
//
////                ).uiImage
//                //            let directory = FileManager.default.temporaryDirectory.appending(component: "prefire/test.png")
//
////                if let pngData = pngData() {
//                    let url = URL(string: "file:///Users/mgrishutin/Documents/Presentations/image1.png")!
//                    do {
//                        try pngData.write(to: url)
//                        print("🟢 Success: \(url)")
//                    } catch {
//                        print(error)
//                    }
////                }
//            }
//        }
}

struct SnapshotModifier<SnapshotView: View>: ViewModifier {
    @State private var isRecordedSnapshot: Bool = false

    private let view: SnapshotView
    private let viewTypeName: String

    init(view: SnapshotView) {
        self.view = view
        self.viewTypeName = String(describing: SnapshotView.self)
//        self.viewTypeName = String(describing: view.self)
    }

    func body(content: Content) -> some View {
        return content
            .onAppear {
                if !isRecordedSnapshot {
                    isRecordedSnapshot = true
        //            Task { @MainActor in
                        print("Run write Snapshot")

        //                let image =
        //                image.pngData()

        //                let renderer = ImageRenderer(content: content)
        //                let image = renderer.uiImage ?? content.snapshot()
                    let image = view.snapshot()//view.snapshot()

                        if let pngData = image.pngData() {
                            let url = URL(string: "file:///Users/mgrishutin/Documents/Presentations/\(viewTypeName).png")!
                            do {
                                try pngData.write(to: url)
                                print("🟢 Success: \(url)")
                            } catch {
                                print("🔴 " + error.localizedDescription)
                            }
                        } else {
                            print("🔴 No image data \(viewTypeName)")
                        }
        //            }
                }
//                return content
        }
    }
}

extension View {
    func writeSnapshot() -> some View {
        modifier(SnapshotModifier(view: self))
    }
}

extension View {
    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view

        let targetSize = controller.view.intrinsicContentSize
//        let targetSize = UIScreen.main.bounds.size
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear

//         Обеспечиваем, что представление загружено
        DispatchQueue.main.async {
            view?.setNeedsLayout()
            view?.layoutIfNeeded()
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            controller.view.layer.render(in: context.cgContext)
        }

//        return renderer.image { _ in
//            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
//        }
    }
}
