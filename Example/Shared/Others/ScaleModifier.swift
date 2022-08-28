//
//  ScaleModifier.swift
//  SnapshotAppSwiftUI (iOS)
//
//  Created by Maksim Grishutin on 16.08.2022.
//

import Foundation
import SwiftUI

struct ScaleModifier: ViewModifier {
    @State private var size: CGSize = .zero
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            size = proxy.size
                        }
                }
            }
            .scaleEffect(scale)
            .frame(width: size.width * scale, height: size.height * scale)
    }
}
