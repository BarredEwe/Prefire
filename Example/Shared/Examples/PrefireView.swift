//
//  AuthView.swift
//  PrefireExample
//
//  Created by Grishutin Maksim Vladimirovich on 03.10.2022.
//

import SwiftUI
import Prefire

struct PrefireView: View {
    var body: some View {
        VStack {
            HStack(spacing: 24) {
                Text("🔥")
                    .font(.system(size: 60))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .padding(.horizontal, -4)
                            .foregroundColor(.red.opacity(0.6))
                    )
                Text("Prefire")
                    .foregroundColor(.white)
                    .font(.system(size: 56).weight(.heavy))
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.7))
            .background(.purple)
        }
        .cornerRadius(16)
    }
}

struct PrefireView_Preview: PreviewProvider, PrefireProvider {
    static var previews: some View {
        PrefireView()
            .previewLayout(.sizeThatFits)
            .previewUserStory(.auth)
            .previewDisplayName("PrefireView")
    }
}
