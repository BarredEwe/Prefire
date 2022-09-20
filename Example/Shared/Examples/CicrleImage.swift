//
//  CicrleImage.swift
//  PreFireExample
//
//  Created by Grishutin Maksim Vladimirovich on 13.09.2022.
//

import SwiftUI
import Prefire

struct CircleImage: View {
    var body: some View {
        Image("nature")
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 4))
            .shadow(radius: 7)
    }
}

struct CircleImage_Previews: PreviewProvider, PrefireProvider {
    static var previews: some View {
        CircleImage()
            .previewLayout(.sizeThatFits)
    }
}
