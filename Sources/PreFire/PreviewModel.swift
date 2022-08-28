//
//  SystemViewModel.swift
//  
//
//  Created by Maksim Grishutin on 05.08.2022.
//

import SwiftUI

// Model
public struct PreviewModel: Identifiable {
    public typealias UserStory = String

    public let content: () -> WrapperView

    public let name: String
    public let state: String

    public var type: ViewType
    public var device: PreviewDevice?
    public var story: UserStory?
    public var renderTime: String?

    @inlinable
    public var id: String {
        name + state
    }

    public init(
        content: @escaping () -> WrapperView,
                name: String,
                type: ViewType = .component,
                device: PreviewDevice?,
                state: String
    ) {
        self.content = content
        self.name = name
        self.type = type
        self.device = device
        self.state = state
    }

    public enum ViewType: Equatable {
        case screen
        case component
    }
}
