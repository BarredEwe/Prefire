//
//  LoadingTimeModifier.swift
//  SnapshotAppSwiftUI (iOS)
//
//  Created by Maksim Grishutin on 11.08.2022.
//

import SwiftUI

struct LoadingTimeModifier: ViewModifier {
    @State private var createDate: Date? = Date()
    var completion: (String) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard let createDate = createDate else { return }

                let diffTime = Date().timeIntervalSince(createDate) * 1000
                completion(String(diffTime.truncatingRemainder(dividingBy: 1000).rounded()) + " ms")

                self.createDate = nil
            }
    }
}
