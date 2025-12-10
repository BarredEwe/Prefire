import Foundation
import Prefire
import SwiftUI

struct TestView: View {
    @State
    var isLoading = false

    var body: some View {
        VStack {
            LinearGradient(gradient: Gradient(
                colors: [Color("gradientStart", bundle: .module),
                         Color("gradientEnd", bundle: .module)]),
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 200)

            CircleImage()
                .offset(y: -130)
                .padding(.bottom, -130)

            VStack(alignment: .leading) {
                Text("Turtle Rock")
                    .font(.title)

                HStack {
                    Text("Joshua Tree National Park")
                        .font(.subheadline)
                    Spacer()
                    Text("California")
                        .font(.subheadline)
                }
            }
            .padding()

            Spacer()
        }
        .redacted(reason: isLoading ? .placeholder : [])
    }
}

extension PreviewModel.UserStory {
    static let testStory = "Test"
}

extension PreviewModel.State {
    static let loading = "loading"
}

struct TestView_Previews: PreviewProvider, PrefireProvider {
    static var previews: some View {
        TestView(isLoading: false)
            .previewUserStory(.testStory)
            .snapshot(delay: 0.5, precision: 0.7)
            .previewDevice(PreviewDevice(rawValue: "iPhone 8"))

        TestView(isLoading: true)
            .previewUserStory(.testStory)
            .previewState(.loading)
            .previewDevice(PreviewDevice(rawValue: "iPhone 8"))

        TestView(isLoading: true)
            .previewUserStory(.testStory)
            .previewState(.loading)
            .snapshot(delay: 0.3, precision: 0.9)
            .previewDevice(PreviewDevice(rawValue: "iPhone 8"))
    }
}

struct TestViewWithoutState_Previews: PreviewProvider, PrefireProvider {
    static var previews: some View {
        TestView(isLoading: true)
            .previewUserStory(.testStory)
            .snapshot(delay: 0.1, precision: 0.9)
            .previewLayout(.sizeThatFits)
    }
}

struct GreenButton_Previews: PreviewProvider, PrefireProvider {
    static var previews: some View {

        Button("Apply", action: {})
            .foregroundColor(.dynamicForegroundColor)
            .font(.title)
            .padding()
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(Capsule().foregroundColor(.dynamicGreen))
            .previewLayout(.sizeThatFits)
            .previewUserStory("Buttons")

    }
}

#Preview(traits: .sizeThatFitsLayout) {
    TestView(isLoading: true)
        .previewUserStory(.testStory)
        .snapshot(delay: 0.1, precision: 0.9)
        .previewUserStory(.auth)
}

extension Color {
    static var dynamicForegroundColor: Color {
        Color(UIColor.dynamicForegroundColor)
    }

    static var dynamicGreen: Color {
        Color(UIColor.dynamicGreen)
    }
}

extension UIColor {
    static var dynamicForegroundColor: UIColor {
        UIColor(dynamicProvider: { trait in
            switch trait.userInterfaceStyle {
                case .dark: return .white
            default: return .black
            }
        })
    }

    static var dynamicGreen: UIColor {
        UIColor(dynamicProvider: { trait in
            switch trait.userInterfaceStyle {
            case .dark: return UIColor.green.withAlphaComponent(0.8)
            default: return UIColor.green.withAlphaComponent(0.2)
            }
        })
    }
}
