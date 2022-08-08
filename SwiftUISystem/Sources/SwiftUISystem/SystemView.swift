//
//  File.swift
//  
//
//  Created by Maksim Grishutin on 05.08.2022.
//

import SwiftUI

// Model
public struct SystemView: Identifiable {
    public enum ViewType: Int {
        case screen // Нужно добавить layout (.fill)
        case component
    }

    public typealias UserStory = String

    public let content: () -> WrapperView

    public let name: String
    public let state: String

    public var type: ViewType
    public var story: UserStory?

    @inlinable
    public var id: String {
        name + state
    }

    public init(content: @escaping () -> WrapperView, name: String, state: String, type: ViewType, story: UserStory? = nil) {
        self.content = content
        self.name = name
        self.state = state
        self.type = type
        self.story = story
    }
}
