//
//  File.swift
//  
//
//  Created by Maksim Grishutin on 05.08.2022.
//

import SwiftUI

// Model
public struct SystemViewModel: Identifiable {
    public typealias UserStory = String

    public let content: () -> WrapperView

    public let name: String
    public let state: String

    public var type: ViewType = .component
    public var story: UserStory?
    public var renderTime: String?

    @inlinable
    public var id: String {
        name + state
    }

    public init(content: @escaping () -> WrapperView, name: String, state: String) {
        self.content = content
        self.name = name
        self.state = state
    }

    public enum ViewType: Equatable {
//        public enum LayoutType: Int {
//            case fill
//            case fit
//        }

        case screen//(LayoutType = .fill)
        case component//(LayoutType = .fit)

//        public var layout: LayoutType {
//            switch self {
//            case let .component(type):
//                return type
//            case let .screen(type):
//                return type
//            }
//        }
    }
}
