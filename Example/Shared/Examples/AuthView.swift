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
                .disabled(login.isEmpty && password.isEmpty)

                Button {

                } label: {
                    Text("Registration")
                        .frame(maxWidth: .infinity)
                }
                .tint(.accentColor)
                .buttonStyle(.bordered)
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

struct AuthView_Preview: PreviewProvider, PrefireProvider {
    static var previews: some View {
        Group {
            AuthView(login: "", password: "")

            AuthView(login: "FireUser", password: "FirePassword")
        }
        .previewUserStory(.auth)
    }
}
