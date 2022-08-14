//
//  WrapperView.swift
//  
//
//  Created by Maksim Grishutin on 05.08.2022.
//

import SwiftUI

// To private
public struct WrapperView: View { // TODO: Rename to .. mb convert to ViewMod
    var content: AnyView?

    public init(content: @escaping () -> AnyView, closure: @escaping () -> Void) {
        closure()

        self.content = AnyView(
            content()
        )
    }

    public var body: some View {
        content
    }
}
