//
//  TestView.swift
//  SnapshotAppSwiftUI (iOS)
//
//  Created by Maksim Grishutin on 04.08.2022.
//

import Foundation
import SwiftUI
import SwiftUISystem

struct TestView: View {
    @State
    var isLoading = false

    var body: some View {
        VStack {
            LinearGradient(gradient: Gradient(colors: [.green, .indigo]), startPoint: .top, endPoint: .bottom)
                .frame(height: 200)

            Image("nature")
                .clipShape(Circle())
                .shadow(radius: 7)
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
        }
        .redacted(reason: isLoading ? .placeholder : [])
    }
}

extension PreviewModel.UserStory {
    static let testStory = "Test"
}

struct TestView_Previews: PreviewProvider, UISystemProvider {
    enum TestViewState: UIState {
        case `default`
        case loading
    }

    static var state: TestViewState = .default

    static var previews: some View {
        VStack {
            TestView(isLoading: state == .loading)
            Spacer()
        }
        .userStory(.testStory)
        .previewDevice(PreviewDevice(rawValue: "iPhone 8"))
    }
}

struct TestViewWithoutState_Previews: PreviewProvider, UISystemProvider {
    static var previews: some View {
        TestView(isLoading: true)
            .previewLayout(.sizeThatFits)
    }
}

struct GreenButton_Previews: PreviewProvider, UISystemProvider {
    static var previews: some View {
        Button("Apply", action: { })
            .foregroundColor(.black)
            .font(.title)
            .padding()
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(Capsule().foregroundColor(.green.opacity(0.2)))
            .previewLayout(.sizeThatFits)
    }
}
