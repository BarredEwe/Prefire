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

    public enum ViewType: Equatable {
        case screen
        case component
    }

    @inlinable
    public var id: String {
        name + state
    }

    /// Наша statc view от Preview
    public let content: () -> AnyView
    /// Имя preview
    public let name: String
    /// Состояние preview (.default, loading и тд)
    public let state: String
    /// Тип preview
    public var type: ViewType
    /// Устройство для отображения preview
    public var device: PreviewDevice?
    /// Наименование нашего Flow
    public var story: UserStory?
    /// Время рендеринга
    public var renderTime: String?

    public init(
        content: @escaping () -> AnyView,
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
}
