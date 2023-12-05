import Foundation
import SwiftUI

struct ScaleModifier: ViewModifier {
    @State private var size: CGSize = .zero
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            size = CGSize(width: proxy.size.width * scale, height: proxy.size.height * scale)
                        }
                },
                alignment: .center
            )
            .scaleEffect(scale)
            .frame(width: size.width, height: size.height)
    }
}

// MARK: - ScaleEffectButtonStyle

struct ScaleEffectButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.linear(duration: 0.15), value: configuration.isPressed)
    }
}
